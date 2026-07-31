import { readFile } from "node:fs/promises";

const environment = process.env.FORGE_ENVIRONMENT;
const configPath = process.env.FORGE_CONFIG_PATH;
const productionRef = process.env.FORGE_PRODUCTION_PROJECT_REF;

if (!["debug", "staging", "production"].includes(environment)) {
  throw new Error("FORGE_ENVIRONMENT must be debug, staging, or production");
}
if (!configPath || !productionRef) {
  throw new Error(
    "FORGE_CONFIG_PATH and FORGE_PRODUCTION_PROJECT_REF are required",
  );
}

const contents = await readFile(configPath, "utf8");
function value(key) {
  const match = contents.match(
    new RegExp(`<key>${key}</key>\\s*<string>([^<]+)</string>`),
  );
  if (!match || /YOUR_|placeholder/i.test(match[1])) {
    throw new Error(`Missing configured ${key}`);
  }
  return match[1].trim();
}

const configuredEnvironment = value("environment");
const url = new URL(value("url"));
value("anonKey");
const projectRef = url.hostname.split(".")[0];

if (configuredEnvironment !== environment) {
  throw new Error("Build and Supabase configuration environments differ");
}
if (environment !== "production" && projectRef === productionRef) {
  throw new Error("Refusing a non-production build connected to production");
}
if (environment === "production" && projectRef !== productionRef) {
  throw new Error("Refusing a production build connected to non-production");
}

console.log(`PASS: ${environment} environment configuration is isolated`);
