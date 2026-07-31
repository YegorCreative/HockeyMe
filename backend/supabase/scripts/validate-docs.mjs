import { access, readFile } from "node:fs/promises";

const required = [
  "README.md",
  "docs/ARCHITECTURE.md",
  "docs/DATABASE.md",
  "docs/DEPLOYMENT.md",
  "docs/SECURITY.md",
  "docs/TESTING.md",
  "docs/RELEASE.md",
  "docs/OPERATIONS.md",
  "docs/RUNBOOK.md",
  "docs/MONITORING.md",
  "docs/INCIDENT_RESPONSE.md",
  "backend/supabase/README.md",
];

for (const path of required) {
  await access(path);
  const contents = await readFile(path, "utf8");
  if (!contents.startsWith("# ") || contents.length < 100) {
    throw new Error(`Documentation is incomplete: ${path}`);
  }
}

console.log(`PASS: ${required.length} required documents are present`);
