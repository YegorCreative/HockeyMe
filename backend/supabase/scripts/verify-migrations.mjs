import { readFile, readdir } from "node:fs/promises";

const directory = new URL("../migrations/", import.meta.url);
const files = (await readdir(directory))
  .filter((name) => name.endsWith(".sql"))
  .sort();

if (files.length === 0) throw new Error("No Supabase migrations found");

const timestamps = new Set();
let schema = "";
for (const file of files) {
  if (!/^\d{14}_[a-z0-9_]+\.sql$/.test(file)) {
    throw new Error(`Invalid migration filename: ${file}`);
  }
  const timestamp = file.slice(0, 14);
  if (timestamps.has(timestamp)) {
    throw new Error(`Duplicate migration timestamp: ${timestamp}`);
  }
  timestamps.add(timestamp);
  schema += `\n${await readFile(new URL(file, directory), "utf8")}`;
}

const tables = [
  ...schema.matchAll(/create table public\.([a-z0-9_]+)/gi),
].map((match) => match[1]);
for (const table of new Set(tables)) {
  const rls = new RegExp(
    `alter\\s+table\\s+public\\.${table}\\s+enable\\s+row\\s+level\\s+security`,
    "i",
  );
  if (!rls.test(schema)) {
    throw new Error(`Missing RLS enablement for public.${table}`);
  }
}

const canonicalMigration = await readFile(
  new URL("20260730140000_phase3_bootstrap.sql", directory),
  "utf8",
);
const exerciseSlugs = new Set(
  [...canonicalMigration.matchAll(/'([a-z0-9]+(?:-[a-z0-9]+)+)'/g)]
    .map((match) => match[1])
    .filter((value) =>
      [
        "back-squat", "front-squat", "trap-bar-deadlift",
        "bulgarian-split-squat", "nordic-hamstring-curl",
        "copenhagen-plank", "lateral-bounds", "box-jump",
        "broad-jump", "skater-hops", "sled-push", "sled-pull",
        "chin-up", "pull-up", "bench-press", "landmine-press",
        "farmer-carry", "pallof-press",
      ].includes(value)
    ),
);
if (exerciseSlugs.size !== 18) {
  throw new Error(`Expected 18 canonical exercises, found ${exerciseSlugs.size}`);
}

console.log(
  `PASS: ${files.length} ordered migrations, ${new Set(tables).size} RLS tables, 18 exercises`,
);
