const required = [
  "SUPABASE_URL",
  "SUPABASE_ANON_KEY",
  "SUPABASE_SERVICE_ROLE_KEY",
  "FORGE_STAGING_PROJECT_REF",
  "FORGE_PRODUCTION_PROJECT_REF",
  "FORGE_STAGING_CONFIRM",
];

for (const name of required) {
  if (!process.env[name]) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
}

const projectRef = new URL(process.env.SUPABASE_URL).hostname.split(".")[0];
if (
  process.env.FORGE_ENVIRONMENT !== "staging" ||
  process.env.FORGE_STAGING_CONFIRM !== projectRef ||
  process.env.FORGE_STAGING_PROJECT_REF !== projectRef
) {
  throw new Error("Explicit staging project confirmation failed");
}
if (projectRef === process.env.FORGE_PRODUCTION_PROJECT_REF) {
  throw new Error("Refusing to operate on the production project");
}
if (
  process.env.SUPABASE_SERVICE_ROLE_KEY ===
  process.env.FORGE_PRODUCTION_SERVICE_ROLE_KEY
) {
  throw new Error("Staging and production service-role credentials match");
}

console.log(`PASS: confirmed isolated staging project ${projectRef}`);
