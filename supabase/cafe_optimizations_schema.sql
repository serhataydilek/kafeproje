-- Supabase cafes policy compatibility fix
-- Resolves: ERROR 42703 column p.is_admin does not exist

ALTER TABLE cafes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Cafes are viewable by everyone" ON cafes;
CREATE POLICY "Cafes are viewable by everyone"
	ON cafes FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins can insert cafes" ON cafes;
CREATE POLICY "Admins can insert cafes"
	ON cafes FOR INSERT
	WITH CHECK (
		EXISTS (
			SELECT 1
			FROM profiles p
			WHERE p.id = auth.uid()
				AND (
					lower(coalesce(to_jsonb(p) ->> 'role', '')) = 'admin'
					OR lower(coalesce(to_jsonb(p) ->> 'is_admin', '')) IN ('true', 't', '1')
				)
		)
	);

DROP POLICY IF EXISTS "Admins can update cafes" ON cafes;
CREATE POLICY "Admins can update cafes"
	ON cafes FOR UPDATE
	USING (
		EXISTS (
			SELECT 1
			FROM profiles p
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
			FROM profiles p
			WHERE p.id = auth.uid()
				AND (
					lower(coalesce(to_jsonb(p) ->> 'role', '')) = 'admin'
					OR lower(coalesce(to_jsonb(p) ->> 'is_admin', '')) IN ('true', 't', '1')
				)
		)
	);
  