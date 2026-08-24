"""Convert dynamic-fee-curve-review.md into a self-contained HTML artifact (figures inlined as SVG)."""
import re, os, html

ROOT = os.path.join(os.path.dirname(__file__), "..")
import sys
SRC = sys.argv[1] if len(sys.argv) > 1 else "dynamic-fee-curve-review.md"
TITLE = sys.argv[2] if len(sys.argv) > 2 else "Dynamic Fee Curve Review"
md = open(os.path.join(ROOT, SRC)).read()

def inline(s):
    s = html.escape(s, quote=False)
    s = re.sub(r"`([^`]+)`", r"<code>\1</code>", s)
    s = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", s)
    s = re.sub(r"(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])", r"<em>\1</em>", s)
    s = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', s)
    return s

out = []
lines = md.split("\n")
i = 0
in_list = None
para = []
def flush_para():
    global para
    if para:
        out.append("<p>" + inline(" ".join(para)) + "</p>")
        para = []
def close_list():
    global in_list
    if in_list:
        out.append(f"</{in_list}>"); in_list = None
sec = 0
while i < len(lines):
    ln = lines[i]
    if ln.startswith("```"):
        flush_para(); close_list()
        lang = ln[3:].strip()
        j = i + 1; buf = []
        while j < len(lines) and not lines[j].startswith("```"):
            buf.append(lines[j]); j += 1
        if lang == "mermaid":
            out.append('<div class="diagram"><pre class="mermaid">' + "\n".join(buf) + "</pre></div>")
        else:
            out.append('<div class="codewrap"><pre><code>' + html.escape("\n".join(buf)) + "</code></pre></div>")
        i = j + 1; continue
    if ln.startswith("|"):
        flush_para(); close_list()
        rows = []
        while i < len(lines) and lines[i].startswith("|"):
            rows.append(lines[i]); i += 1
        hdr = [c.strip() for c in rows[0].strip("|").split("|")]
        align = [("r" if c.strip().endswith(":") else "l") for c in rows[1].strip("|").split("|")]
        t = ['<div class="tablewrap"><table><thead><tr>']
        for h, a in zip(hdr, align):
            t.append(f'<th class="{a}">{inline(h)}</th>')
        t.append("</tr></thead><tbody>")
        for r in rows[2:]:
            cells = [c.strip() for c in r.strip("|").split("|")]
            t.append("<tr>")
            for c, a in zip(cells, align):
                cls = a
                m = re.match(r"^\*\*(High|Medium|Low|Info)\*\*|^(High|Medium|Low|Info)\b", c)
                if m and "Severity" in hdr[cells.index(c)] if c in cells else False:
                    pass
                if hdr[cells.index(c)].startswith("Severity") if c in cells else False:
                    sev = (m.group(1) or m.group(2)).lower() if m else ""
                    t.append(f'<td class="{cls}"><span class="sev sev-{sev}">{inline(c)}</span></td>')
                else:
                    t.append(f'<td class="{cls}">{inline(c)}</td>')
            t.append("</tr>")
        t.append("</tbody></table></div>")
        out.append("".join(t)); continue
    m = re.match(r"^(#{1,3}) (.*)", ln)
    if m:
        flush_para(); close_list()
        lvl = len(m.group(1)); txt = m.group(2)
        anchor = re.sub(r"[^a-z0-9]+", "-", txt.lower()).strip("-")
        if lvl == 1:
            out.append(f"<h1>{inline(txt)}</h1>")
        else:
            out.append(f'<h{lvl} id="{anchor}">{inline(txt)}</h{lvl}>')
        i += 1; continue
    m = re.match(r"^!\[([^\]]*)\]\(([^)]+)\)", ln)
    if m:
        flush_para(); close_list()
        svg = open(os.path.join(ROOT, m.group(2))).read()
        svg = re.sub(r"\s(width|height)='\d+'", "", svg, count=2)
        out.append(f'<figure class="fig">{svg}</figure>')
        i += 1; continue
    if ln.startswith("> "):
        flush_para(); close_list()
        buf = []
        while i < len(lines) and lines[i].startswith(">"):
            buf.append(lines[i][1:].strip()); i += 1
        out.append('<blockquote class="note">' + inline(" ".join(buf)) + "</blockquote>"); continue
    m = re.match(r"^(\s*)([*-]|\d+\.) (.*)", ln)
    if m:
        flush_para()
        kind = "ol" if m.group(2)[0].isdigit() else "ul"
        if in_list != kind:
            close_list(); out.append(f"<{kind}>"); in_list = kind
        item = [m.group(3)]
        i += 1
        while i < len(lines) and lines[i].startswith("  ") and not re.match(r"^\s*([*-]|\d+\.) ", lines[i]) and not lines[i].strip().startswith("```"):
            item.append(lines[i].strip()); i += 1
        # code block inside list item
        if i < len(lines) and lines[i].strip().startswith("```"):
            j = i + 1; buf = []
            while j < len(lines) and not lines[j].strip().startswith("```"):
                buf.append(lines[j][3:] if lines[j].startswith("   ") else lines[j]); j += 1
            out.append("<li>" + inline(" ".join(item)) + '<div class="codewrap"><pre><code>' + html.escape("\n".join(buf)) + "</code></pre></div></li>")
            i = j + 1
            while i < len(lines) and lines[i].startswith("   ") and lines[i].strip():
                i += 1  # swallow continuation lines already captured
            continue
        out.append("<li>" + inline(" ".join(item)) + "</li>")
        continue
    if ln.strip() == "---":
        flush_para(); close_list(); out.append("<hr>"); i += 1; continue
    if ln.strip() == "":
        flush_para(); close_list(); i += 1; continue
    para.append(ln.strip()); i += 1
flush_para(); close_list()
body = "\n".join(out)

# TOC from h2
toc = "".join(f'<li><a href="#{a}">{t}</a></li>' for a, t in re.findall(r'<h2 id="([^"]+)">(.*?)</h2>', body))

page = f"""<title>{TITLE}</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Source+Serif+4:opsz,wght@8..60,500;8..60,600&family=IBM+Plex+Sans:wght@400;500;600&family=IBM+Plex+Mono:wght@400;500&display=swap">
<style>
:root {{
  --bg: #f7f8fa; --surface: #ffffff; --ink: #151b24; --ink-2: #4b5563; --ink-3: #6b7280; --rule: #e3e6eb;
  --accent: #2563eb; --accent-ink: #1d4ed8; --code-bg: #eef1f5;
  --high: #b42318; --high-bg: #fde8e6; --med: #b54708; --med-bg: #fdeedd; --low: #3f5a78; --low-bg: #e7edf4; --info: #5b6470; --info-bg: #eceef1;
  --note-bg: #eaf1fd;
}}
@media (prefers-color-scheme: dark) {{ :root:not([data-theme="light"]) {{
  --bg: #0f1318; --surface: #161b22; --ink: #e6eaf0; --ink-2: #b5bdc8; --ink-3: #8b95a3; --rule: #273038;
  --accent: #6ea0ff; --accent-ink: #8fb4ff; --code-bg: #1d242d;
  --high: #ff8a80; --high-bg: #3a1714; --med: #ffb870; --med-bg: #3a2410; --low: #a9c1dc; --low-bg: #1c2733; --info: #aab3bf; --info-bg: #20262e;
  --note-bg: #16243a;
}} }}
:root[data-theme="dark"] {{
  --bg: #0f1318; --surface: #161b22; --ink: #e6eaf0; --ink-2: #b5bdc8; --ink-3: #8b95a3; --rule: #273038;
  --accent: #6ea0ff; --accent-ink: #8fb4ff; --code-bg: #1d242d;
  --high: #ff8a80; --high-bg: #3a1714; --med: #ffb870; --med-bg: #3a2410; --low: #a9c1dc; --low-bg: #1c2733; --info: #aab3bf; --info-bg: #20262e;
  --note-bg: #16243a;
}}
body {{ background: var(--bg); color: var(--ink); font-family: "IBM Plex Sans", ui-sans-serif, system-ui, sans-serif; font-size: 16px; line-height: 1.6; margin: 0; }}
.wrap {{ display: grid; grid-template-columns: 220px minmax(0, 1fr); gap: 48px; max-width: 1240px; margin: 0 auto; padding: 48px 32px 96px; }}
nav.toc {{ position: sticky; top: 24px; align-self: start; font-size: 13px; line-height: 1.45; }}
nav.toc .eyebrow {{ font-size: 11px; letter-spacing: .08em; text-transform: uppercase; color: var(--ink-3); margin-bottom: 10px; }}
nav.toc ul {{ list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 6px; }}
nav.toc a {{ color: var(--ink-2); text-decoration: none; }} nav.toc a:hover, nav.toc a:focus-visible {{ color: var(--accent-ink); }}
main {{ min-width: 0; }}
main > * {{ max-width: 72ch; }}
main > .tablewrap, main > .fig, main > .diagram, main > .codewrap, main > h1 {{ max-width: none; }}
h1, h2, h3 {{ font-family: "Source Serif 4", Georgia, "Times New Roman", serif; font-weight: 600; line-height: 1.2; text-wrap: balance; color: var(--ink); }}
h1 {{ font-size: 34px; margin: 0 0 24px; letter-spacing: -.01em; }}
h2 {{ font-size: 26px; margin: 56px 0 16px; padding-top: 20px; border-top: 1px solid var(--rule); }}
h3 {{ font-size: 19px; margin: 36px 0 10px; }}
p {{ margin: 0 0 14px; }} p, li {{ color: var(--ink); }}
a {{ color: var(--accent-ink); }} a:focus-visible {{ outline: 2px solid var(--accent); outline-offset: 2px; }}
strong {{ font-weight: 600; }}
code {{ font-family: "IBM Plex Mono", ui-monospace, Menlo, monospace; font-size: .9em; background: var(--code-bg); padding: 1px 5px; border-radius: 3px; }}
.codewrap {{ overflow-x: auto; background: var(--code-bg); border-radius: 6px; margin: 12px 0 18px; }}
.codewrap pre {{ margin: 0; padding: 14px 16px; }} .codewrap code {{ background: none; padding: 0; font-size: 13px; line-height: 1.5; }}
.tablewrap {{ overflow-x: auto; margin: 12px 0 22px; border: 1px solid var(--rule); border-radius: 6px; background: var(--surface); }}
table {{ border-collapse: collapse; width: 100%; font-size: 13.5px; font-variant-numeric: tabular-nums; }}
th, td {{ padding: 7px 10px; border-bottom: 1px solid var(--rule); vertical-align: top; text-align: left; }}
th {{ font-size: 11.5px; letter-spacing: .05em; text-transform: uppercase; color: var(--ink-3); font-weight: 600; background: var(--bg); }}
th.r, td.r {{ text-align: right; font-family: "IBM Plex Mono", ui-monospace, monospace; font-size: 12.5px; }}
th.r {{ font-family: "IBM Plex Sans", sans-serif; font-size: 11.5px; }}
tbody tr:last-child td {{ border-bottom: 0; }}
.sev {{ display: inline-block; padding: 1px 8px; border-radius: 999px; font-size: 12px; font-weight: 600; white-space: nowrap; }}
.sev strong {{ font-weight: 600; }}
.sev-high {{ color: var(--high); background: var(--high-bg); }} .sev-medium {{ color: var(--med); background: var(--med-bg); }}
.sev-low {{ color: var(--low); background: var(--low-bg); }} .sev-info {{ color: var(--info); background: var(--info-bg); }}
.fig {{ margin: 18px 0 26px; padding: 8px; background: #ffffff; border: 1px solid var(--rule); border-radius: 6px; overflow-x: auto; }}
.fig svg {{ display: block; width: 100%; height: auto; max-width: 960px; }}
.diagram {{ margin: 16px 0 24px; overflow-x: auto; }}
blockquote.note {{ margin: 16px 0 20px; padding: 12px 16px; border-left: 3px solid var(--accent); background: var(--note-bg); border-radius: 0 6px 6px 0; }}
hr {{ border: 0; height: 0; margin: 0; }}
ul, ol {{ padding-left: 22px; margin: 0 0 16px; }} li {{ margin-bottom: 6px; }} li .codewrap {{ margin-top: 8px; }}
@media (max-width: 880px) {{ .wrap {{ grid-template-columns: 1fr; padding: 24px 16px 64px; }} nav.toc {{ position: static; }} }}
@media (prefers-reduced-motion: no-preference) {{ html {{ scroll-behavior: smooth; }} }}
</style>
<div class="wrap">
<nav class="toc"><div class="eyebrow">Contents</div><ul>{toc}</ul></nav>
<main>
{body}
</main>
</div>
"""
open(os.path.join(ROOT, SRC.replace(".md", ".html")), "w").write(page)
print(len(page))
