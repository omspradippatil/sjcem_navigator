-- =============================================
-- DISABLE RLS ON device_tokens
-- Run this in Supabase SQL Editor
-- =============================================
-- The GitHub Actions workflow reads device_tokens using the anon key.
-- RLS blocks anon key reads by default, so we disable it for this table.
-- device_tokens contains no sensitive data (just UUIDs and push tokens).

ALTER TABLE device_tokens DISABLE ROW LEVEL SECURITY;
