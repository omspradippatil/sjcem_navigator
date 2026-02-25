-- ===================================================
-- FIX RLS POLICIES FOR INSERT OPERATIONS
-- Run this in Supabase SQL Editor to fix the issue
-- ===================================================
-- Problem: Original policies used only USING(true) which
-- doesn't work for INSERT. INSERT requires WITH CHECK(true).

-- Drop all existing policies
DROP POLICY IF EXISTS "Allow all for branches" ON branches;
DROP POLICY IF EXISTS "Allow all for students" ON students;
DROP POLICY IF EXISTS "Allow all for teachers" ON teachers;
DROP POLICY IF EXISTS "Allow all for rooms" ON rooms;
DROP POLICY IF EXISTS "Allow all for subjects" ON subjects;
DROP POLICY IF EXISTS "Allow all for timetable" ON timetable;
DROP POLICY IF EXISTS "Allow all for branch_chat" ON branch_chat_messages;
DROP POLICY IF EXISTS "Allow all for private_messages" ON private_messages;
DROP POLICY IF EXISTS "Allow all for polls" ON polls;
DROP POLICY IF EXISTS "Allow all for poll_options" ON poll_options;
DROP POLICY IF EXISTS "Allow all for poll_votes" ON poll_votes;
DROP POLICY IF EXISTS "Allow all for announcements" ON announcements;
DROP POLICY IF EXISTS "Allow all for study_folders" ON study_folders;
DROP POLICY IF EXISTS "Allow all for study_files" ON study_files;
DROP POLICY IF EXISTS "HOD can update rooms" ON rooms;
DROP POLICY IF EXISTS "Allow all for teacher_subjects" ON teacher_subjects;
DROP POLICY IF EXISTS "Allow all for navigation_waypoints" ON navigation_waypoints;
DROP POLICY IF EXISTS "Allow all for waypoint_connections" ON waypoint_connections;
DROP POLICY IF EXISTS "Allow all for room_waypoint_connections" ON room_waypoint_connections;
DROP POLICY IF EXISTS "Allow all for teacher_location_history" ON teacher_location_history;

-- Enable RLS on all tables (safe to run even if already enabled)
ALTER TABLE branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE students ENABLE ROW LEVEL SECURITY;
ALTER TABLE teachers ENABLE ROW LEVEL SECURITY;
ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE timetable ENABLE ROW LEVEL SECURITY;
ALTER TABLE branch_chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE private_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE polls ENABLE ROW LEVEL SECURITY;
ALTER TABLE poll_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE poll_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_folders ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE navigation_waypoints ENABLE ROW LEVEL SECURITY;
ALTER TABLE waypoint_connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE room_waypoint_connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_location_history ENABLE ROW LEVEL SECURITY;

-- Create new policies with WITH CHECK for INSERT support
CREATE POLICY "Allow all for branches" ON branches FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for students" ON students FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for teachers" ON teachers FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for rooms" ON rooms FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for subjects" ON subjects FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for timetable" ON timetable FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for branch_chat" ON branch_chat_messages FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for private_messages" ON private_messages FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for polls" ON polls FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for poll_options" ON poll_options FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for poll_votes" ON poll_votes FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for announcements" ON announcements FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for study_folders" ON study_folders FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for study_files" ON study_files FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for teacher_subjects" ON teacher_subjects FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for navigation_waypoints" ON navigation_waypoints FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for waypoint_connections" ON waypoint_connections FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for room_waypoint_connections" ON room_waypoint_connections FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for teacher_location_history" ON teacher_location_history FOR ALL USING (true) WITH CHECK (true);

-- Re-grant permissions just in case
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO anon;

-- Success message
SELECT 'RLS policies fixed successfully! Sign-up and Admin Panel operations should now work.' as message;
