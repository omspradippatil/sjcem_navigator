-- =============================================
-- TEACHER LOCATION AUTO-UPDATE COMMANDS
-- =============================================
-- Run these commands to manually update teacher locations based on timetable
-- Since Supabase Free tier doesn't support pg_cron, these can be:
-- 1. Called from the app (already implemented in app code)
-- 2. Run manually via Supabase SQL Editor
-- 3. Automated via external scheduler (GitHub Actions, cron job, etc.)

-- =============================================
-- UPDATE SINGLE TEACHER LOCATION
-- =============================================
-- Updates a specific teacher's location based on their current scheduled class
-- Usage: SELECT auto_update_teacher_location('teacher_uuid_here');

-- Example:
-- SELECT auto_update_teacher_location('550e8400-e29b-41d4-a716-446655440000');


-- =============================================
-- UPDATE ALL TEACHER LOCATIONS
-- =============================================
-- Updates ALL active teachers' locations based on current timetable
-- Returns the count of teachers updated
-- Usage: SELECT auto_update_all_teacher_locations();

SELECT auto_update_all_teacher_locations();


-- =============================================
-- GET TEACHER'S SCHEDULED ROOM
-- =============================================
-- Get the room a teacher should be in right now based on timetable
-- Usage: SELECT get_teacher_scheduled_room('teacher_uuid_here');

-- Example:
-- SELECT get_teacher_scheduled_room('550e8400-e29b-41d4-a716-446655440000');


-- =============================================
-- GET TEACHER'S NEXT CLASS
-- =============================================
-- Get details about a teacher's next scheduled class today
-- Usage: SELECT * FROM get_teacher_next_class('teacher_uuid_here');

-- Example:
-- SELECT * FROM get_teacher_next_class('550e8400-e29b-41d4-a716-446655440000');


-- =============================================
-- VIEW CURRENT ONGOING CLASSES
-- =============================================
-- Shows all classes currently in session
SELECT 
    teacher_name,
    subject_name,
    room_display_name,
    branch_name,
    semester,
    start_time,
    end_time,
    batch
FROM current_ongoing_classes
ORDER BY branch_name, semester;


-- =============================================
-- VIEW TEACHERS WITH LOCATIONS
-- =============================================
-- Shows all teachers and their current locations
SELECT 
    name as teacher_name,
    current_room_display_name,
    current_floor,
    branch_name,
    current_room_updated_at
FROM teachers_with_location
WHERE current_room_id IS NOT NULL
ORDER BY branch_name, name;


-- =============================================
-- SYNC ALL LOCATIONS (ONE-TIME COMMAND)
-- =============================================
-- Run this to sync all teacher locations at once
-- This updates every teacher who has a class right now

DO $$
DECLARE
    updated_count INTEGER;
BEGIN
    SELECT auto_update_all_teacher_locations() INTO updated_count;
    RAISE NOTICE 'Updated % teacher locations', updated_count;
END $$;


-- =============================================
-- CLEAR STALE LOCATIONS
-- =============================================
-- Clear teacher locations that haven't been updated in X hours
-- Useful to clear locations when teachers forget to sign out

UPDATE teachers
SET current_room_id = NULL,
    current_room_updated_at = NULL
WHERE current_room_id IS NOT NULL
  AND current_room_updated_at < NOW() - INTERVAL '8 hours';


-- =============================================
-- BATCH UPDATE FOR SPECIFIC TIME
-- =============================================
-- Update all teachers for a specific time (useful for testing)
-- Change the time values as needed

CREATE OR REPLACE FUNCTION sync_teacher_locations_for_time(
    p_time TIME,
    p_day INTEGER DEFAULT EXTRACT(DOW FROM CURRENT_DATE)::INTEGER
)
RETURNS INTEGER AS $$
DECLARE
    v_teacher_record RECORD;
    v_updated_count INTEGER := 0;
    v_room_id UUID;
BEGIN
    FOR v_teacher_record IN 
        SELECT DISTINCT t.id 
        FROM teachers t
        INNER JOIN timetable tt ON tt.teacher_id = t.id
        WHERE t.is_active = true
    LOOP
        SELECT room_id INTO v_room_id
        FROM timetable
        WHERE teacher_id = v_teacher_record.id
          AND day_of_week = p_day
          AND start_time <= p_time
          AND end_time > p_time
          AND is_active = true
          AND is_break = false
        LIMIT 1;
        
        IF v_room_id IS NOT NULL THEN
            UPDATE teachers 
            SET current_room_id = v_room_id,
                current_room_updated_at = NOW()
            WHERE id = v_teacher_record.id
              AND (current_room_id IS DISTINCT FROM v_room_id);
            
            IF FOUND THEN
                v_updated_count := v_updated_count + 1;
            END IF;
        END IF;
    END LOOP;
    
    RETURN v_updated_count;
END;
$$ LANGUAGE plpgsql;

-- Example: Sync for 10:30 AM on current day
-- SELECT sync_teacher_locations_for_time('10:30:00');


-- =============================================
-- AUTOMATION OPTIONS
-- =============================================
-- Since Supabase free tier doesn't support pg_cron, here are alternatives:
--
-- 1. APP-BASED (Already implemented):
--    - App calls auto_update_teacher_location() when teacher logs in
--    - App runs a timer that checks every minute while running
--
-- 2. GITHUB ACTIONS (Recommended for free):
--    Create a GitHub Action that runs every 5-10 minutes:
--    
--    name: Sync Teacher Locations
--    on:
--      schedule:
--        - cron: '*/10 * * * *'  # Every 10 minutes
--    jobs:
--      sync:
--        runs-on: ubuntu-latest
--        steps:
--          - name: Sync locations
--            run: |
--              curl -X POST "$SUPABASE_URL/rest/v1/rpc/auto_update_all_teacher_locations" \
--                -H "apikey: $SUPABASE_ANON_KEY" \
--                -H "Authorization: Bearer $SUPABASE_ANON_KEY"
--
-- 3. VERCEL/CLOUDFLARE WORKERS:
--    Set up a serverless function that calls the sync endpoint
--
-- 4. EXTERNAL CRON SERVICE:
--    Use cron-job.org or similar to call the sync endpoint
