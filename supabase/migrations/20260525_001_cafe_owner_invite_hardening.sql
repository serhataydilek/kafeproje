-- Require the explicit cafe_owner role for owner-scoped cafe updates.
-- Being assigned in cafes.owner_user_id alone is not enough.

CREATE OR REPLACE FUNCTION public.owner_update_cafe(
  p_cafe_id text,
  p_updates jsonb
)
RETURNS SETOF public.cafes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
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

  IF NOT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND lower(coalesce(p.role, '')) = 'cafe_owner'
  ) THEN
    RAISE EXCEPTION 'Cafe owner role is required' USING ERRCODE = '42501';
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

REVOKE ALL ON FUNCTION public.owner_update_cafe(text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.owner_update_cafe(text, jsonb) TO authenticated;
