-- Supabase Migration: Add community-driven fields to cafe_reviews table

ALTER TABLE cafe_reviews 
ADD COLUMN IF NOT EXISTS wifi_quality smallint CHECK (wifi_quality >= 1 AND wifi_quality <= 5),
ADD COLUMN IF NOT EXISTS noise_level smallint CHECK (noise_level >= 1 AND noise_level <= 5),
ADD COLUMN IF NOT EXISTS study_friendliness smallint CHECK (study_friendliness >= 1 AND study_friendliness <= 5),
ADD COLUMN IF NOT EXISTS seating_comfort smallint CHECK (seating_comfort >= 1 AND seating_comfort <= 5),
ADD COLUMN IF NOT EXISTS socket_availability text CHECK (socket_availability IN ('Yes', 'No', 'Unknown')),
ADD COLUMN IF NOT EXISTS smoking_policy text CHECK (smoking_policy IN ('allowed', 'not_allowed', 'mixed', 'unknown'));

-- Update existing rows that might have null for the new texts to 'Unknown' if necessary, 
-- though it's optional for new fields without DEFAULT to just remain NULL.
-- But setting a default for future inserts could be helpful if they aren't provided:
ALTER TABLE cafe_reviews
ALTER COLUMN socket_availability SET DEFAULT 'Unknown',
ALTER COLUMN smoking_policy SET DEFAULT 'unknown';
