-- Allow cafe owner profiles to be stored with the canonical app role.
--
-- The owner invite Edge Function promotes invited owners by writing
-- profiles.role = 'cafe_owner'. Some live databases still have an older
-- profiles_role_check constraint that only allows the original roles.

DO $$
DECLARE
  constraint_name text;
BEGIN
  FOR constraint_name IN
    SELECT c.conname
    FROM pg_constraint c
    JOIN pg_attribute a
      ON a.attrelid = c.conrelid
     AND a.attnum = ANY (c.conkey)
    WHERE c.conrelid = 'public.profiles'::regclass
      AND c.contype = 'c'
      AND a.attname = 'role'
  LOOP
    EXECUTE format(
      'ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS %I',
      constraint_name
    );
  END LOOP;
END $$;

UPDATE public.profiles
SET role = 'user'
WHERE role IS NULL
   OR lower(role) NOT IN ('user', 'admin', 'cafe_owner');

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_role_check
  CHECK (lower(role) IN ('user', 'admin', 'cafe_owner'));
