/**
 * oda-run.ts — commission One Dollar Audit (ODA) jobs for the in-scope contracts
 * of PR #153, one job per contract (or per cluster), paying $1 USDC each via the
 * x402 protocol, then poll each job and save the returned report.
 *
 * SAFETY: this script defaults to DRY-RUN. It only spends money when invoked with
 * `--live --yes`. Every created job is written to a manifest BEFORE polling, and
 * a job already in the manifest for the same commit is skipped — so a re-run never
 * double-pays.
 *
 * The wallet only needs USDC on Base: x402 uses EIP-3009 (`transferWithAuthorization`),
 * a gasless signature the facilitator submits on-chain, so the payer pays no gas.
 *
 * Usage:
 *   npx tsx script/audits/oda-run.ts                      # dry-run, per-file (13 jobs), writes previews
 *   npx tsx script/audits/oda-run.ts --clustered          # dry-run, clustered (7 jobs)
 *   npx tsx script/audits/oda-run.ts --only multivault    # a single job by id
 *   ODA_PRIVATE_KEY=0x... npx tsx script/audits/oda-run.ts --live --yes   # actually pay + poll
 *
 * Env:
 *   ODA_PRIVATE_KEY   (required for --live)  funded Base wallet holding USDC, one signer
 *   ODA_ENDPOINT      default https://leftclaw.services/api/audit
 *   ODA_CALLBACK_URL  optional https webhook; ODA POSTs {jobId,status,reportUrl,statusUrl} on completion
 *   ODA_IPFS_GATEWAY  default https://ipfs.io/ipfs/   (used to fetch ipfs:// report bodies)
 *   ODA_COMMIT / ODA_PR / ODA_REPO   override the pinned commit / PR number / repo slug
 */

import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import * as path from "node:path";
import {
  REPO_ROOT,
  REPO_SLUG,
  PR_NUMBER,
  buildJobs,
  computeScope,
  githubBlob,
  readSource,
  type OdaJob,
  type Scope,
} from "./oda-scope.ts";

const ENDPOINT = process.env.ODA_ENDPOINT ?? "https://leftclaw.services/api/audit";
const IPFS_GATEWAY = process.env.ODA_IPFS_GATEWAY ?? "https://ipfs.io/ipfs/";
const CALLBACK_URL = process.env.ODA_CALLBACK_URL;
const BRIEF_PATH = path.join(REPO_ROOT, "audits/handoffs/oda/oda-scope-brief.md");
const OUT_DIR = path.join(REPO_ROOT, "audits/handoffs/oda/reports");
const MANIFEST_PATH = path.join(OUT_DIR, "manifest.json");
const WARN_BYTES = Number(process.env.ODA_WARN_BYTES ?? 100_000);
const TERMINAL = new Set(["complete", "declined", "cancelled"]);

interface Args {
  live: boolean;
  yes: boolean;
  granularity: "per-file" | "clustered";
  only?: string;
  poll: boolean;
}

interface ManifestEntry {
  odaJobId: number | string;
  jobUrl?: string;
  statusUrl?: string;
  commit: string;
  files: string[];
  createdAtIso: string;
  status?: string;
  reportUrl?: string;
  reportHtmlUrl?: string;
}
type Manifest = Record<string, ManifestEntry>;

function parseArgs(): Args {
  const a = process.argv.slice(2);
  const val = (flag: string) => {
    const i = a.indexOf(flag);
    return i >= 0 ? a[i + 1] : undefined;
  };
  return {
    live: a.includes("--live"),
    yes: a.includes("--yes"),
    granularity: a.includes("--clustered") ? "clustered" : "per-file",
    only: val("--only"),
    poll: !a.includes("--no-poll"),
  };
}

function loadBrief(): string {
  if (!existsSync(BRIEF_PATH)) throw new Error(`missing brief: ${BRIEF_PATH}`);
  return readFileSync(BRIEF_PATH, "utf8").trimEnd();
}

/** The full on-chain description for one job: brief + scope lock + pasted source. */
function buildDescription(job: OdaJob, brief: string, commit: string): string {
  const lines: string[] = [brief, "", "── THIS JOB'S SCOPE ──", ""];
  lines.push(`Pull request: #${PR_NUMBER} (feat/v1.1.0-core-upgrade) — public repo ${REPO_SLUG}`);
  lines.push(`Pinned commit: ${commit}`);
  lines.push(`Job: ${job.title}`);
  lines.push("");
  lines.push("Review these file(s) IN FULL (their source is pasted below):");
  for (const p of job.primaries) lines.push(`  - ${p}  (GitHub: ${githubBlob(commit, p)})`);
  if (job.context.length) {
    lines.push("");
    lines.push("Context only — trusted dependencies, DO NOT file findings against these (pull from GitHub if needed):");
    for (const c of job.context) lines.push(`  - ${c}  (GitHub: ${githubBlob(commit, c)})`);
  }
  lines.push("", `── SOURCE (pinned @ ${commit}) ──`, "");
  for (const p of job.primaries) {
    lines.push(`///// BEGIN FILE: ${p} /////`, "");
    lines.push(readSource(p).trimEnd());
    lines.push("", `///// END FILE: ${p} /////`, "");
  }
  return lines.join("\n");
}

function jobKey(commit: string, job: OdaJob): string {
  return `${commit.slice(0, 10)}:${job.id}`;
}

function loadManifest(): Manifest {
  if (!existsSync(MANIFEST_PATH)) return {};
  try {
    return JSON.parse(readFileSync(MANIFEST_PATH, "utf8")) as Manifest;
  } catch {
    return {};
  }
}

function saveManifest(m: Manifest): void {
  mkdirSync(OUT_DIR, { recursive: true });
  writeFileSync(MANIFEST_PATH, JSON.stringify(m, null, 2) + "\n");
}

function nowIso(): string {
  return new Date().toISOString();
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/** Build the payment-wrapped fetch. Imported lazily so dry-run needs no deps. */
async function makePaidFetch(): Promise<typeof fetch> {
  const pk = process.env.ODA_PRIVATE_KEY;
  if (!pk) throw new Error("ODA_PRIVATE_KEY is required for --live (a funded Base wallet holding USDC).");
  let wrapFetchWithPaymentFromConfig: any;
  let ExactEvmScheme: any;
  let privateKeyToAccount: any;
  try {
    ({ wrapFetchWithPaymentFromConfig } = await import("@x402/fetch"));
    ({ ExactEvmScheme } = await import("@x402/evm"));
    ({ privateKeyToAccount } = await import("viem/accounts"));
  } catch {
    throw new Error(
      "x402 client not installed. Run:\n  bun add -d @x402/fetch @x402/evm viem\n(or: npm i -D @x402/fetch @x402/evm viem)",
    );
  }
  const account = privateKeyToAccount(pk.startsWith("0x") ? pk : `0x${pk}`);
  return wrapFetchWithPaymentFromConfig(fetch, {
    schemes: [{ network: "eip155:*", client: new ExactEvmScheme(account) }],
  }) as typeof fetch;
}

/** Create one job: POST (pays via x402), return the parsed job pointer. */
async function createJob(
  paidFetch: typeof fetch,
  description: string,
): Promise<{ jobId: number | string; jobUrl?: string; statusUrl?: string }> {
  const body: Record<string, unknown> = { description };
  body.context = `Public repo ${REPO_SLUG}. Full PR diff: https://github.com/${REPO_SLUG}/pull/${PR_NUMBER}. Review only the pasted in-scope file(s); treat everything else as trusted context.`;
  if (CALLBACK_URL) body.callbackUrl = CALLBACK_URL;

  const res = await paidFetch(ENDPOINT, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`ODA POST ${res.status}: ${text.slice(0, 400)}`);
  const json = JSON.parse(text) as any;
  const jobId = json.jobId ?? json.id;
  if (jobId === undefined) throw new Error(`ODA response missing jobId: ${text.slice(0, 400)}`);
  return { jobId, jobUrl: json.jobUrl, statusUrl: json.statusUrl ?? `https://onedollaraudit.com/api/jobs/${jobId}` };
}

/** Poll one job until terminal; persist and download the report. */
async function pollJob(key: string, manifest: Manifest): Promise<void> {
  const entry = manifest[key];
  if (!entry?.statusUrl) return;
  const deadline = Date.now() + 2 * 60 * 60 * 1000; // 2h ceiling
  while (Date.now() < deadline) {
    let status = "unknown";
    try {
      const res = await fetch(entry.statusUrl);
      const j = (await res.json()) as any;
      status = j.status ?? "unknown";
      entry.status = status;
      entry.reportUrl = j.reportUrl ?? entry.reportUrl;
      entry.reportHtmlUrl = j.reportHtmlUrl ?? entry.reportHtmlUrl;
      saveManifest(manifest);
      process.stdout.write(`  [${entry.odaJobId}] ${status}${j.stage ? ` — ${j.stage}` : ""}\n`);
      if (TERMINAL.has(status)) {
        if (status === "complete") await downloadReport(entry);
        return;
      }
      await sleep(Math.max(5, Number(j.pollIntervalSeconds ?? 20)) * 1000);
    } catch (e) {
      process.stdout.write(`  [${entry.odaJobId}] poll error: ${(e as Error).message}; retrying in 20s\n`);
      await sleep(20_000);
    }
  }
  process.stdout.write(`  [${entry.odaJobId}] still running after 2h; re-run with --no-poll off later to resume.\n`);
}

async function downloadReport(entry: ManifestEntry): Promise<void> {
  const dir = path.join(OUT_DIR, String(entry.odaJobId));
  mkdirSync(dir, { recursive: true });
  const fetchTo = async (url: string | undefined, file: string) => {
    if (!url) return;
    const href = url.startsWith("ipfs://") ? IPFS_GATEWAY + url.slice("ipfs://".length) : url;
    try {
      const res = await fetch(href);
      const buf = Buffer.from(await res.arrayBuffer());
      writeFileSync(path.join(dir, file), buf);
      process.stdout.write(`  [${entry.odaJobId}] saved ${file} (${buf.length} bytes)\n`);
    } catch (e) {
      process.stdout.write(`  [${entry.odaJobId}] could not fetch ${file}: ${(e as Error).message}\n`);
    }
  };
  await fetchTo(entry.reportUrl, "report.md");
  await fetchTo(entry.reportHtmlUrl, "report.html");
  writeFileSync(path.join(dir, "job.json"), JSON.stringify(entry, null, 2) + "\n");
}

async function main(): Promise<void> {
  const args = parseArgs();
  const brief = loadBrief();
  const scope: Scope = computeScope();
  let jobs = buildJobs(scope, args.granularity);
  if (args.only) jobs = jobs.filter((j) => j.id === args.only);
  if (jobs.length === 0) throw new Error(`no jobs matched (--only ${args.only ?? ""})`);

  console.log(`\nOne Dollar Audit runner — PR #${PR_NUMBER} @ ${scope.commit}`);
  console.log(
    `Mode: ${args.live ? "LIVE (will spend USDC)" : "DRY-RUN"} · ${args.granularity} · ${jobs.length} job(s)`,
  );
  if (scope.uncharted.length) {
    console.log(`⚠️  uncharted in-scope files (no curated context): ${scope.uncharted.join(", ")}`);
  }

  // Preview + size report for every job.
  const previewDir = path.join(OUT_DIR, "dry-run");
  mkdirSync(previewDir, { recursive: true });
  const descriptions = new Map<string, string>();
  console.log("");
  for (const job of jobs) {
    const desc = buildDescription(job, brief, scope.commit);
    descriptions.set(job.id, desc);
    const kb = (Buffer.byteLength(desc, "utf8") / 1024).toFixed(1);
    const warn =
      Buffer.byteLength(desc, "utf8") > WARN_BYTES
        ? "  ⚠️ large — may exceed ODA input limit; GitHub link is the fallback"
        : "";
    console.log(`  [${job.id}] ${job.primaries.map((p) => path.basename(p)).join(", ")} — ${kb} KiB${warn}`);
    writeFileSync(path.join(previewDir, `${job.id}.txt`), desc);
  }
  console.log(`\nPer-job descriptions written to ${path.relative(REPO_ROOT, previewDir)}/ for inspection.`);

  if (!args.live) {
    console.log(
      `\nDry-run only. To commission for real:  ODA_PRIVATE_KEY=0x... npx tsx script/audits/oda-run.ts${args.granularity === "clustered" ? " --clustered" : ""} --live --yes\n`,
    );
    return;
  }
  if (!args.yes) {
    console.log(
      `\nRefusing to spend without --yes. This would create ${jobs.length} job(s) at $1 USDC each (~$${jobs.length}).`,
    );
    console.log(`Re-run with --live --yes to proceed.\n`);
    process.exitCode = 2;
    return;
  }

  const manifest = loadManifest();
  const paidFetch = await makePaidFetch();

  for (const job of jobs) {
    const key = jobKey(scope.commit, job);
    if (manifest[key]?.odaJobId !== undefined) {
      console.log(
        `\n[${job.id}] already commissioned (job ${manifest[key].odaJobId}) at this commit — skipping payment.`,
      );
      continue;
    }
    console.log(`\n[${job.id}] paying $1 USDC and creating job…`);
    try {
      const created = await createJob(paidFetch, descriptions.get(job.id)!);
      manifest[key] = {
        odaJobId: created.jobId,
        jobUrl: created.jobUrl,
        statusUrl: created.statusUrl,
        commit: scope.commit,
        files: job.primaries,
        createdAtIso: nowIso(),
        status: "pending",
      };
      saveManifest(manifest); // persist BEFORE polling so a crash never loses a paid job
      console.log(`[${job.id}] created ODA job ${created.jobId} → ${created.jobUrl ?? created.statusUrl}`);
    } catch (e) {
      console.log(`[${job.id}] FAILED: ${(e as Error).message}`);
    }
  }

  if (args.poll) {
    console.log(`\nPolling ${jobs.length} job(s) until complete (Ctrl-C is safe — resume by re-running)…`);
    for (const job of jobs) await pollJob(jobKey(scope.commit, job), manifest);
  }
  console.log(`\nDone. Manifest: ${path.relative(REPO_ROOT, MANIFEST_PATH)}\n`);
}

main().catch((e) => {
  console.error(`\nerror: ${(e as Error).message}\n`);
  process.exitCode = 1;
});
