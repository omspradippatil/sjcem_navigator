-- Migration: Add 'batch' column to students table
-- Run this in Supabase SQL Editor (Dashboard > SQL Editor > New query)
-- This allows students to be assigned to a practical batch (B1, B2, etc.)

ALTER TABLE students ADD COLUMN IF NOT EXISTS batch VARCHAR(10);

-- Optional: Update existing students with a default batch if needed
-- UPDATE students SET batch = 'B1' WHERE batch IS NULL;
