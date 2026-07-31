import "./guard-staging.mjs";

const baseURL = new URL(process.env.SUPABASE_URL);
const anonKey = process.env.SUPABASE_ANON_KEY;
const tables = [
  "organizations",
  "organization_members",
  "teams",
  "team_members",
  "seasons",
  "season_assignments",
  "invitations",
];

for (const table of tables) {
  const response = await fetch(
    new URL(`/rest/v1/${table}?select=id&limit=1`, baseURL),
    {
      headers: {
        apikey: anonKey,
        Authorization: `Bearer ${anonKey}`,
      },
    },
  );
  if (response.status === 401 || response.status === 403) {
    continue;
  }
  if (!response.ok) {
    throw new Error(`${table} verification failed (${response.status})`);
  }
  const rows = await response.json();
  if (!Array.isArray(rows) || rows.length !== 0) {
    throw new Error(`Anonymous access leaked rows from ${table}`);
  }
}

const rpcResponse = await fetch(
  new URL("/rest/v1/rpc/create_organization", baseURL),
  {
    method: "POST",
    headers: {
      apikey: anonKey,
      Authorization: `Bearer ${anonKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      organization_name: "Must Not Exist",
      organization_slug: "must-not-exist",
    }),
  },
);

if (rpcResponse.ok) {
  throw new Error("Anonymous organization creation unexpectedly succeeded");
}

console.log(
  `PASS: ${tables.length} Phase 6 tables hide rows from anonymous users`,
);
console.log("PASS: anonymous organization creation is rejected");
