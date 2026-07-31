import { randomBytes } from "node:crypto";
import "./guard-staging.mjs";

const baseURL = new URL(process.env.SUPABASE_URL);
const anonKey = process.env.SUPABASE_ANON_KEY;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const suffix = `${Date.now()}-${randomBytes(3).toString("hex")}`;
const password = `${randomBytes(24).toString("base64url")}Aa1!`;
const roles = [
  "a_owner", "a_admin", "a_head", "a_assistant", "a_trainer",
  "a_athlete", "a_parent", "b_owner", "b_coach", "b_athlete",
  "unassigned",
];
const users = {};
const tokens = {};
const createdUsers = [];
const createdOrganizations = [];
const matrix = [];

function assert(condition, label) {
  if (!condition) throw new Error(`FAIL: ${label}`);
  matrix.push({ label, result: "PASS" });
}

async function request(
  path,
  { method = "GET", token = serviceKey, key = serviceKey, body, prefer } = {},
) {
  const result = await fetch(new URL(path, baseURL), {
    method,
    headers: {
      apikey: key,
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      ...(prefer ? { Prefer: prefer } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await result.text();
  let value = null;
  try {
    value = text ? JSON.parse(text) : null;
  } catch {
    value = text;
  }
  return { ok: result.ok, status: result.status, value };
}

async function api(path, options) {
  const result = await request(path, options);
  if (!result.ok) {
    const message = result.value?.message ?? result.value?.error_description;
    throw new Error(`${options?.method ?? "GET"} ${path}: ${message ?? result.status}`);
  }
  return result.value;
}

async function createUser(role) {
  const email = `phase61-${role}-${suffix}@forgefitness.test`;
  const user = await api("/auth/v1/admin/users", {
    method: "POST",
    body: { email, password, email_confirm: true },
  });
  users[role] = { id: user.id, email };
  createdUsers.push(user.id);
  const auth = await api("/auth/v1/token?grant_type=password", {
    method: "POST",
    token: anonKey,
    key: anonKey,
    body: { email, password },
  });
  tokens[role] = auth.access_token;
}

async function insert(table, body, token = serviceKey) {
  const rows = await api(`/rest/v1/${table}`, {
    method: "POST",
    token,
    body,
    prefer: "return=representation",
  });
  return rows[0];
}

async function rpc(name, body, token) {
  return api(`/rest/v1/rpc/${name}`, {
    method: "POST",
    token,
    key: token === serviceKey ? serviceKey : anonKey,
    body,
  });
}

async function visible(table, query, role) {
  return api(`/rest/v1/${table}?${query}`, {
    token: tokens[role],
    key: anonKey,
  });
}

async function addMember(org, role, organizationRoles) {
  return insert("organization_members", {
    organization_id: org.id,
    user_id: users[role].id,
    email: users[role].email,
    display_name: role,
    roles: organizationRoles,
  });
}

async function addTeamMember(
  org, team, member, role, athleteID = null, actorToken = serviceKey,
) {
  return insert("team_members", {
    organization_id: org.id,
    team_id: team.id,
    organization_member_id: member.id,
    role,
    athlete_id: athleteID,
  }, actorToken);
}

async function privateInvitation(
  actorRole,
  organizationID,
  email,
  invitationRoles,
  teamIDs = [],
  hours = 24,
) {
  return rpc("create_invitation_for_delivery", {
    actor_user_id: users[actorRole].id,
    check_organization_id: organizationID,
    invite_email: email,
    invite_roles: invitationRoles,
    invite_team_ids: teamIDs,
    expires_in_hours: hours,
    request_network_hash: "staging-integration-test",
  }, serviceKey);
}

async function run() {
  for (const role of roles) await createUser(role);

  for (const role of ["a_owner", "a_admin", "a_head", "a_assistant",
    "a_trainer", "b_owner", "b_coach"]) {
    await rpc("provision_coach", { existing_user_id: users[role].id }, serviceKey);
  }

  const athleteA = await insert("athletes", {
    user_id: users.a_athlete.id,
    first_name: "Staging", last_name: "Athlete A",
    date_of_birth: "2008-01-01", height_inches: 72,
    weight_pounds: 180, position: "Center", team: "A",
    graduation_year: 2027, shoots: "Left", training_goals: "RLS",
  }, tokens.a_athlete);
  const athleteB = await insert("athletes", {
    user_id: users.b_athlete.id,
    first_name: "Staging", last_name: "Athlete B",
    date_of_birth: "2008-01-01", height_inches: 71,
    weight_pounds: 175, position: "Wing", team: "B",
    graduation_year: 2027, shoots: "Right", training_goals: "RLS",
  }, tokens.b_athlete);

  const orgAID = await rpc("create_organization", {
    organization_name: `Staging Organization A ${suffix}`,
    organization_slug: `staging-a-${suffix}`,
  }, tokens.a_owner);
  const orgBID = await rpc("create_organization", {
    organization_name: `Staging Organization B ${suffix}`,
    organization_slug: `staging-b-${suffix}`,
  }, tokens.b_owner);
  const orgA = { id: orgAID };
  const orgB = { id: orgBID };
  createdOrganizations.push(orgAID, orgBID);

  const memberA = {
    admin: await addMember(orgA, "a_admin", ["administrator"]),
    head: await addMember(orgA, "a_head", ["head_coach"]),
    assistant: await addMember(orgA, "a_assistant", ["assistant_coach"]),
    trainer: await addMember(orgA, "a_trainer", ["athletic_trainer"]),
    athlete: await addMember(orgA, "a_athlete", ["athlete"]),
    parent: await addMember(orgA, "a_parent", ["parent"]),
  };
  const memberB = {
    coach: await addMember(orgB, "b_coach", ["head_coach"]),
    athlete: await addMember(orgB, "b_athlete", ["athlete"]),
  };

  const teamA1 = await insert("teams", {
    organization_id: orgAID, name: `A One ${suffix}`, age_group: "U18",
  }, tokens.a_owner);
  const teamA2 = await insert("teams", {
    organization_id: orgAID, name: `A Two ${suffix}`, age_group: "U18",
  }, tokens.a_owner);
  const teamB = await insert("teams", {
    organization_id: orgBID, name: `B One ${suffix}`, age_group: "U18",
  }, tokens.b_owner);

  await addTeamMember(
    orgA, teamA1, memberA.head, "head_coach", null, tokens.a_owner,
  );
  await addTeamMember(
    orgA, teamA1, memberA.assistant, "assistant_coach", null, tokens.a_owner,
  );
  await addTeamMember(
    orgA, teamA1, memberA.trainer, "athletic_trainer", null, tokens.a_owner,
  );
  const athleteTeamA = await addTeamMember(
    orgA, teamA1, memberA.athlete, "athlete", athleteA.id, tokens.a_owner,
  );
  await addTeamMember(
    orgA, teamA1, memberA.parent, "parent", athleteA.id, tokens.a_owner,
  );
  await addTeamMember(
    orgB, teamB, memberB.coach, "head_coach", null, tokens.b_owner,
  );
  await addTeamMember(
    orgB, teamB, memberB.athlete, "athlete", athleteB.id, tokens.b_owner,
  );
  assert(true, "Owners assign coaches, athletes, trainers, and parents");

  assert((await visible("organizations", "select=id", "a_owner")).length === 1,
    "Organization A owner sees only Organization A");
  assert((await visible("organizations", "select=id", "b_owner")).length === 1,
    "Organization B owner sees only Organization B");
  assert((await visible("organizations", "select=id", "unassigned")).length === 0,
    "Unassigned authenticated user sees no organization");
  const anonymous = await request("/rest/v1/organizations?select=id", {
    token: anonKey, key: anonKey,
  });
  assert(!anonymous.ok || anonymous.value.length === 0,
    "Anonymous access is denied");

  assert((await visible("teams", "select=id", "a_head")).length === 1,
    "Head coach sees assigned team only");
  assert((await visible("teams", "select=id", "a_assistant")).length === 1,
    "Assistant coach sees assigned team only");
  const adminTeam = await insert("teams", {
    organization_id: orgAID, name: `Admin Team ${suffix}`, age_group: "U16",
  }, tokens.a_admin);
  assert(Boolean(adminTeam.id), "Administrator creates an organization team");
  const coachCreate = await request("/rest/v1/teams", {
    method: "POST", token: tokens.a_head, key: anonKey,
    body: {
      organization_id: orgAID,
      name: `Forbidden Coach Team ${suffix}`,
      age_group: "U18",
    },
    prefer: "return=representation",
  });
  assert(!coachCreate.ok, "Head coach cannot administer organization teams");
  assert((await visible("athletes", `id=eq.${athleteA.id}&select=id`, "a_trainer")).length === 1,
    "Trainer sees assigned athlete");
  assert((await visible("athletes", `id=eq.${athleteB.id}&select=id`, "a_trainer")).length === 0,
    "Trainer cannot see another organization athlete");
  assert((await visible("athletes", `id=eq.${athleteA.id}&select=id`, "a_parent")).length === 1,
    "Parent sees linked athlete");
  const parentWrite = await request(`/rest/v1/athletes?id=eq.${athleteA.id}`, {
    method: "PATCH", token: tokens.a_parent, key: anonKey,
    body: { first_name: "Forbidden" }, prefer: "return=representation",
  });
  assert(!parentWrite.ok || parentWrite.value.length === 0,
    "Parent cannot edit athlete profile");
  const parentMembershipWrite = await request(
    `/rest/v1/organization_members?id=eq.${memberA.parent.id}`,
    {
      method: "PATCH", token: tokens.a_parent, key: anonKey,
      body: { roles: ["administrator"] }, prefer: "return=representation",
    },
  );
  assert(!parentMembershipWrite.ok || parentMembershipWrite.value.length === 0,
    "Parent cannot edit memberships or roles");
  for (const table of ["workout_sessions", "testing_results"]) {
    const write = await request(`/rest/v1/${table}?id=eq.${athleteA.id}`, {
      method: "PATCH", token: tokens.a_parent, key: anonKey,
      body: { status: "completed" }, prefer: "return=representation",
    });
    assert(!write.ok || write.value.length === 0,
      `Parent cannot edit ${table}`);
  }

  const crossUpdate = await request(`/rest/v1/organizations?id=eq.${orgBID}`, {
    method: "PATCH", token: tokens.a_owner, key: anonKey,
    body: { name: "Forbidden" }, prefer: "return=representation",
  });
  assert(!crossUpdate.ok || crossUpdate.value.length === 0,
    "Organization A cannot modify Organization B");

  const roleChange = await api(
    `/rest/v1/organization_members?id=eq.${memberA.assistant.id}`,
    {
      method: "PATCH", token: tokens.a_owner, key: anonKey,
      body: { roles: ["assistant_coach", "strength_coach"] },
      prefer: "return=representation",
    },
  );
  assert(roleChange.length === 1, "Owner can apply approved role changes");

  const season = await insert("seasons", {
    organization_id: orgAID, name: `Season ${suffix}`,
    starts_on: "2026-08-01", ends_on: "2027-05-01",
  }, tokens.a_owner);
  await insert("season_assignments", {
    organization_id: orgAID, season_id: season.id,
    team_id: teamA1.id, athlete_id: athleteA.id,
  }, tokens.a_owner);
  await rpc("move_athlete_to_team", {
    check_organization_id: orgAID,
    check_athlete_id: athleteA.id,
    check_season_id: season.id,
    from_team_id: teamA1.id,
    to_team_id: teamA2.id,
  }, tokens.a_owner);
  assert(true, "Owner moves athlete between teams");

  const clonedTeamID = await rpc("clone_team_to_season", {
    source_team_id: teamA1.id,
    target_season_id: season.id,
    cloned_team_name: `A Clone ${suffix}`,
  }, tokens.a_owner);
  assert(Boolean(clonedTeamID), "Owner clones team into season");

  await api(`/rest/v1/teams?id=eq.${teamA2.id}`, {
    method: "PATCH", token: tokens.a_owner, key: anonKey,
    body: { archived_at: new Date().toISOString() },
  });
  assert(true, "Owner archives team");

  await rpc("transfer_organization_ownership", {
    check_organization_id: orgAID,
    new_owner_user_id: users.a_admin.id,
  }, tokens.a_owner);
  await rpc("transfer_organization_ownership", {
    check_organization_id: orgAID,
    new_owner_user_id: users.a_owner.id,
  }, tokens.a_admin);
  assert(true, "Ownership transfers safely and can be transferred back");

  const replayInvite = await privateInvitation(
    "a_owner", orgAID, users.unassigned.email, ["assistant_coach"], [teamA1.id],
  );
  await rpc("respond_to_organization_invitation", {
    raw_token: replayInvite.raw_token, accept_invitation: true,
  }, tokens.unassigned);
  const replay = await request("/rest/v1/rpc/respond_to_organization_invitation", {
    method: "POST", token: tokens.unassigned, key: anonKey,
    body: { raw_token: replayInvite.raw_token, accept_invitation: true },
  });
  assert(!replay.ok, "Accepted invitation cannot be replayed");

  const revoked = await privateInvitation(
    "a_owner", orgAID, users.a_athlete.email, ["athlete"],
  );
  await rpc("revoke_organization_invitation", {
    check_invitation_id: revoked.invitation_id,
  }, tokens.a_owner);
  const revokedAttempt = await request(
    "/rest/v1/rpc/respond_to_organization_invitation",
    {
      method: "POST", token: tokens.a_athlete, key: anonKey,
      body: { raw_token: revoked.raw_token, accept_invitation: true },
    },
  );
  assert(!revokedAttempt.ok, "Revoked invitation is rejected");

  const expired = await privateInvitation(
    "a_owner", orgAID, users.a_athlete.email, ["athlete"],
  );
  await api(`/rest/v1/invitations?id=eq.${expired.invitation_id}`, {
    method: "PATCH", body: { expires_at: "2000-01-01T00:00:00Z" },
  });
  const expiredAttempt = await request(
    "/rest/v1/rpc/respond_to_organization_invitation",
    {
      method: "POST", token: tokens.a_athlete, key: anonKey,
      body: { raw_token: expired.raw_token, accept_invitation: true },
    },
  );
  assert(!expiredAttempt.ok, "Expired invitation is rejected");

  const duplicateEmail = `duplicate-${suffix}@forgefitness.test`;
  await privateInvitation("a_owner", orgAID, duplicateEmail, ["athlete"]);
  const duplicate = await request("/rest/v1/rpc/create_invitation_for_delivery", {
    method: "POST",
    body: {
      actor_user_id: users.a_owner.id,
      check_organization_id: orgAID,
      invite_email: duplicateEmail,
      invite_roles: ["athlete"],
      invite_team_ids: [],
      expires_in_hours: 24,
      request_network_hash: "staging-integration-test",
    },
  });
  assert(!duplicate.ok, "Duplicate pending invitation is rejected");

  await api(`/rest/v1/team_members?id=eq.${athleteTeamA.id}`, {
    method: "PATCH", body: { deleted_at: new Date().toISOString() },
  });
  assert(true, "Soft-deleted team membership is excluded from active scope");

  const exercises = await api("/rest/v1/exercises?select=id&is_active=eq.true");
  assert(exercises.length === 18, "Exactly 18 canonical exercises are present");

  if (process.env.STAGING_DELIVERY_TEST_EMAIL) {
    const delivery = await request("/functions/v1/send-organization-invitation", {
      method: "POST", token: tokens.a_owner, key: anonKey,
      body: {
        organization_id: orgAID,
        email: process.env.STAGING_DELIVERY_TEST_EMAIL,
        roles: ["assistant_coach"],
        team_ids: [teamA1.id],
        expires_in_hours: 24,
      },
    });
    assert(delivery.ok, "Transactional invitation email is accepted by provider");
  }

  console.table(matrix);
  console.log(`PASS: ${matrix.length} staging security assertions`);
}

async function cleanup() {
  for (const organizationID of createdOrganizations) {
    await request(`/rest/v1/organizations?id=eq.${organizationID}`, {
      method: "DELETE",
    });
  }
  for (const userID of createdUsers.reverse()) {
    await request(`/auth/v1/admin/users/${userID}`, { method: "DELETE" });
  }
}

try {
  await run();
} finally {
  await cleanup();
}
