-- Supabase Migration: Enforce backend review mutation rate limiting.
--
-- The Flutter client also applies a 30-second submission cooldown, but client
-- throttles are advisory. This trigger enforces the same boundary in Postgres
-- so direct API callers cannot bypass it.

CREATE TABLE IF NOT EXISTS public.cafe_review_rate_limits (
  user_id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  last_mutation_at timestamptz NOT NULL DEFAULT '-infinity'::timestamptz
);

ALTER TABLE public.cafe_review_rate_limits ENABLE ROW LEVEL SECURITY;

-- This table is internal enforcement state. Clients should not read or mutate it
-- directly; the SECURITY DEFINER trigger function owns the writes.
REVOKE ALL ON TABLE public.cafe_review_rate_limits FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.enforce_cafe_review_mutation_rate_limit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  effective_user_id uuid;
  cooldown interval := interval '30 seconds';
  attempted_at timestamptz := clock_timestamp();
  updated_rows integer;
BEGIN
  effective_user_id := auth.uid();

  IF effective_user_id IS NULL THEN
    RAISE EXCEPTION 'Review rate limit requires an authenticated user.'
      USING ERRCODE = '42501';
  END IF;

  IF TG_OP = 'INSERT' AND NEW.user_id IS DISTINCT FROM effective_user_id THEN
    RAISE EXCEPTION 'Cannot create a review for another user.'
      USING ERRCODE = '42501';
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF OLD.user_id IS DISTINCT FROM effective_user_id THEN
      RAISE EXCEPTION 'Cannot update another user''s review.'
        USING ERRCODE = '42501';
    END IF;

    IF NEW.user_id IS DISTINCT FROM OLD.user_id THEN
      RAISE EXCEPTION 'Cannot transfer review ownership.'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  IF TG_OP = 'DELETE' AND OLD.user_id IS DISTINCT FROM effective_user_id THEN
    RAISE EXCEPTION 'Cannot delete another user''s review.'
      USING ERRCODE = '42501';
  END IF;

  LOOP
    UPDATE public.cafe_review_rate_limits
    SET last_mutation_at = attempted_at
    WHERE user_id = effective_user_id
      AND last_mutation_at <= attempted_at - cooldown;

    GET DIAGNOSTICS updated_rows = ROW_COUNT;
    IF updated_rows = 1 THEN
      EXIT;
    END IF;

    BEGIN
      INSERT INTO public.cafe_review_rate_limits (user_id, last_mutation_at)
      VALUES (effective_user_id, attempted_at);
      EXIT;
    EXCEPTION
      WHEN unique_violation THEN
        RAISE EXCEPTION 'Review submission rate limit exceeded. Try again in 30 seconds.'
          USING ERRCODE = 'P0001';
    END;

    RAISE EXCEPTION 'Review submission rate limit exceeded. Try again in 30 seconds.'
      USING ERRCODE = 'P0001';
  END LOOP;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS cafe_reviews_rate_limit_trigger ON public.cafe_reviews;

CREATE TRIGGER cafe_reviews_rate_limit_trigger
BEFORE INSERT OR UPDATE OR DELETE ON public.cafe_reviews
FOR EACH ROW
EXECUTE FUNCTION public.enforce_cafe_review_mutation_rate_limit();
