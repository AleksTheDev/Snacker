-- Migration: Add phone and location columns to offer table
-- Run this in Supabase SQL Editor: https://app.supabase.com/project/_/sql/new

-- Add phone column (optional, text)
ALTER TABLE offer ADD COLUMN IF NOT EXISTS phone TEXT;

-- Add location column (optional, text)
ALTER TABLE offer ADD COLUMN IF NOT EXISTS location TEXT;

-- Optional: Add comments to columns
COMMENT ON COLUMN offer.phone IS 'Phone number of the offer contact (10 digits)';
COMMENT ON COLUMN offer.location IS 'Location of the offer (e.g., city or district)';

-- Verify the table structure (optional, for testing)
-- SELECT * FROM offer LIMIT 1;
