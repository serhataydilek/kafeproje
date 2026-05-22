-- Foundation for cafe owner accounts and ownership claims.
-- No payment, subscription, Stripe, or ranking behavior is introduced here.

ALTER TABLE public.cafes
  ADD COLUMN IF NOT EXISTS owner_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS cafes_owner_user_id_idx
  ON public.cafes(owner_user_id);

CREATE TABLE IF NOT EXISTS public.cafe_owner_claims (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  cafe_id text NOT NULL REFERENCES public.cafes(id) ON DELETE CASCADE,
  business_name text NOT NULL,
  phone text,
  note text,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at timestamptz NOT NULL DEFAULT now(),
  reviewed_at timestamptz,
  reviewed_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS cafe_owner_claims_user_id_idx
  ON public.cafe_owner_claims(user_id);

CREATE INDEX IF NOT EXISTS cafe_owner_claims_cafe_id_idx
  ON public.cafe_owner_claims(cafe_id);

CREATE INDEX IF NOT EXISTS cafe_owner_claims_status_idx
  ON public.cafe_owner_claims(status);

CREATE UNIQUE INDEX IF NOT EXISTS cafe_owner_claims_one_pending_per_user_cafe
  ON public.cafe_owner_claims(user_id, cafe_id)
  WHERE status = 'pending';

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

DROP POLICY IF EXISTS "Admins can read all cafe owner claims" ON public.cafe_owner_claims;
CREATE POLICY "Admins can read all cafe owner claims"
  ON public.cafe_owner_claims
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.id = auth.uid()
        AND (
          lower(coalesce(to_jsonb(p) ->> 'role', '')) = 'admin'
          OR lower(coalesce(to_jsonb(p) ->> 'is_admin', '')) IN ('true', 't', '1')
        )
    )
  );

DROP POLICY IF EXISTS "Admins can review cafe owner claims" ON public.cafe_owner_claims;
CREATE POLICY "Admins can review cafe owner claims"
  ON public.cafe_owner_claims
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.id = auth.uid()
        AND (
          lower(coalesce(to_jsonb(p) ->> 'role', '')) = 'admin'
          OR lower(coalesce(to_jsonb(p) ->> 'is_admin', '')) IN ('true', 't', '1')
        )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.id = auth.uid()
        AND (
          lower(coalesce(to_jsonb(p) ->> 'role', '')) = 'admin'
          OR lower(coalesce(to_jsonb(p) ->> 'is_admin', '')) IN ('true', 't', '1')
        )
    )
  );

-- Extend cafes update policy so approved owners can update only their own cafe.
-- Existing admin policies from earlier migrations remain in place.
DROP POLICY IF EXISTS "Cafe owners can update owned cafes" ON public.cafes;
CREATE POLICY "Cafe owners can update owned cafes"
  ON public.cafes
  FOR UPDATE
  TO authenticated
  USING (owner_user_id = auth.uid())
  WITH CHECK (owner_user_id = auth.uid());
