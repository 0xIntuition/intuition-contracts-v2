import fs from "fs";
import path from "path";

const baseDir = path.join(__dirname, "..", "..", "out");

function processJsonFile(filePath: string) {
  const content = fs.readFileSync(filePath, "utf-8");
  try {
    const parsed = JSON.parse(content);
    if (Array.isArray(parsed.abi)) {
      fs.writeFileSync(filePath, JSON.stringify(parsed.abi, null, 2));
      console.log(`✅ Cleaned: ${filePath}`);
    } else {
      console.warn(`⚠️ No ABI found in: ${filePath}`);
    }
  } catch (err: any) {
    console.error(`❌ Failed to parse JSON in: ${filePath}`, err.message);
  }
}

function walk(dir: string) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walk(fullPath);
    } else if (entry.isFile() && fullPath.endsWith(".json")) {
      processJsonFile(fullPath);
    }
  }
}

walk(baseDir);
