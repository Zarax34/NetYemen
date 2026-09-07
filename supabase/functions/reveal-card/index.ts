/**
 * NetYemen — Customer Card Reveal Edge Function
 *
 * Decrypts the internet card PIN for a completed purchase and returns it
 * ONLY to the verified purchaser.
 *
 * Flow (see docs/CARD-ENCRYPTION-DESIGN.md):
 *   1. Forward the caller's own JWT to `reveal_purchase_card_secret`. That
 *      RPC — not this function — is the authorization boundary: it checks
 *      `auth.uid()` against `purchase_records.user_id`, checks purchase and
 *      card state, and writes the `CARD_REVEALED` audit event. This function
 *      never accepts or trusts a purchaser id / envelope from the client.
 *   2. Decrypt the envelope the RPC returns with the AES-256-GCM key for its
 *      `key_version`.
 *   3. Return the plaintext PIN to the caller. It is never logged.
 *
 * Required environment variables (Supabase Edge Function secrets):
 *   - SUPABASE_URL                   (auto-provided)
 *   - SUPABASE_ANON_KEY              (auto-provided)
 *   - CARD_MASTER_KEY_<VERSION>      (base64-encoded 32-byte AES-256 key for
 *                                     every key_version still referenced by
 *                                     sold card_vault rows, until rotated out)
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.0";
import { aes256GcmDecrypt, getCardMasterKey } from "../_shared/crypto.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const MAX_REQUEST_BYTES = 4_096;

interface RevealRequestPayload {
  purchase_id: string;
}

interface CardSecretEnvelope {
  purchase_id: string;
  status: string;
  key_version: string;
  ciphertext_b64: string;
  nonce: string;
  auth_tag_b64: string;
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

  let payload: RevealRequestPayload;
  try {
    payload = validatePayload(body);
  } catch (error) {
    return jsonResponse({ error: "INVALID_REQUEST", message: safeMessage(error) }, 400);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !anonKey) {
    console.error("reveal-card server configuration is incomplete");
    return jsonResponse({ error: "SERVICE_UNAVAILABLE" }, 503);
  }

  // The caller's own JWT is forwarded — never a service-role key — so
  // `reveal_purchase_card_secret` runs as the requesting user and its own
  // purchaser-only + audit-logging checks apply in full.
  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: envelope, error: revealError } = await callerClient.rpc(
    "reveal_purchase_card_secret",
    { p_purchase_id: payload.purchase_id },
  );

  if (revealError) {
    console.error("reveal-card RPC failed:", revealError.message);
    return mapPostgrestError(revealError.message);
  }

  const secret = envelope as CardSecretEnvelope;

  let cardKey: CryptoKey;
  try {
    cardKey = await getCardMasterKey(secret.key_version);
  } catch (error) {
    console.error("reveal-card key load failed:", safeMessage(error));
    return jsonResponse({ error: "SERVICE_UNAVAILABLE", status: "key_not_configured" }, 503);
  }

  let plaintextPin: string;
  try {
    plaintextPin = await aes256GcmDecrypt(
      cardKey,
      secret.ciphertext_b64,
      secret.nonce,
      secret.auth_tag_b64,
    );
  } catch (error) {
    // Tamper / wrong-key / corrupt envelope. Never log plaintext or
    // ciphertext material — only the failure class.
    console.error("reveal-card decryption failed:", safeMessage(error));
    return jsonResponse({ error: "DECRYPTION_FAILED" }, 500);
  }

  return jsonResponse(
    { purchase_id: secret.purchase_id, status: secret.status, plaintext_pin: plaintextPin },
    200,
  );
});

function validatePayload(body: unknown): RevealRequestPayload {
  if (typeof body !== "object" || body === null) {
    throw new Error("Request body must be a JSON object.");
  }
  const candidate = body as Record<string, unknown>;
  if (typeof candidate.purchase_id !== "string" || candidate.purchase_id.trim().length === 0) {
    throw new Error("purchase_id is required.");
  }
  return { purchase_id: candidate.purchase_id };
}

function mapPostgrestError(message: string): Response {
  const code = message.split(":")[0].trim();
  switch (code) {
    case "UNAUTHENTICATED":
      return jsonResponse({ error: code }, 401);
    case "NOT_FOUND":
    case "CARD_NOT_ASSIGNED":
      return jsonResponse({ error: code }, 404);
    case "INVALID_STATE":
    case "CARD_BLOCKED":
    case "INVALID_CARD_STATE":
      return jsonResponse({ error: code, message }, 409);
    default:
      return jsonResponse({ error: "REVEAL_FAILED" }, 500);
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
