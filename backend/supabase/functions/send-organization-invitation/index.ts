import { createClient } from "npm:@supabase/supabase-js@2";

type RequestBody = {
  organization_id: string;
  email: string;
  roles: string[];
  team_ids: string[];
  expires_in_hours: number;
};

const requiredEnvironment = [
  "SUPABASE_URL",
  "SUPABASE_ANON_KEY",
  "SUPABASE_SERVICE_ROLE_KEY",
  "RESEND_API_KEY",
  "INVITATION_FROM_EMAIL",
  "INVITATION_ACCEPT_URL",
  "APP_ENVIRONMENT",
  "FORGE_PRODUCTION_PROJECT_REF",
];

function response(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function sha256(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function escapeHTML(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return response(405, { success: false, error: "Method not allowed." });
  }

  for (const name of requiredEnvironment) {
    if (!Deno.env.get(name)) {
      return response(503, {
        success: false,
        error: "Invitation delivery is not configured.",
      });
    }
  }

  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return response(401, { success: false, error: "Authentication required." });
  }

  const url = Deno.env.get("SUPABASE_URL")!;
  const projectRef = new URL(url).hostname.split(".")[0];
  if (
    Deno.env.get("APP_ENVIRONMENT") !== "production" &&
    projectRef === Deno.env.get("FORGE_PRODUCTION_PROJECT_REF")
  ) {
    return response(503, {
      success: false,
      error: "Invitation environment safety check failed.",
    });
  }
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const userClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
  });
  const { data: userData, error: userError } =
    await userClient.auth.getUser(authorization.slice(7));
  if (userError || !userData.user) {
    return response(401, { success: false, error: "Authentication required." });
  }

  let body: RequestBody;
  try {
    body = await request.json();
  } catch {
    return response(400, { success: false, error: "Invalid request." });
  }

  const networkValue = request.headers.get("x-forwarded-for") ?? "";
  const networkHash = networkValue ? await sha256(networkValue) : "";
  const serviceClient = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: delivery, error: createError } = await serviceClient.rpc(
    "create_invitation_for_delivery",
    {
      actor_user_id: userData.user.id,
      check_organization_id: body.organization_id,
      invite_email: body.email,
      invite_roles: body.roles,
      invite_team_ids: body.team_ids,
      expires_in_hours: body.expires_in_hours,
      request_network_hash: networkHash,
    },
  );

  if (createError || !delivery) {
    const duplicate = createError?.code === "23505";
    const limited = createError?.message?.includes("rate limit");
    return response(limited ? 429 : 400, {
      success: false,
      error: duplicate
        ? "A pending invitation already exists for this email."
        : limited
          ? "Too many invitations. Please try again later."
          : "The invitation could not be created.",
    });
  }

  const token = delivery.raw_token as string;
  const acceptBase = Deno.env.get("INVITATION_ACCEPT_URL")!;
  const acceptanceURL = `${acceptBase}?code=${encodeURIComponent(token)}`;
  const environment = Deno.env.get("APP_ENVIRONMENT")!;
  const organizationName = String(delivery.organization_name);
  const subjectPrefix = environment === "production" ? "" : `[${environment.toUpperCase()}] `;
  const safeSubjectName = organizationName.replaceAll(/[\r\n]/g, " ");
  const subject = `${subjectPrefix}You're invited to ${safeSubjectName}`;
  const plainText = [
    `You have been invited to join ${organizationName} on Forge Fitness.`,
    `This invitation expires at ${delivery.expires_at}.`,
    `Open ${acceptanceURL}`,
    `Or enter this invitation code in Forge Fitness: ${token}`,
    "If you did not expect this invitation, you can ignore this email.",
  ].join("\n\n");
  const html = `
    <h1>Forge Fitness invitation</h1>
    <p>You have been invited to join <strong>${escapeHTML(organizationName)}</strong>.</p>
    <p><a href="${escapeHTML(acceptanceURL)}">Accept invitation</a></p>
    <p>Invitation code: <code>${token}</code></p>
    <p>This invitation expires at ${delivery.expires_at}.</p>
  `;

  const emailResponse = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${Deno.env.get("RESEND_API_KEY")}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: Deno.env.get("INVITATION_FROM_EMAIL"),
      to: [delivery.email],
      subject,
      html,
      text: plainText,
    }),
  });

  await serviceClient.rpc("complete_invitation_delivery", {
    check_invitation_id: delivery.invitation_id,
    was_delivered: emailResponse.ok,
    failure_code: emailResponse.ok ? null : `provider_${emailResponse.status}`,
  });

  if (!emailResponse.ok) {
    return response(502, {
      success: false,
      error: "The invitation email could not be delivered.",
    });
  }

  return response(200, {
    success: true,
    message: "Invitation email sent.",
  });
});
