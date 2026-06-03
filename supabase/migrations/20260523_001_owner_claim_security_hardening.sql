-- Harden cafe owner claims, transactional review, and owner-scoped cafe edits.

ALTER TABLE public.cafes
  ADD COLUMN IF NOT EXISTS owner_user_id uuid;

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
    WHERE c.conrelid = 'public.cafes'::regclass
      AND c.contype = 'f'
      AND a.attname = 'owner_user_id'
  LOOP
    EXECUTE format('ALTER TABLE public.cafes DROP CONSTRAINT IF EXISTS %I', constraint_name);
  END LOOP;
END $$;

ALTER TABLE public.cafes
  ADD CONSTRAINT cafes_owner_user_id_fkey
  FOREIGN KEY (owner_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS cafes_owner_user_id_idx
  ON public.cafes(owner_user_id);

CREATE TABLE IF NOT EXISTS public.cafe_owner_claims (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cafe_id text NOT NULL REFERENCES public.cafes(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending',
  message text,
  business_email text,
  business_phone text,
  evidence_url text,
  business_name text,
  phone text,
  note text,
  reviewed_by uuid REFERENCES auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.cafe_owner_claims
  ADD COLUMN IF NOT EXISTS message text,
  ADD COLUMN IF NOT EXISTS business_email text,
  ADD COLUMN IF NOT EXISTS business_phone text,
  ADD COLUMN IF NOT EXISTS evidence_url text,
  ADD COLUMN IF NOT EXISTS reviewed_by uuid,
  ADD COLUMN IF NOT EXISTS reviewed_at timestamptz,
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

DO $$
DECLARE
  constraint_name text;
BEGIN
  FOR constraint_name IN
    SELECT conname
    FROM pg_constraint
    WHERE conrelid = 'public.cafe_owner_claims'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) ILIKE '%status%'
  LOOP
    EXECUTE format(
      'ALTER TABLE public.cafe_owner_claims DROP CONSTRAINT IF EXISTS %I',
      constraint_name
    );
  END LOOP;
END $$;

ALTER TABLE public.cafe_owner_claims
  ADD CONSTRAINT cafe_owner_claims_status_check
  CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled'));

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
    WHERE c.conrelid = 'public.cafe_owner_claims'::regclass
      AND c.contype = 'f'
      AND a.attname IN ('user_id', 'reviewed_by')
  LOOP
    EXECUTE format(
      'ALTER TABLE public.cafe_owner_claims DROP CONSTRAINT IF EXISTS %I',
      constraint_name
    );
  END LOOP;
END $$;

ALTER TABLE public.cafe_owner_claims
  ADD CONSTRAINT cafe_owner_claims_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  ADD CONSTRAINT cafe_owner_claims_reviewed_by_fkey
  FOREIGN KEY (reviewed_by) REFERENCES auth.users(id);

CREATE INDEX IF NOT EXISTS cafe_owner_claims_user_id_idx
  ON public.cafe_owner_claims(user_id);

CREATE INDEX IF NOT EXISTS cafe_owner_claims_cafe_id_idx
  ON public.cafe_owner_claims(cafe_id);

CREATE INDEX IF NOT EXISTS cafe_owner_claims_status_idx
  ON public.cafe_owner_claims(status);

CREATE UNIQUE INDEX IF NOT EXISTS cafe_owner_claims_one_pending_per_user_cafe
  ON public.cafe_owner_claims(user_id, cafe_id)
  WHERE status = 'pending';

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS cafe_owner_claims_set_updated_at
  ON public.cafe_owner_claims;
CREATE TRIGGER cafe_owner_claims_set_updated_at
  BEFORE UPDATE ON public.cafe_owner_claims
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE FUNCTION public.app_is_admin(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = p_user_id
      AND (
        lower(coalesce(to_jsonb(p) ->> 'role', '')) = 'admin'
        OR lower(coalesce(to_jsonb(p) ->> 'is_admin', '')) IN ('true', 't', '1')
      )
  );
$$;

ALTER TABLE public.cafe_owner_claims ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can create own cafe owner claims" ON public.cafe_owner_claims;
CREATE POLICY "Users can create own cafe owner claims"
  ON public.cafe_owner_claims
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND status = 'pending'
    AND reviewed_at IS NULL
    AND reviewed_by IS NULL
  );

DROP POLICY IF EXISTS "Users can read own cafe owner claims" ON public.cafe_owner_claims;
CREATE POLICY "Users can read own cafe owner claims"
  ON public.cafe_owner_claims
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can cancel own pending cafe owner claims" ON public.cafe_owner_claims;
CREATE POLICY "Users can cancel own pending cafe owner claims"
  ON public.cafe_owner_claims
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id AND status = 'pending')
  WITH CHECK (
    auth.uid() = user_id
    AND status = 'cancelled'
    AND reviewed_at IS NULL
    AND reviewed_by IS NULL
  );

DROP POLICY IF EXISTS "Admins can read all cafe owner claims" ON public.cafe_owner_claims;
CREATE POLICY "Admins can read all cafe owner claims"
  ON public.cafe_owner_claims
  FOR SELECT
  TO authenticated
  USING (public.app_is_admin(auth.uid()));

DROP POLICY IF EXISTS "Admins can review cafe owner claims" ON public.cafe_owner_claims;
CREATE POLICY "Admins can review cafe owner claims"
ON public.cafe_owner_claims
FOR UPDATE
TO authenticated
USING (public.app_is_admin(auth.uid()))
WITH CHECK (public.app_is_admin(auth.uid()));

DROP POLICY IF EXISTS "Cafe owners can update owned cafes" ON public.cafes;

CREATE OR REPLACE FUNCTION public.owner_update_cafe(
  p_cafe_id text,
  p_updates jsonb
)
RETURNS SETOF public.cafes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  allowed_keys text[] := ARRAY[
    'name',
    'category',
    'district',
    'neighborhood',
    'address',
    'description',
    'price_level',
    'tags',
    'wifi_quality',
    'outlet_availability',
    'quietness_level',
    'study_friendly',
    'pet_friendly',
    'outdoor_seating',
    'smoking_policy',
    'opening_hours',
    'menu_highlights'
  ];
  disallowed_key text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;

  SELECT key INTO disallowed_key
  FROM jsonb_object_keys(coalesce(p_updates, '{}'::jsonb)) AS key
  WHERE NOT key = ANY (allowed_keys)
  LIMIT 1;

  IF disallowed_key IS NOT NULL THEN
    RAISE EXCEPTION 'Field "%" is not owner editable', disallowed_key
      USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.cafes c
    WHERE c.id = p_cafe_id
      AND c.owner_user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'You can only update cafes you own' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  UPDATE public.cafes
  SET
    name = CASE WHEN p_updates ? 'name' THEN p_updates ->> 'name' ELSE name END,
    category = CASE WHEN p_updates ? 'category' THEN p_updates ->> 'category' ELSE category END,
    district = CASE WHEN p_updates ? 'district' THEN p_updates ->> 'district' ELSE district END,
    neighborhood = CASE WHEN p_updates ? 'neighborhood' THEN p_updates ->> 'neighborhood' ELSE neighborhood END,
    address = CASE WHEN p_updates ? 'address' THEN p_updates ->> 'address' ELSE address END,
    description = CASE WHEN p_updates ? 'description' THEN p_updates ->> 'description' ELSE description END,
    price_level = CASE WHEN p_updates ? 'price_level' THEN p_updates ->> 'price_level' ELSE price_level END,
    tags = CASE WHEN p_updates ? 'tags' THEN p_updates -> 'tags' ELSE tags END,
    wifi_quality = CASE WHEN p_updates ? 'wifi_quality' THEN p_updates ->> 'wifi_quality' ELSE wifi_quality END,
    outlet_availability = CASE WHEN p_updates ? 'outlet_availability' THEN p_updates ->> 'outlet_availability' ELSE outlet_availability END,
    quietness_level = CASE WHEN p_updates ? 'quietness_level' THEN p_updates ->> 'quietness_level' ELSE quietness_level END,
    study_friendly = CASE WHEN p_updates ? 'study_friendly' THEN (p_updates ->> 'study_friendly')::boolean ELSE study_friendly END,
    pet_friendly = CASE WHEN p_updates ? 'pet_friendly' THEN (p_updates ->> 'pet_friendly')::boolean ELSE pet_friendly END,
    outdoor_seating = CASE WHEN p_updates ? 'outdoor_seating' THEN (p_updates ->> 'outdoor_seating')::boolean ELSE outdoor_seating END,
    smoking_policy = CASE WHEN p_updates ? 'smoking_policy' THEN p_updates ->> 'smoking_policy' ELSE smoking_policy END,
    opening_hours = CASE WHEN p_updates ? 'opening_hours' THEN p_updates -> 'opening_hours' ELSE opening_hours END,
    menu_highlights = CASE WHEN p_updates ? 'menu_highlights' THEN p_updates -> 'menu_highlights' ELSE menu_highlights END,
    google_uses_app_defaults = false
  WHERE id = p_cafe_id
    AND owner_user_id = auth.uid()
  RETURNING *;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_approve_cafe_owner_claim(p_claim_id uuid)
RETURNS SETOF public.cafe_owner_claims
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  claim_row public.cafe_owner_claims%ROWTYPE;
BEGIN
  IF NOT public.app_is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Admin privileges are required' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO claim_row
  FROM public.cafe_owner_claims
  WHERE id = p_claim_id
    AND status = 'pending'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Only pending claims can be approved' USING ERRCODE = '22000';
  END IF;

  UPDATE public.cafes
  SET owner_user_id = claim_row.user_id
  WHERE id = claim_row.cafe_id;

  UPDATE public.profiles p
  SET role = 'cafe_owner'
  WHERE p.id = claim_row.user_id
    AND lower(coalesce(to_jsonb(p) ->> 'role', '')) <> 'admin'
    AND lower(coalesce(to_jsonb(p) ->> 'is_admin', '')) NOT IN ('true', 't', '1');

  RETURN QUERY
  UPDATE public.cafe_owner_claims
  SET
    status = 'approved',
    reviewed_by = auth.uid(),
    reviewed_at = now()
  WHERE id = p_claim_id
  RETURNING *;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_reject_cafe_owner_claim(
  p_claim_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS SETOF public.cafe_owner_claims
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.app_is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Admin privileges are required' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  UPDATE public.cafe_owner_claims
  SET
    status = 'rejected',
    reviewed_by = auth.uid(),
    reviewed_at = now(),
    message = coalesce(nullif(trim(p_reason), ''), message)
  WHERE id = p_claim_id
    AND status = 'pending'
  RETURNING *;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Only pending claims can be rejected' USING ERRCODE = '22000';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.owner_update_cafe(text, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_approve_cafe_owner_claim(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reject_cafe_owner_claim(uuid, text) TO authenticated;
