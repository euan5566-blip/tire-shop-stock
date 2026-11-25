-- Secure application accounts for the Neon migration.
-- The first owner account is created on first successful login using Vercel
-- OWNER_EMAIL and OWNER_PASSWORD environment variables. No public signup.
CREATE TABLE IF NOT EXISTS public.app_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL UNIQUE,
  password_hash text NOT NULL,
  full_name text NOT NULL DEFAULT '',
  role text NOT NULL DEFAULT 'owner' CHECK (role IN ('owner','manager','staff')),
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
