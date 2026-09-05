-- NetYemen Local Verification Shim
-- Purpose: reproduce the minimal Supabase platform surface (auth schema, JWT
-- claim helpers, and the anon/authenticated/service_role grants) on a plain
-- PostgreSQL 16 cluster, so the migration set and the SQL contract suite can be
-- executed without Docker or the Supabase CLI.
--
-- This file is verification tooling only. It is never applied to a real
-- Supabase project, where the platform already provides every object below.

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ----------------------------------------------------------------------------
-- Platform roles
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        CREATE ROLE anon NOLOGIN NOINHERIT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        CREATE ROLE authenticated NOLOGIN NOINHERIT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
        CREATE ROLE service_role NOLOGIN NOINHERIT BYPASSRLS;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin') THEN
        CREATE ROLE supabase_admin NOLOGIN NOINHERIT SUPERUSER;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticator') THEN
        CREATE ROLE authenticator NOINHERIT LOGIN;
    END IF;
END
$$;

GRANT anon, authenticated, service_role TO authenticator;
GRANT anon, authenticated, service_role, supabase_admin TO postgres;

-- ----------------------------------------------------------------------------
-- auth schema
-- ----------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS auth AUTHORIZATION postgres;

CREATE TABLE IF NOT EXISTS auth.users (
    instance_id            UUID,
    id                     UUID PRIMARY KEY,
    aud                    VARCHAR(255) DEFAULT 'authenticated',
    role                   VARCHAR(255) DEFAULT 'authenticated',
    email                  VARCHAR(255) UNIQUE,
    encrypted_password     VARCHAR(255),
    email_confirmed_at     TIMESTAMPTZ,
    phone                  TEXT UNIQUE,
    phone_confirmed_at     TIMESTAMPTZ,
    confirmed_at           TIMESTAMPTZ,
    last_sign_in_at        TIMESTAMPTZ,
    raw_app_meta_data      JSONB DEFAULT '{}'::JSONB,
    raw_user_meta_data     JSONB DEFAULT '{}'::JSONB,
    is_super_admin         BOOLEAN,
    created_at             TIMESTAMPTZ DEFAULT NOW(),
    updated_at             TIMESTAMPTZ DEFAULT NOW(),
    banned_until           TIMESTAMPTZ,
    deleted_at             TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS auth.identities (
    provider_id     TEXT NOT NULL,
    user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    identity_data   JSONB NOT NULL DEFAULT '{}'::JSONB,
    provider        TEXT NOT NULL,
    last_sign_in_at TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    email           TEXT,
    id              UUID NOT NULL DEFAULT gen_random_uuid(),
    PRIMARY KEY (provider_id, provider)
);

-- ----------------------------------------------------------------------------
-- JWT claim helpers (identical semantics to the Supabase platform versions)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auth.jwt()
RETURNS JSONB
LANGUAGE SQL
STABLE
AS $$
    SELECT COALESCE(
        NULLIF(current_setting('request.jwt.claim', TRUE), ''),
        NULLIF(current_setting('request.jwt.claims', TRUE), ''),
        '{}'
    )::JSONB
$$;

CREATE OR REPLACE FUNCTION auth.uid()
RETURNS UUID
LANGUAGE SQL
STABLE
AS $$
    SELECT NULLIF(
        COALESCE(
            NULLIF(current_setting('request.jwt.claim.sub', TRUE), ''),
            (NULLIF(current_setting('request.jwt.claims', TRUE), '')::JSONB ->> 'sub')
        ),
        ''
    )::UUID
$$;

CREATE OR REPLACE FUNCTION auth.role()
RETURNS TEXT
LANGUAGE SQL
STABLE
AS $$
    SELECT COALESCE(
        NULLIF(current_setting('request.jwt.claim.role', TRUE), ''),
        (NULLIF(current_setting('request.jwt.claims', TRUE), '')::JSONB ->> 'role')
    )
$$;

CREATE OR REPLACE FUNCTION auth.email()
RETURNS TEXT
LANGUAGE SQL
STABLE
AS $$
    SELECT COALESCE(
        NULLIF(current_setting('request.jwt.claim.email', TRUE), ''),
        (NULLIF(current_setting('request.jwt.claims', TRUE), '')::JSONB ->> 'email')
    )
$$;

GRANT USAGE ON SCHEMA auth TO anon, authenticated, service_role;
GRANT SELECT ON auth.users TO service_role;
GRANT EXECUTE ON FUNCTION auth.uid(), auth.role(), auth.jwt(), auth.email()
    TO anon, authenticated, service_role;

-- ----------------------------------------------------------------------------
-- Default public-schema grants applied by the Supabase platform
-- ----------------------------------------------------------------------------
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

-- ----------------------------------------------------------------------------
-- Supabase CLI migration ledger
-- The CLI creates this table and records one row per applied migration. The
-- production verification scripts gate on it, so the local runner must record
-- versions here exactly as `supabase db reset` would.
-- ----------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS supabase_migrations AUTHORIZATION postgres;

CREATE TABLE IF NOT EXISTS supabase_migrations.schema_migrations (
    version    TEXT PRIMARY KEY,
    statements TEXT[],
    name       TEXT
);
