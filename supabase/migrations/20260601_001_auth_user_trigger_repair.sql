-- Keep Supabase Auth inserts non-blocking.
--
-- The app creates profiles after sign-up, and invite-cafe-owner upserts the
-- owner profile after inviteUserByEmail succeeds. A failing auth.users trigger
-- prevents Supabase Auth from saving the user at all and surfaces as:
-- "Database error saving new user".

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'handle_new_user ignored profile bootstrap failure for user %: %',
      NEW.id,
      SQLERRM;
    RETURN NEW;
END;
$$;

DO $$
DECLARE
  trigger_name text;
BEGIN
  FOR trigger_name IN
    SELECT t.tgname
    FROM pg_trigger t
    JOIN pg_proc p ON p.oid = t.tgfoid
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE t.tgrelid = 'auth.users'::regclass
      AND NOT t.tgisinternal
      AND n.nspname = 'public'
      AND p.proname = 'handle_new_user'
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS %I ON auth.users', trigger_name);
  END LOOP;
END $$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
