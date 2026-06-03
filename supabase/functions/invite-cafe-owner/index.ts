import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type InviteBody = {
  cafe_id?: string;
  email?: string;
  first_name?: string;
  last_name?: string;
  full_name?: string;
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function inviteErrorResponse(
  stage: string,
  code: string,
  message: string,
  status = 500,
) {
  const body = {
    error: message,
    code,
    stage,
  };
  console.error(
    `[invite-cafe-owner] stage=${stage} code=${code} status=${status} message=${message}`,
  );
  return jsonResponse(body, status);
}

function cleanText(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length === 0 ? null : trimmed.slice(0, 160);
}

function isMissingColumnError(error: unknown, column: string): boolean {
  const message = String((error as { message?: unknown })?.message ?? error)
    .toLowerCase();
  return message.includes(column.toLowerCase()) &&
    (message.includes("does not exist") || message.includes("schema cache"));
}

function isAlreadyRegisteredError(error: unknown): boolean {
  const message = String((error as { message?: unknown })?.message ?? error)
    .toLowerCase();
  return message.includes("already registered") ||
    message.includes("already been registered") ||
    message.includes("already exists") ||
    message.includes("user exists");
}

function metadataText(
  metadata: Record<string, unknown>,
  key: string,
): string | null {
  const value = metadata[key];
  return typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : null;
}

function usernameFromEmail(email: string): string {
  const localPart = email.split("@")[0] ?? "owner";
  const normalized = localPart
    .toLowerCase()
    .replace(/[^a-z0-9._]/g, "_")
    .replace(/[._]{2,}/g, "_")
    .replace(/^[._]+|[._]+$/g, "");
  const base = normalized.length >= 3 ? normalized : `owner_${normalized}`;
  return base.slice(0, 24);
}

async function findAuthUserByEmail(
  adminClient: ReturnType<typeof createClient>,
  email: string,
) {
  const normalizedEmail = email.toLowerCase();
  const perPage = 1000;
  for (let page = 1; page <= 20; page += 1) {
    const { data, error } = await adminClient.auth.admin.listUsers({
      page,
      perPage,
    });
    if (error) {
      return { user: null, error };
    }
    const users = data?.users ?? [];
    const user = users.find((candidate) =>
      String(candidate.email ?? "").toLowerCase() === normalizedEmail
    );
    if (user) {
      return { user, error: null };
    }
    if (users.length < perPage) {
      break;
    }
  }
  return { user: null, error: null };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return inviteErrorResponse(
      "configuration",
      "function_not_configured",
      "Cafe owner invite service is not configured.",
      500,
    );
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (!token) {
    return inviteErrorResponse(
      "authentication",
      "missing_session",
      "Authentication is required to invite cafe owners.",
      401,
    );
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false },
  });
  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  const { data: authData, error: authError } = await userClient.auth.getUser(
    token,
  );
  if (authError || !authData.user) {
    return inviteErrorResponse(
      "authentication",
      "invalid_session",
      "Your admin session is no longer valid. Sign in again.",
      401,
    );
  }

  let { data: callerProfile, error: callerError } = await adminClient
    .from("profiles")
    .select("id, role, is_admin")
    .eq("id", authData.user.id)
    .maybeSingle();
  if (callerError && isMissingColumnError(callerError, "is_admin")) {
    const fallback = await adminClient
      .from("profiles")
      .select("id, role")
      .eq("id", authData.user.id)
      .maybeSingle();
    callerProfile = fallback.data;
    callerError = fallback.error;
  }
  const callerIsAdmin = callerProfile?.is_admin === true ||
    String(callerProfile?.role ?? "").toLowerCase() === "admin";
  if (callerError || !callerIsAdmin) {
    return inviteErrorResponse(
      "authorization",
      "admin_required",
      "Admin privileges are required to invite cafe owners.",
      403,
    );
  }

  let body: InviteBody;
  try {
    body = await req.json();
  } catch (_) {
    return inviteErrorResponse(
      "validation",
      "invalid_json",
      "Invalid owner invite request.",
      400,
    );
  }

  const cafeId = cleanText(body.cafe_id);
  const email = cleanText(body.email)?.toLowerCase();
  const firstName = cleanText(body.first_name);
  const lastName = cleanText(body.last_name);
  const providedFullName = cleanText(body.full_name);
  const nameFromParts = [firstName, lastName]
    .filter((part) => part && part.length > 0)
    .join(" ");
  const fullName = providedFullName ?? (nameFromParts.length > 0
    ? nameFromParts
    : email);
  if (!cafeId || !email || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    return inviteErrorResponse(
      "validation",
      "invalid_request",
      "Cafe id and a valid owner email are required.",
      400,
    );
  }

  const { data: cafe, error: cafeError } = await adminClient
    .from("cafes")
    .select("id")
    .eq("id", cafeId)
    .maybeSingle();
  if (cafeError) {
    return inviteErrorResponse(
      "load_cafe",
      "cafe_lookup_failed",
      cafeError.message,
      500,
    );
  }
  if (!cafe) {
    return inviteErrorResponse(
      "load_cafe",
      "cafe_not_found",
      "Cafe not found.",
      404,
    );
  }

  const profileColumns =
    "id, email, first_name, last_name, full_name, username, role, is_admin, created_at, avatar_url";
  const profileColumnsFallback =
    "id, email, first_name, last_name, full_name, username, role, created_at";
  let activeProfileColumns = profileColumns;
  let { data: profile, error: profileError } = await adminClient
    .from("profiles")
    .select(activeProfileColumns)
    .ilike("email", email)
    .maybeSingle();
  if (
    profileError &&
    (isMissingColumnError(profileError, "is_admin") ||
      isMissingColumnError(profileError, "avatar_url"))
  ) {
    activeProfileColumns = profileColumnsFallback;
    const fallback = await adminClient
      .from("profiles")
      .select(activeProfileColumns)
      .ilike("email", email)
      .maybeSingle();
    profile = fallback.data;
    profileError = fallback.error;
  }
  if (profileError) {
    return inviteErrorResponse(
      "load_profile",
      "profile_lookup_failed",
      profileError.message,
      500,
    );
  }

  let invited = false;
  if (!profile) {
    const redirectTo = Deno.env.get("OWNER_INVITE_REDIRECT_URL") ?? undefined;
    const username = usernameFromEmail(email);
    const { data: inviteData, error: inviteError } = await adminClient.auth.admin
      .inviteUserByEmail(email, {
        data: {
          username,
          preferred_username: username,
          user_name: username,
          first_name: firstName,
          given_name: firstName,
          last_name: lastName,
          family_name: lastName,
          full_name: fullName,
          name: fullName,
          role: "cafe_owner",
        },
        redirectTo,
      });
    let invitedUser = inviteData.user;
    if (inviteError && isAlreadyRegisteredError(inviteError)) {
      const lookup = await findAuthUserByEmail(adminClient, email);
      if (lookup.error) {
        return inviteErrorResponse(
          "lookup_auth_user",
          "auth_user_lookup_failed",
          lookup.error.message,
          500,
        );
      }
      invitedUser = lookup.user;
    } else if (inviteError || !inviteData.user) {
      return inviteErrorResponse(
        "send_invite",
        "invite_failed",
        inviteError?.message ?? "Owner invite failed.",
        500,
      );
    }
    if (!invitedUser) {
      return inviteErrorResponse(
        "lookup_auth_user",
        "auth_user_missing_profile",
        "An auth user already exists for this email, but no matching profile could be created.",
        409,
      );
    }
    invited = !inviteError;
    const metadata = (invitedUser.user_metadata ?? {}) as Record<
      string,
      unknown
    >;
    const { data: upserted, error: upsertError } = await adminClient
      .from("profiles")
      .upsert({
        id: invitedUser.id,
        email: invitedUser.email ?? email,
        username: metadataText(metadata, "username") ??
          metadataText(metadata, "preferred_username") ??
          metadataText(metadata, "user_name") ?? username,
        first_name: firstName ?? metadataText(metadata, "first_name"),
        last_name: lastName ?? metadataText(metadata, "last_name"),
        full_name: fullName || metadataText(metadata, "full_name") ||
          (invitedUser.email ?? email),
        role: "cafe_owner",
      }, { onConflict: "id" })
      .select(activeProfileColumns)
      .single();
    if (upsertError) {
      return inviteErrorResponse(
        "upsert_profile",
        "profile_upsert_failed",
        upsertError.message,
        500,
      );
    }
    profile = upserted;
  } else {
    const preservesAdmin = profile.is_admin === true ||
      String(profile.role ?? "").toLowerCase() === "admin";
    const updatePayload: Record<string, unknown> = {
      email,
      first_name: firstName ?? profile.first_name,
      last_name: lastName ?? profile.last_name,
      full_name: fullName || profile.full_name || email,
    };
    if (!preservesAdmin) {
      updatePayload.role = "cafe_owner";
    }
    const { data: updatedProfile, error: updateError } = await adminClient
      .from("profiles")
      .update(updatePayload)
      .eq("id", profile.id)
      .select(activeProfileColumns)
      .single();
    if (updateError) {
      return inviteErrorResponse(
        "update_profile",
        "profile_update_failed",
        updateError.message,
        500,
      );
    }
    profile = updatedProfile;
  }

  let { data: updatedCafe, error: assignError } = await adminClient
    .from("cafes")
    .update({
      owner_user_id: profile.id,
      owner_approval_status: "approved",
      google_uses_app_defaults: false,
    })
    .eq("id", cafe.id)
    .select("*")
    .single();
  if (
    assignError && isMissingColumnError(assignError, "google_uses_app_defaults")
  ) {
    const fallback = await adminClient
      .from("cafes")
      .update({
        owner_user_id: profile.id,
        owner_approval_status: "approved",
      })
      .eq("id", cafe.id)
      .select("*")
      .single();
    updatedCafe = fallback.data;
    assignError = fallback.error;
  }
  if (assignError) {
    return inviteErrorResponse(
      "assign_cafe",
      "cafe_assignment_failed",
      assignError.message,
      500,
    );
  }

  return jsonResponse({
    owner: profile,
    cafe: updatedCafe,
    invited,
  });
});
