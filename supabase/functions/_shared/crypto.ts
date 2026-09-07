/**
 * Shared AES-256-GCM envelope encryption helpers for the card vault.
 *
 * - Keys are read ONLY from environment variables (Supabase Edge Function
 *   secrets). There is no built-in test-key fallback: if a key is missing,
 *   callers must fail closed, not silently encrypt/decrypt with a derived
 *   key. Local/dev testing sets its own env var to a locally generated
 *   32-byte base64 key — never a value checked into this repository.
 * - `card_vault.nonce` and `card_vault.auth_tag` are TEXT columns holding
 *   base64 already; `card_vault.ciphertext` is BYTEA. This module's
 *   base64-in/base64-out shape matches that layout directly, and matches
 *   the JSON keys `admin_ingest_card_vault_batch` and
 *   `reveal_purchase_card_secret` already use (`ciphertext`/`ciphertext_b64`,
 *   `nonce`, `auth_tag`/`auth_tag_b64`).
 */

const NONCE_BYTES = 12;
const AUTH_TAG_BYTES = 16;
const AES_KEY_BYTES = 32;

export interface EncryptedCardSecret {
  ciphertextB64: string;
  nonce: string;
  authTagB64: string;
}

/** `CARD_MASTER_KEY_<VERSION>` — version is uppercased, non-alphanumerics become `_`. */
function keyEnvVarName(keyVersion: string): string {
  const normalized = keyVersion.trim().toUpperCase().replace(/[^A-Z0-9]/g, "_");
  return `CARD_MASTER_KEY_${normalized}`;
}

/**
 * Loads the AES-256-GCM key for a given `key_version`. Throws
 * `KEY_NOT_CONFIGURED: <var>` if the corresponding secret is not set —
 * callers must map that to a 503, never derive a substitute key.
 */
export async function getCardMasterKey(keyVersion: string): Promise<CryptoKey> {
  if (!keyVersion || keyVersion.trim().length === 0) {
    throw new Error("INVALID_KEY_VERSION: key_version is required.");
  }

  const envVar = keyEnvVarName(keyVersion);
  const rawB64 = Deno.env.get(envVar);
  if (!rawB64) {
    throw new Error(`KEY_NOT_CONFIGURED: ${envVar}`);
  }

  return importAes256GcmKeyFromBase64(rawB64, envVar);
}

async function importAes256GcmKeyFromBase64(b64: string, envVar: string): Promise<CryptoKey> {
  const raw = base64ToUint8Array(b64);
  if (raw.length !== AES_KEY_BYTES) {
    throw new Error(`INVALID_KEY_LENGTH: ${envVar} must decode to 32 bytes for AES-256.`);
  }
  return crypto.subtle.importKey("raw", raw, "AES-GCM", false, ["encrypt", "decrypt"]);
}

/** Encrypts a plaintext card secret (e.g. a PIN) for storage in `card_vault`. */
export async function aes256GcmEncrypt(
  key: CryptoKey,
  plaintext: string,
): Promise<EncryptedCardSecret> {
  const iv = crypto.getRandomValues(new Uint8Array(NONCE_BYTES));
  const encoded = new TextEncoder().encode(plaintext);
  const encrypted = new Uint8Array(await crypto.subtle.encrypt({ name: "AES-GCM", iv }, key, encoded));

  const tagStart = encrypted.length - AUTH_TAG_BYTES;
  const ciphertext = encrypted.slice(0, tagStart);
  const authTag = encrypted.slice(tagStart);

  return {
    ciphertextB64: uint8ArrayToBase64(ciphertext),
    nonce: uint8ArrayToBase64(iv),
    authTagB64: uint8ArrayToBase64(authTag),
  };
}

/** Decrypts a `card_vault` envelope. Throws on tamper/wrong-key (GCM tag mismatch). */
export async function aes256GcmDecrypt(
  key: CryptoKey,
  ciphertextB64: string,
  nonce: string,
  authTagB64: string,
): Promise<string> {
  const ciphertext = base64ToUint8Array(ciphertextB64);
  const authTag = base64ToUint8Array(authTagB64);
  const iv = base64ToUint8Array(nonce);

  if (iv.length !== NONCE_BYTES) {
    throw new Error("INVALID_NONCE_LENGTH: AES-GCM nonce must be 12 bytes.");
  }
  if (authTag.length !== AUTH_TAG_BYTES) {
    throw new Error("INVALID_AUTH_TAG_LENGTH: AES-GCM auth tag must be 16 bytes.");
  }

  const combined = new Uint8Array(ciphertext.length + authTag.length);
  combined.set(ciphertext, 0);
  combined.set(authTag, ciphertext.length);

  const decrypted = await crypto.subtle.decrypt({ name: "AES-GCM", iv }, key, combined);
  return new TextDecoder().decode(decrypted);
}

function base64ToUint8Array(b64: string): Uint8Array {
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function uint8ArrayToBase64(bytes: Uint8Array): string {
  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}
