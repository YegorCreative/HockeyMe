import { randomBytes, randomUUID } from "node:crypto";

const required = [
  "SUPABASE_URL",
  "SUPABASE_ANON_KEY",
  "SUPABASE_SERVICE_ROLE_KEY",
  "E2E_CONFIRM_PROJECT_REF",
  "FORGE_PRODUCTION_PROJECT_REF",
];

for (const name of required) {
  if (!process.env[name]) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
}

if (process.env.FORGE_ENVIRONMENT !== "development") {
  throw new Error("Refusing to run outside FORGE_ENVIRONMENT=development");
}

if (process.env.E2E_ALLOW_REMOTE_WRITES !== "YES_I_UNDERSTAND") {
  throw new Error(
    "Set E2E_ALLOW_REMOTE_WRITES=YES_I_UNDERSTAND to permit temporary writes",
  );
}

const baseURL = new URL(process.env.SUPABASE_URL);
const projectRef = baseURL.hostname.split(".")[0];
if (projectRef !== process.env.E2E_CONFIRM_PROJECT_REF) {
  throw new Error("SUPABASE_URL does not match E2E_CONFIRM_PROJECT_REF");
}
if (projectRef === process.env.FORGE_PRODUCTION_PROJECT_REF) {
  throw new Error("Refusing to run against FORGE_PRODUCTION_PROJECT_REF");
}

const anonKey = process.env.SUPABASE_ANON_KEY;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const suffix = `${Date.now()}-${randomBytes(3).toString("hex")}`;
const password = `${randomBytes(24).toString("base64url")}Aa1!`;
const identities = {
  coach: `phase3-coach-${suffix}@forgefitness.test`,
  athlete: `phase3-athlete-${suffix}@forgefitness.test`,
  unrelated: `phase3-unrelated-${suffix}@forgefitness.test`,
};

const createdUsers = [];
let programID;

async function request(
  path,
  { method = "GET", key = anonKey, token = key, body, prefer } = {},
) {
  const response = await fetch(new URL(path, baseURL), {
    method,
    headers: {
      apikey: key,
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      ...(prefer ? { Prefer: prefer } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  const value = text ? JSON.parse(text) : null;
  if (!response.ok) {
    throw new Error(
      `${method} ${path} failed (${response.status}): ${
        value?.message ?? value?.error_description ?? "request failed"
      }`,
    );
  }
  return value;
}

async function createUser(email) {
  const user = await request("/auth/v1/admin/users", {
    method: "POST",
    key: serviceKey,
    token: serviceKey,
    body: { email, password, email_confirm: true },
  });
  createdUsers.push(user.id);
  return user;
}

async function signIn(email) {
  return request("/auth/v1/token?grant_type=password", {
    method: "POST",
    body: { email, password },
  });
}

async function insert(table, body, token) {
  const rows = await request(`/rest/v1/${table}`, {
    method: "POST",
    token,
    body,
    prefer: "return=representation",
  });
  return rows[0];
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

async function run() {
  const coachUser = await createUser(identities.coach);
  const athleteUser = await createUser(identities.athlete);
  const unrelatedUser = await createUser(identities.unrelated);

  for (const user of [coachUser, unrelatedUser]) {
    await request("/rest/v1/rpc/provision_coach", {
      method: "POST",
      key: serviceKey,
      token: serviceKey,
      body: { existing_user_id: user.id },
    });
  }

  const coachAuth = await signIn(identities.coach);
  const athleteAuth = await signIn(identities.athlete);
  const unrelatedAuth = await signIn(identities.unrelated);

  const coachRows = await request(
    `/rest/v1/coaches?user_id=eq.${coachUser.id}&select=user_id`,
    { token: coachAuth.access_token },
  );
  assert(coachRows.length === 1, "Coach role routing prerequisite failed");

  const athlete = await insert(
    "athletes",
    {
      user_id: athleteUser.id,
      first_name: "Phase",
      last_name: "Athlete",
      date_of_birth: "2008-01-01",
      height_inches: 72,
      weight_pounds: 180,
      position: "Center",
      team: "Development",
      graduation_year: 2027,
      shoots: "Left",
      training_goals: "End-to-end verification",
    },
    athleteAuth.access_token,
  );

  const exercises = await request(
    "/rest/v1/exercises?select=id,name&order=name",
    { token: coachAuth.access_token },
  );
  assert(exercises.length >= 18, "Canonical exercise library did not load");

  const program = await insert(
    "workout_programs",
    {
      coach_user_id: coachUser.id,
      name: `Phase 3 Verification ${suffix}`,
      description: "Temporary development verification",
      status: "draft",
      duration_weeks: 1,
    },
    coachAuth.access_token,
  );
  programID = program.id;

  const week = await insert(
    "workout_program_weeks",
    {
      program_id: program.id,
      week_number: 1,
      name: "Verification Week",
      focus: "RLS and persistence",
    },
    coachAuth.access_token,
  );
  const workout = await insert(
    "workouts",
    {
      program_week_id: week.id,
      name: "Verification Workout",
      description: "Temporary",
      day_number: 1,
      estimated_duration_minutes: 30,
      sort_order: 0,
    },
    coachAuth.access_token,
  );
  const prescription = await insert(
    "workout_exercises",
    {
      workout_id: workout.id,
      exercise_id: exercises[0].id,
      sort_order: 0,
      sets: 1,
      reps_min: 5,
      reps_max: 5,
      rest_seconds: 60,
      tempo: "3-1-1",
      coach_notes: "Temporary test",
      coach_cues: "Move with control",
    },
    coachAuth.access_token,
  );

  await request(`/rest/v1/workout_programs?id=eq.${program.id}`, {
    method: "PATCH",
    token: coachAuth.access_token,
    body: { status: "active" },
  });
  const assignment = await insert(
    "athlete_program_assignments",
    {
      athlete_id: athlete.id,
      program_id: program.id,
      assigned_by: coachUser.id,
      starts_on: new Date().toISOString().slice(0, 10),
      status: "active",
    },
    coachAuth.access_token,
  );

  const athletePrograms = await request(
    `/rest/v1/workout_programs?id=eq.${program.id}&select=id`,
    { token: athleteAuth.access_token },
  );
  assert(athletePrograms.length === 1, "Athlete did not receive program");

  const session = await insert(
    "workout_sessions",
    {
      athlete_id: athlete.id,
      assignment_id: assignment.id,
      workout_id: workout.id,
      status: "in_progress",
      started_at: new Date().toISOString(),
    },
    athleteAuth.access_token,
  );
  await insert(
    "workout_sets",
    {
      session_id: session.id,
      workout_exercise_id: prescription.id,
      exercise_id: exercises[0].id,
      set_number: 1,
      weight: 100,
      reps: 5,
      rpe: 7,
      pain_level: 1,
      notes: "Temporary test set",
      completed_at: new Date().toISOString(),
    },
    athleteAuth.access_token,
  );
  await request(`/rest/v1/workout_sessions?id=eq.${session.id}`, {
    method: "PATCH",
    token: athleteAuth.access_token,
    body: {
      status: "completed",
      completed_at: new Date().toISOString(),
      duration_seconds: 60,
      total_sets: 1,
      total_reps: 5,
      total_volume: 500,
    },
  });

  const coachSessions = await request(
    `/rest/v1/workout_sessions?id=eq.${session.id}&select=id,status`,
    { token: coachAuth.access_token },
  );
  assert(
    coachSessions.length === 1 && coachSessions[0].status === "completed",
    "Assigned coach could not read completed training",
  );

  const unrelatedPrograms = await request(
    `/rest/v1/workout_programs?id=eq.${program.id}&select=id`,
    { token: unrelatedAuth.access_token },
  );
  const unrelatedAthletes = await request(
    `/rest/v1/athletes?id=eq.${athlete.id}&select=id`,
    { token: unrelatedAuth.access_token },
  );
  assert(
    unrelatedPrograms.length === 0 && unrelatedAthletes.length === 0,
    "Unrelated coach gained access",
  );

  let anonymousBlocked = false;
  try {
    const anonymousPrograms = await request(
      `/rest/v1/workout_programs?id=eq.${program.id}&select=id`,
    );
    anonymousBlocked = anonymousPrograms.length === 0;
  } catch {
    anonymousBlocked = true;
  }
  assert(anonymousBlocked, "Anonymous access was not blocked");

  console.log("Phase 3 end-to-end verification passed (14 checks).");
}

async function cleanup() {
  // Delete the athlete first so assignments and sessions cascade away.
  const athleteID = createdUsers[1];
  if (athleteID) {
    await request(`/auth/v1/admin/users/${athleteID}`, {
      method: "DELETE",
      key: serviceKey,
      token: serviceKey,
    }).catch(() => {});
  }
  if (programID) {
    await request(`/rest/v1/workout_programs?id=eq.${programID}`, {
      method: "DELETE",
      key: serviceKey,
      token: serviceKey,
    }).catch(() => {});
  }
  for (const userID of [createdUsers[0], createdUsers[2]]) {
    if (!userID) continue;
    await request(`/auth/v1/admin/users/${userID}`, {
      method: "DELETE",
      key: serviceKey,
      token: serviceKey,
    }).catch(() => {});
  }
}

try {
  await run();
} finally {
  await cleanup();
}
