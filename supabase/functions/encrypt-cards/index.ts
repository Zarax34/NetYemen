/**
 * NetYemen — Admin Card Ingest Edge Function
 *
 * Encrypts a batch of plaintext internet card PINs with AES-256-GCM and
 * ingests the resulting envelopes via `admin_ingest_card_vault_batch`.
 *
 * Flow (see docs/CARD-ENCRYPTION-DESIGN.md):
 *   1. Verify the caller is `platform_admin` (via `has_platform_role`, using
 *      the caller's own JWT — no service-role key is used by this function).
 *   2. Encrypt each plaintext PIN in memory with the active AES-256-GCM key.
 *   3. Call `admin_ingest_card_vault_batch` with the encrypted envelopes;
 *      the RPC re-validates authorization server-side and performs the
 *      insert atomically.
 *
 * Plaintext PINs are held in memory only for the duration of the request
 * and are NEVER logged, echoed back, or persisted outside `card_vault`.
 *
 * Required environment variables (Supabase Edge Function secrets):
 *   - SUPABASE_URL                   (auto-provided)
 *   - SUPABASE_ANON_KEY              (auto-provided)
 *   - CARD_MASTER_KEY_<VERSION>      (base64-encoded 32-byte AES-256 key,
 *                                     e.g. CARD_MASTER_KEY_V1 for key_version "v1")
 *   - CARD_ACTIVE_KEY_VERSION        (optional, default "v1"; which key
 *                                     version to encrypt new cards with when
 *                                     the request does not specify one)
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.0";
import { aes256GcmEncrypt, getCardMasterKey } from "../_shared/crypto.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const MAX_CARDS_PER_BATCH = 500;
const MAX_PIN_LENGTH = 128;
const MAX_REQUEST_BYTES = 262_144; // 256 KiB

interface IngestCardInput {
  plaintext_pin: string;
  expires_at?: string;
}

interface IngestRequestPayload {
  network_id: string;
  package_id: string;
  key_version?: string;
  cards: IngestCardInput[];
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "METHOD_NOT_ALLOWED" }, 405);
  }

  const authHeader = request.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ error: "UNAUTHENTICATED" }, 401);
  }

  let rawBody: string;
  let body: unknown;
  try {
    rawBody = await request.text();
    if (new TextEncoder().encode(rawBody).byteLength > MAX_REQUEST_BYTES) {
      return jsonResponse({ error: "REQUEST_TOO_LARGE" }, 413);
    }
    body = JSON.parse(rawBody);
  } catch {
    return jsonResponse({ error: "INVALID_REQUEST" }, 400);
  }

  let payload: IngestRequestPayload;
  try {
    payload = validatePayload(body);
  } catch (error) {
    return jsonResponse({ error: "INVALID_REQUEST", message: safeMessage(error) }, 400);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !anonKey) {
    console.error("encrypt-cards server configuration is incomplete");
    return jsonResponse({ error: "SERVICE_UNAVAILABLE" }, 503);
  }

  // Client acts AS THE CALLER (their JWT is forwarded, never a service-role
  // key) so both the role check and the ingest RPC run under the caller's
  // own auth.uid() — matching how `admin_ingest_card_vault_batch` itself
  // re-validates the caller.
  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: isPlatformAdmin, error: roleError } = await callerClient.rpc(
    "has_platform_role",
    { p_role: "platform_admin" },
  );
  if (roleError) {
    console.error("encrypt-cards role check failed:", roleError.message);
    return jsonResponse({ error: "FORBIDDEN_ROLE" }, 403);
  }
  if (!isPlatformAdmin) {
    return jsonResponse({ error: "FORBIDDEN_ROLE" }, 403);
  }

  const keyVersion = payload.key_version?.trim() || Deno.env.get("CARD_ACTIVE_KEY_VERSION") || "v1";

  let cardKey: CryptoKey;
  try {
    cardKey = await getCardMasterKey(keyVersion);
  } catch (error) {
    console.error("encrypt-cards key load failed:", safeMessage(error));
    return jsonResponse({ error: "SERVICE_UNAVAILABLE", status: "key_not_configured" }, 503);
  }

  const envelopes: Record<string, unknown>[] = [];
  try {
    for (const card of payload.cards) {
      const encrypted = await aes256GcmEncrypt(cardKey, card.plaintext_pin);
      envelopes.push({
        ciphertext: encrypted.ciphertextB64,
        nonce: encrypted.nonce,
        auth_tag: encrypted.authTagB64,
        expires_at: card.expires_at ?? null,
      });
    }
  } catch (error) {
    // Never log plaintext or ciphertext material — only the failure class.
    console.error("encrypt-cards encryption step failed:", safeMessage(error));
    return jsonResponse({ error: "ENCRYPTION_FAILED" }, 500);
  }

  const { data: ingestResult, error: ingestError } = await callerClient.rpc(
    "admin_ingest_card_vault_batch",
    {
      p_network_id: payload.network_id,
      p_package_id: payload.package_id,
      p_cards: envelopes,
      p_key_version: keyVersion,
    },
  );

  if (ingestError) {
    console.error("encrypt-cards ingest RPC failed:", ingestError.message);
    return mapPostgrestError(ingestError.message);
  }

  return jsonResponse({ ...ingestResult, key_version: keyVersion }, 200);
});

function validatePayload(body: unknown): IngestRequestPayload {
  if (typeof body !== "object" || body === null) {
    throw new Error("Request body must be a JSON object.");
  }
  const candidate = body as Record<string, unknown>;

  if (typeof candidate.network_id !== "string" || candidate.network_id.trim().length === 0) {
    throw new Error("network_id is required.");
  }
  if (typeof candidate.package_id !== "string" || candidate.package_id.trim().length === 0) {
    throw new Error("package_id is required.");
  }
  if (candidate.key_version !== undefined && typeof candidate.key_version !== "string") {
    throw new Error("key_version must be a string when provided.");
  }
  if (!Array.isArray(candidate.cards) || candidate.cards.length === 0) {
    throw new Error("cards must be a non-empty array.");
  }
  if (candidate.cards.length > MAX_CARDS_PER_BATCH) {
    throw new Error(`cards batch exceeds the maximum of ${MAX_CARDS_PER_BATCH}.`);
  }

  const cards: IngestCardInput[] = candidate.cards.map((raw, index) => {
    if (typeof raw !== "object" || raw === null) {
      throw new Error(`cards[${index}] must be an object.`);
    }
    const card = raw as Record<string, unknown>;
    if (typeof card.plaintext_pin !== "string" || card.plaintext_pin.trim().length === 0) {
      throw new Error(`cards[${index}].plaintext_pin is required.`);
    }
    if (card.plaintext_pin.length > MAX_PIN_LENGTH) {
      throw new Error(`cards[${index}].plaintext_pin exceeds the maximum length.`);
    }
    if (card.expires_at !== undefined && card.expires_at !== null && typeof card.expires_at !== "string") {
      throw new Error(`cards[${index}].expires_at must be a string when provided.`);
    }
    return {
      plaintext_pin: card.plaintext_pin,
      expires_at: (card.expires_at as string | undefined) ?? undefined,
    };
  });

  return {
    network_id: candidate.network_id,
    package_id: candidate.package_id,
    key_version: candidate.key_version as string | undefined,
    cards,
  };
}

function mapPostgrestError(message: string): Response {
  const code = message.split(":")[0].trim();
  switch (code) {
    case "UNAUTHENTICATED":
      return jsonResponse({ error: code }, 401);
    case "FORBIDDEN_ROLE":
    case "INACTIVE_PROFILE":
      return jsonResponse({ error: code }, 403);
    case "INVALID_PACKAGE_REFERENCE":
    case "INVALID_CARDS":
    case "INVALID_CARD":
      return jsonResponse({ error: code, message }, 400);
    default:
      return jsonResponse({ error: "INGEST_FAILED" }, 500);
  }
}

function safeMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

function jsonResponse(body: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
    },
  });
}
