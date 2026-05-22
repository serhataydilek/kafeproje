-- Supabase Migration: Create cafe_reviews table

CREATE TABLE IF NOT EXISTS cafe_reviews (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  cafe_id text NOT NULL,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  rating smallint NOT NULL CHECK (rating >= 1 AND rating <= 5),
  content text,
  created_at timestamptz DEFAULT now() NOT NULL
);

-- Enable Row Level Security
ALTER TABLE cafe_reviews ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can read reviews
CREATE POLICY "Reviews are viewable by everyone."
  ON cafe_reviews FOR SELECT
  USING (true);

-- Policy: Authenticated users can insert their own reviews
CREATE POLICY "Authenticated users can insert their own reviews."
  ON cafe_reviews FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own reviews
CREATE POLICY "Users can update their own reviews."
  ON cafe_reviews FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Policy: Users can delete their own reviews
CREATE POLICY "Users can delete their own reviews."
  ON cafe_reviews FOR DELETE
  USING (auth.uid() = user_id);

-- Create an index for faster lookups by cafe_id
CREATE INDEX IF NOT EXISTS idx_cafe_reviews_cafe_id ON cafe_reviews(cafe_id);
-- Create an index for faster lookups by user_id
CREATE INDEX IF NOT EXISTS idx_cafe_reviews_user_id ON cafe_reviews(user_id);
