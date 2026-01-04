-- SJCEM Navigator Database Schema
-- Supabase Free Tier Compatible (NO pg_cron)
-- Run this in Supabase SQL Editor

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================
-- BRANCHES TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS branches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL UNIQUE,
    code VARCHAR(20) NOT NULL UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert default branches
INSERT INTO branches (name, code) VALUES 
    ('Artificial Intelligence & Data Science', 'AID'),
    ('Information Technology', 'IT'),
    ('Computer Engineering', 'COMP'),
    ('Mechanical Engineering', 'MECH'),
    ('Civil Engineering', 'CIVIL'),
    ('Electronics & Telecommunication', 'EXTC')
ON CONFLICT (code) DO NOTHING;

-- =============================================
-- STUDENTS TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS students (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(100) NOT NULL,
    roll_number VARCHAR(20) NOT NULL,
    branch_id UUID REFERENCES branches(id),
    semester INTEGER NOT NULL DEFAULT 1 CHECK (semester >= 1 AND semester <= 8),
    anonymous_id VARCHAR(20) NOT NULL UNIQUE,
    phone VARCHAR(20),
    is_active BOOLEAN DEFAULT TRUE,
    last_login TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for faster login
CREATE INDEX IF NOT EXISTS idx_students_email ON students(email);
CREATE INDEX IF NOT EXISTS idx_students_branch ON students(branch_id);

-- =============================================
-- TEACHERS TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS teachers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    branch_id UUID REFERENCES branches(id),
    is_hod BOOLEAN DEFAULT FALSE,
    is_admin BOOLEAN DEFAULT FALSE,
    current_room_id UUID,
    current_room_updated_at TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT TRUE,
    last_login TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for faster login
CREATE INDEX IF NOT EXISTS idx_teachers_email ON teachers(email);
CREATE INDEX IF NOT EXISTS idx_teachers_branch ON teachers(branch_id);

-- =============================================
-- ROOMS TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS rooms (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    room_number VARCHAR(20) NOT NULL UNIQUE,
    floor INTEGER NOT NULL DEFAULT 1,
    branch_id UUID REFERENCES branches(id),
    x_coordinate DOUBLE PRECISION NOT NULL,
    y_coordinate DOUBLE PRECISION NOT NULL,
    room_type VARCHAR(50) DEFAULT 'classroom',
    capacity INTEGER DEFAULT 60,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for room queries
CREATE INDEX IF NOT EXISTS idx_rooms_floor ON rooms(floor);
CREATE INDEX IF NOT EXISTS idx_rooms_type ON rooms(room_type);

-- Add foreign key for teacher current room (after rooms table is created)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_teacher_current_room'
    ) THEN
        ALTER TABLE teachers 
        ADD CONSTRAINT fk_teacher_current_room 
        FOREIGN KEY (current_room_id) REFERENCES rooms(id) ON DELETE SET NULL;
    END IF;
END $$;

-- =============================================
-- SUBJECTS TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS subjects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    code VARCHAR(20) NOT NULL UNIQUE,
    branch_id UUID REFERENCES branches(id),
    semester INTEGER NOT NULL CHECK (semester >= 1 AND semester <= 8),
    credits INTEGER DEFAULT 3,
    is_lab BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for subject queries
CREATE INDEX IF NOT EXISTS idx_subjects_branch_semester ON subjects(branch_id, semester);

-- =============================================
-- TEACHER-SUBJECT MAPPING
-- =============================================
CREATE TABLE IF NOT EXISTS teacher_subjects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    teacher_id UUID REFERENCES teachers(id) ON DELETE CASCADE,
    subject_id UUID REFERENCES subjects(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(teacher_id, subject_id)
);

-- =============================================
-- TIMETABLE TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS timetable (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    branch_id UUID REFERENCES branches(id),
    semester INTEGER NOT NULL CHECK (semester >= 1 AND semester <= 8),
    day_of_week INTEGER NOT NULL CHECK (day_of_week >= 0 AND day_of_week <= 6),
    period_number INTEGER NOT NULL CHECK (period_number >= 1 AND period_number <= 10),
    subject_id UUID REFERENCES subjects(id),
    teacher_id UUID REFERENCES teachers(id),
    room_id UUID REFERENCES rooms(id),
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(branch_id, semester, day_of_week, period_number)
);

-- Index for timetable queries
CREATE INDEX IF NOT EXISTS idx_timetable_lookup ON timetable(branch_id, semester, day_of_week);
CREATE INDEX IF NOT EXISTS idx_timetable_teacher ON timetable(teacher_id);

-- =============================================
-- BRANCH CHAT MESSAGES (Anonymous)
-- =============================================
CREATE TABLE IF NOT EXISTS branch_chat_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    branch_id UUID REFERENCES branches(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL,
    sender_type VARCHAR(20) NOT NULL CHECK (sender_type IN ('student', 'teacher')),
    anonymous_name VARCHAR(50) NOT NULL,
    message TEXT NOT NULL,
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for chat queries
CREATE INDEX IF NOT EXISTS idx_branch_chat_branch ON branch_chat_messages(branch_id, created_at DESC);

-- =============================================
-- PRIVATE MESSAGES (Student to Student)
-- =============================================
CREATE TABLE IF NOT EXISTS private_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sender_id UUID NOT NULL,
    receiver_id UUID NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    is_deleted_by_sender BOOLEAN DEFAULT FALSE,
    is_deleted_by_receiver BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for private message queries
CREATE INDEX IF NOT EXISTS idx_private_messages_conversation 
ON private_messages(sender_id, receiver_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_private_messages_unread 
ON private_messages(receiver_id, is_read) WHERE is_read = FALSE;

-- =============================================
-- POLLS TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS polls (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    branch_id UUID REFERENCES branches(id),
    created_by UUID REFERENCES teachers(id),
    is_active BOOLEAN DEFAULT TRUE,
    is_anonymous BOOLEAN DEFAULT TRUE,
    allow_multiple_votes BOOLEAN DEFAULT FALSE,
    ends_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for poll queries
CREATE INDEX IF NOT EXISTS idx_polls_branch ON polls(branch_id, is_active, created_at DESC);

-- =============================================
-- POLL OPTIONS TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS poll_options (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    poll_id UUID REFERENCES polls(id) ON DELETE CASCADE,
    option_text VARCHAR(255) NOT NULL,
    vote_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for poll options
CREATE INDEX IF NOT EXISTS idx_poll_options_poll ON poll_options(poll_id);

-- =============================================
-- POLL VOTES TABLE (Anonymous voting)
-- =============================================
CREATE TABLE IF NOT EXISTS poll_votes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    poll_id UUID REFERENCES polls(id) ON DELETE CASCADE,
    option_id UUID REFERENCES poll_options(id) ON DELETE CASCADE,
    student_id UUID REFERENCES students(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(poll_id, student_id)
);

-- =============================================
-- TEACHER LOCATION HISTORY (Optional tracking)
-- =============================================
CREATE TABLE IF NOT EXISTS teacher_location_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    teacher_id UUID REFERENCES teachers(id) ON DELETE CASCADE,
    room_id UUID REFERENCES rooms(id),
    action VARCHAR(20) DEFAULT 'enter',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for location history
CREATE INDEX IF NOT EXISTS idx_teacher_location_history ON teacher_location_history(teacher_id, created_at DESC);

-- =============================================
-- NAVIGATION WAYPOINTS (for complex routing)
-- =============================================
CREATE TABLE IF NOT EXISTS navigation_waypoints (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100),
    floor INTEGER NOT NULL DEFAULT 1,
    x_coordinate DOUBLE PRECISION NOT NULL,
    y_coordinate DOUBLE PRECISION NOT NULL,
    waypoint_type VARCHAR(50) DEFAULT 'corridor',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================
-- WAYPOINT CONNECTIONS (Graph edges for routing)
-- =============================================
CREATE TABLE IF NOT EXISTS waypoint_connections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    from_waypoint_id UUID REFERENCES navigation_waypoints(id) ON DELETE CASCADE,
    to_waypoint_id UUID REFERENCES navigation_waypoints(id) ON DELETE CASCADE,
    distance DOUBLE PRECISION,
    is_bidirectional BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(from_waypoint_id, to_waypoint_id)
);

-- =============================================
-- ROOM-WAYPOINT CONNECTIONS
-- =============================================
CREATE TABLE IF NOT EXISTS room_waypoint_connections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_id UUID REFERENCES rooms(id) ON DELETE CASCADE,
    waypoint_id UUID REFERENCES navigation_waypoints(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(room_id, waypoint_id)
);

-- =============================================
-- ANNOUNCEMENTS TABLE (Teachers/HOD can post)
-- =============================================
CREATE TABLE IF NOT EXISTS announcements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    branch_id UUID REFERENCES branches(id),
    created_by UUID REFERENCES teachers(id),
    is_pinned BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================
-- FUNCTION: Update vote count on poll_votes changes
-- =============================================
CREATE OR REPLACE FUNCTION update_vote_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE poll_options 
        SET vote_count = vote_count + 1 
        WHERE id = NEW.option_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE poll_options 
        SET vote_count = GREATEST(vote_count - 1, 0)
        WHERE id = OLD.option_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger for vote count
DROP TRIGGER IF EXISTS trigger_update_vote_count ON poll_votes;
CREATE TRIGGER trigger_update_vote_count
AFTER INSERT OR DELETE ON poll_votes
FOR EACH ROW
EXECUTE FUNCTION update_vote_count();

-- =============================================
-- FUNCTION: Auto-update updated_at timestamp
-- =============================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
DROP TRIGGER IF EXISTS trigger_students_updated_at ON students;
CREATE TRIGGER trigger_students_updated_at
BEFORE UPDATE ON students
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_teachers_updated_at ON teachers;
CREATE TRIGGER trigger_teachers_updated_at
BEFORE UPDATE ON teachers
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- =============================================
-- FUNCTION: Log teacher location changes
-- =============================================
CREATE OR REPLACE FUNCTION log_teacher_location_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.current_room_id IS DISTINCT FROM NEW.current_room_id THEN
        IF NEW.current_room_id IS NOT NULL THEN
            INSERT INTO teacher_location_history (teacher_id, room_id, action)
            VALUES (NEW.id, NEW.current_room_id, 'enter');
        ELSIF OLD.current_room_id IS NOT NULL THEN
            INSERT INTO teacher_location_history (teacher_id, room_id, action)
            VALUES (NEW.id, OLD.current_room_id, 'leave');
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_teacher_location_change ON teachers;
CREATE TRIGGER trigger_teacher_location_change
AFTER UPDATE OF current_room_id ON teachers
FOR EACH ROW
EXECUTE FUNCTION log_teacher_location_change();

-- =============================================
-- ENABLE REALTIME FOR REQUIRED TABLES
-- =============================================
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE branch_chat_messages;
    ALTER PUBLICATION supabase_realtime ADD TABLE private_messages;
    ALTER PUBLICATION supabase_realtime ADD TABLE teachers;
    ALTER PUBLICATION supabase_realtime ADD TABLE poll_votes;
    ALTER PUBLICATION supabase_realtime ADD TABLE poll_options;
    ALTER PUBLICATION supabase_realtime ADD TABLE announcements;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- =============================================
-- ROW LEVEL SECURITY POLICIES
-- =============================================

-- Enable RLS on all tables
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

-- Create policies (allow all for anon key since using custom auth)
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

CREATE POLICY "Allow all for branches" ON branches FOR ALL USING (true);
CREATE POLICY "Allow all for students" ON students FOR ALL USING (true);
CREATE POLICY "Allow all for teachers" ON teachers FOR ALL USING (true);
CREATE POLICY "Allow all for rooms" ON rooms FOR ALL USING (true);
CREATE POLICY "Allow all for subjects" ON subjects FOR ALL USING (true);
CREATE POLICY "Allow all for timetable" ON timetable FOR ALL USING (true);
CREATE POLICY "Allow all for branch_chat" ON branch_chat_messages FOR ALL USING (true);
CREATE POLICY "Allow all for private_messages" ON private_messages FOR ALL USING (true);
CREATE POLICY "Allow all for polls" ON polls FOR ALL USING (true);
CREATE POLICY "Allow all for poll_options" ON poll_options FOR ALL USING (true);
CREATE POLICY "Allow all for poll_votes" ON poll_votes FOR ALL USING (true);
CREATE POLICY "Allow all for announcements" ON announcements FOR ALL USING (true);

-- =============================================
-- SAMPLE DATA: ROOMS (Based on 3rd Floor Plan)
-- Map dimensions: 700x650 pixels
-- =============================================

-- Clear existing room data first
DELETE FROM room_waypoint_connections;
DELETE FROM waypoint_connections;
DELETE FROM navigation_waypoints;
DELETE FROM timetable;
DELETE FROM rooms;

-- B-WING ROOMS (Top Section)
INSERT INTO rooms (name, room_number, floor, x_coordinate, y_coordinate, room_type, capacity) VALUES
    -- Top Row (B-Wing North)
    ('Tutorial Room', 'B-304', 3, 50, 30, 'classroom', 25),
    ('Classroom', 'B-305', 3, 130, 30, 'classroom', 75),
    ('Classroom', 'B-306', 3, 230, 30, 'classroom', 24),
    ('Boys Toilet', 'BT-301', 3, 310, 30, 'washroom', 0),
    ('Girls Toilet', 'GT-301', 3, 350, 30, 'washroom', 0),
    ('Classroom', 'B-307A', 3, 450, 30, 'classroom', 74),
    ('Basic Electronics Lab', 'B-308', 3, 620, 30, 'lab', 30),
    
    -- Second Row (B-Wing)
    ('IT Lab', 'B-303', 3, 50, 100, 'lab', 65),
    ('Faculty Room', 'B-302', 3, 130, 100, 'faculty', 65),
    ('Classroom', 'B-301', 3, 230, 100, 'classroom', 64),
    ('Faculty Room', 'B-314', 3, 450, 100, 'faculty', 25),
    ('HOD Cabin', 'B-HOD', 3, 500, 100, 'office', 5),
    ('Faculty Room', 'B-313', 3, 550, 100, 'faculty', 71),
    ('ANIL Lab 1', 'B-312', 3, 620, 100, 'lab', 71),
    ('ANIL Lab 2', 'B-311', 3, 620, 160, 'lab', 71),
    ('Classroom', 'B-310', 3, 620, 220, 'classroom', 30),

-- A-WING ROOMS (Left Section - Data Science)
    ('Data Science Lab 1', 'A-306', 3, 50, 200, 'lab', 21),
    ('Data Science Lab 2', 'A-305', 3, 50, 260, 'lab', 21),
    ('Data Science Lab 3', 'A-304', 3, 50, 320, 'lab', 21),
    ('Data Science Lab 4', 'A-303', 3, 50, 380, 'lab', 21),

-- A-WING CENTER (Auditorium)
    ('Auditorium', 'A-307', 3, 200, 280, 'auditorium', 256),

-- A-WING ROOMS (Right Section - IT Labs)
    ('IT Project Lab', 'A-310', 3, 400, 200, 'lab', 56),
    ('IT Lab 1', 'A-311', 3, 400, 280, 'lab', 56),
    ('IT Lab 2', 'A-312', 3, 400, 360, 'lab', 56),

-- A-WING BOTTOM ROW
    ('Room', 'A-302', 3, 100, 520, 'classroom', 66),
    ('Faculty Room', 'A-301', 3, 180, 520, 'faculty', 66),
    ('Staff Toilet', 'A-315A', 3, 260, 520, 'washroom', 0),
    ('Dept Office', 'A-OFFICE', 3, 310, 520, 'office', 29),
    ('IT Lab 3', 'A-314', 3, 400, 520, 'lab', 30),
    ('IT Lab 4', 'A-313', 3, 480, 520, 'lab', 30),

-- COMMON AREAS
    ('Staircase A (Left)', 'STAIR-A', 3, 30, 450, 'staircase', 0),
    ('Staircase B (Right)', 'STAIR-B', 3, 650, 320, 'staircase', 0),
    ('Lift A', 'LIFT-A', 3, 30, 100, 'lift', 0),
    ('Lift B', 'LIFT-B', 3, 650, 100, 'lift', 0),
    ('Open Courtyard 1', 'COURT-1', 3, 150, 180, 'courtyard', 0),
    ('Open Courtyard 2', 'COURT-2', 3, 300, 380, 'courtyard', 0)
ON CONFLICT (room_number) DO UPDATE SET
    name = EXCLUDED.name,
    x_coordinate = EXCLUDED.x_coordinate,
    y_coordinate = EXCLUDED.y_coordinate,
    room_type = EXCLUDED.room_type,
    capacity = EXCLUDED.capacity;

-- =============================================
-- NAVIGATION WAYPOINTS (3rd Floor)
-- =============================================
INSERT INTO navigation_waypoints (name, floor, x_coordinate, y_coordinate, waypoint_type) VALUES
    -- Main Corridors
    ('B-Wing North Corridor Start', 3, 50, 65, 'corridor'),
    ('B-Wing North Corridor Mid', 3, 300, 65, 'corridor'),
    ('B-Wing North Corridor End', 3, 620, 65, 'corridor'),
    
    ('B-Wing South Corridor Start', 3, 50, 135, 'corridor'),
    ('B-Wing South Corridor Mid', 3, 300, 135, 'corridor'),
    ('B-Wing South Corridor End', 3, 620, 135, 'corridor'),
    
    ('A-Wing Left Corridor Top', 3, 85, 200, 'corridor'),
    ('A-Wing Left Corridor Mid', 3, 85, 320, 'corridor'),
    ('A-Wing Left Corridor Bottom', 3, 85, 450, 'corridor'),
    
    ('A-Wing Right Corridor Top', 3, 440, 200, 'corridor'),
    ('A-Wing Right Corridor Mid', 3, 440, 320, 'corridor'),
    ('A-Wing Right Corridor Bottom', 3, 440, 450, 'corridor'),
    
    ('Bottom Corridor Start', 3, 100, 490, 'corridor'),
    ('Bottom Corridor Mid', 3, 300, 490, 'corridor'),
    ('Bottom Corridor End', 3, 480, 490, 'corridor'),
    
    -- Junction Points
    ('Junction NW', 3, 85, 135, 'junction'),
    ('Junction NE', 3, 440, 135, 'junction'),
    ('Junction SW', 3, 85, 490, 'junction'),
    ('Junction SE', 3, 440, 490, 'junction'),
    
    -- Staircase Points
    ('Staircase A Point', 3, 30, 450, 'staircase'),
    ('Staircase B Point', 3, 650, 320, 'staircase'),
    ('Lift A Point', 3, 30, 100, 'lift'),
    ('Lift B Point', 3, 650, 100, 'lift');

-- =============================================
-- SAMPLE DATA: TEACHERS (TY Computer - Sem 6)
-- All passwords: 1234 (SHA256 hashed)
-- Password hash for '1234': 03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4
-- =============================================
DELETE FROM teacher_subjects;
DELETE FROM timetable;
DELETE FROM teachers;

INSERT INTO teachers (email, password_hash, name, phone, branch_id, is_hod, is_admin)
SELECT 
    'pradeeps@sjcem.edu.in',
    '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4',
    'Dr. Pradeepkumar Shetty',
    '9876543201',
    id,
    false,
    false
FROM branches WHERE code = 'COMP';

INSERT INTO teachers (email, password_hash, name, phone, branch_id, is_hod, is_admin)
SELECT 
    'divyatar@sjcem.edu.in',
    '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4',
    'Ms. Divyata Raut',
    '9876543202',
    id,
    false,
    false
FROM branches WHERE code = 'COMP';

INSERT INTO teachers (email, password_hash, name, phone, branch_id, is_hod, is_admin)
SELECT 
    'pritig@sjcem.edu.in',
    '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4',
    'Ms. Priti Ghodke',
    '9876543203',
    id,
    false,
    false
FROM branches WHERE code = 'COMP';

INSERT INTO teachers (email, password_hash, name, phone, branch_id, is_hod, is_admin)
SELECT 
    'hemantb@sjcem.edu.in',
    '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4',
    'Mr. Hemant Bansal',
    '9876543204',
    id,
    false,
    false
FROM branches WHERE code = 'COMP';

INSERT INTO teachers (email, password_hash, name, phone, branch_id, is_hod, is_admin)
SELECT 
    'juilek@sjcem.edu.in',
    '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4',
    'Ms. Juilee Kini',
    '9876543205',
    id,
    true,  -- Class Advisor / HOD
    false
FROM branches WHERE code = 'COMP';

INSERT INTO teachers (email, password_hash, name, phone, branch_id, is_hod, is_admin)
SELECT 
    'karishmat@sjcem.edu.in',
    '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4',
    'Mrs. Karishma Tamboli',
    '9876543206',
    id,
    false,
    false
FROM branches WHERE code = 'COMP';

-- =============================================
-- SAMPLE DATA: SUBJECTS (TY Computer - Sem 6)
-- Based on SJCEM Timetable
-- =============================================
DELETE FROM subjects WHERE branch_id IN (SELECT id FROM branches WHERE code = 'COMP') AND semester = 6;

-- Management (MGT/MAN) - Dr. Pradeepkumar Shetty
INSERT INTO subjects (name, code, branch_id, semester, credits, is_lab) 
SELECT 'Management', 'COMP601', id, 6, 3, false FROM branches WHERE code = 'COMP'
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name;

-- ETI - Emerging Trends in Computer Engineering And Information Technology - Ms. Divyata Raut
INSERT INTO subjects (name, code, branch_id, semester, credits, is_lab) 
SELECT 'Emerging Trends in CE & IT', 'COMP602', id, 6, 3, false FROM branches WHERE code = 'COMP'
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name;

-- STE/SFT - Software Testing - Ms. Priti Ghodke
INSERT INTO subjects (name, code, branch_id, semester, credits, is_lab) 
SELECT 'Software Testing', 'COMP603', id, 6, 3, false FROM branches WHERE code = 'COMP'
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name;

-- CSS - Client Side Scripting - Mr. Hemant Bansal (Lab in IT-L4)
INSERT INTO subjects (name, code, branch_id, semester, credits, is_lab) 
SELECT 'Client Side Scripting', 'COMP604', id, 6, 3, true FROM branches WHERE code = 'COMP'
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name;

-- MAD - Mobile Application Development - Ms. Juilee Kini (Lab in B-303)
INSERT INTO subjects (name, code, branch_id, semester, credits, is_lab) 
SELECT 'Mobile Application Development', 'COMP605', id, 6, 3, true FROM branches WHERE code = 'COMP'
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name;

-- DFH - Digital Forensics and Hacking Techniques - Mrs. Karishma Tamboli (Lab in B-303)
INSERT INTO subjects (name, code, branch_id, semester, credits, is_lab) 
SELECT 'Digital Forensics & Hacking', 'COMP606', id, 6, 3, true FROM branches WHERE code = 'COMP'
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name;

-- CPE - Capstone Project - Mr. Hemant Bansal
INSERT INTO subjects (name, code, branch_id, semester, credits, is_lab) 
SELECT 'Capstone Project', 'COMP607', id, 6, 4, false FROM branches WHERE code = 'COMP'
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name;

-- =============================================
-- TEACHER-SUBJECT MAPPING
-- =============================================
-- Dr. Pradeepkumar Shetty - Management
INSERT INTO teacher_subjects (teacher_id, subject_id)
SELECT t.id, s.id FROM teachers t, subjects s
WHERE t.email = 'pradeeps@sjcem.edu.in' AND s.code = 'COMP601'
ON CONFLICT (teacher_id, subject_id) DO NOTHING;

-- Ms. Divyata Raut - ETI
INSERT INTO teacher_subjects (teacher_id, subject_id)
SELECT t.id, s.id FROM teachers t, subjects s
WHERE t.email = 'divyatar@sjcem.edu.in' AND s.code = 'COMP602'
ON CONFLICT (teacher_id, subject_id) DO NOTHING;

-- Ms. Priti Ghodke - Software Testing
INSERT INTO teacher_subjects (teacher_id, subject_id)
SELECT t.id, s.id FROM teachers t, subjects s
WHERE t.email = 'pritig@sjcem.edu.in' AND s.code = 'COMP603'
ON CONFLICT (teacher_id, subject_id) DO NOTHING;

-- Mr. Hemant Bansal - CSS & CPE
INSERT INTO teacher_subjects (teacher_id, subject_id)
SELECT t.id, s.id FROM teachers t, subjects s
WHERE t.email = 'hemantb@sjcem.edu.in' AND s.code = 'COMP604'
ON CONFLICT (teacher_id, subject_id) DO NOTHING;

INSERT INTO teacher_subjects (teacher_id, subject_id)
SELECT t.id, s.id FROM teachers t, subjects s
WHERE t.email = 'hemantb@sjcem.edu.in' AND s.code = 'COMP607'
ON CONFLICT (teacher_id, subject_id) DO NOTHING;

-- Ms. Juilee Kini - MAD
INSERT INTO teacher_subjects (teacher_id, subject_id)
SELECT t.id, s.id FROM teachers t, subjects s
WHERE t.email = 'juilek@sjcem.edu.in' AND s.code = 'COMP605'
ON CONFLICT (teacher_id, subject_id) DO NOTHING;

-- Mrs. Karishma Tamboli - DFH
INSERT INTO teacher_subjects (teacher_id, subject_id)
SELECT t.id, s.id FROM teachers t, subjects s
WHERE t.email = 'karishmat@sjcem.edu.in' AND s.code = 'COMP606'
ON CONFLICT (teacher_id, subject_id) DO NOTHING;

-- =============================================
-- ADD ADDITIONAL ROOMS FOR TIMETABLE
-- =============================================
INSERT INTO rooms (name, room_number, floor, x_coordinate, y_coordinate, room_type, capacity) VALUES
    ('IT Lab 4 (CSS Lab)', 'IT-L4', 3, 480, 520, 'lab', 60),
    ('Classroom 34', 'CL-34', 3, 230, 100, 'classroom', 75)
ON CONFLICT (room_number) DO UPDATE SET
    name = EXCLUDED.name,
    x_coordinate = EXCLUDED.x_coordinate,
    y_coordinate = EXCLUDED.y_coordinate;

-- =============================================
-- TIMETABLE: TY Computer Sem 6
-- Day: 0=Sunday, 1=Monday, 2=Tuesday, 3=Wednesday, 4=Thursday, 5=Friday, 6=Saturday
-- =============================================

-- MONDAY (day_of_week = 1)
-- 10:00-11:00: MAD (Ms. Juilee Kini) - Classroom
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time)
SELECT b.id, 6, 1, 2, s.id, t.id, r.id, '10:00:00', '11:00:00'
FROM branches b, subjects s, teachers t, rooms r
WHERE b.code = 'COMP' AND s.code = 'COMP605' AND t.email = 'juilek@sjcem.edu.in' AND r.room_number = 'CL-34';

-- 11:00-12:00: DFH-B1 (Mrs. Karishma Tamboli) - B-303, STE-B2 (Ms. Priti Ghodke) - CL
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time)
SELECT b.id, 6, 1, 3, s.id, t.id, r.id, '11:00:00', '12:00:00'
FROM branches b, subjects s, teachers t, rooms r
WHERE b.code = 'COMP' AND s.code = 'COMP606' AND t.email = 'karishmat@sjcem.edu.in' AND r.room_number = 'B-303';

-- 12:00-13:00: (continuation or STE-B2)
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time)
SELECT b.id, 6, 1, 4, s.id, t.id, r.id, '12:00:00', '13:00:00'
FROM branches b, subjects s, teachers t, rooms r
WHERE b.code = 'COMP' AND s.code = 'COMP603' AND t.email = 'pritig@sjcem.edu.in' AND r.room_number = 'CL-34';

-- 14:00-15:00: CSS (Mr. Hemant Bansal) - Classroom
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time)
SELECT b.id, 6, 1, 6, s.id, t.id, r.id, '14:00:00', '15:00:00'
FROM branches b, subjects s, teachers t, rooms r
WHERE b.code = 'COMP' AND s.code = 'COMP604' AND t.email = 'hemantb@sjcem.edu.in' AND r.room_number = 'CL-34';

-- 15:00-16:00: STE (Ms. Priti Ghodke) - Classroom
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time)
SELECT b.id, 6, 1, 7, s.id, t.id, r.id, '15:00:00', '16:00:00'
FROM branches b, subjects s, teachers t, rooms r
WHERE b.code = 'COMP' AND s.code = 'COMP603' AND t.email = 'pritig@sjcem.edu.in' AND r.room_number = 'CL-34';

-- 16:00-17:00: ETI (Ms. Divyata Raut) - Classroom
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time)
SELECT b.id, 6, 1, 8, s.id, t.id, r.id, '16:00:00', '17:00:00'
FROM branches b, subjects s, teachers t, rooms r
WHERE b.code = 'COMP' AND s.code = 'COMP602' AND t.email = 'divyatar@sjcem.edu.in' AND r.room_number = 'CL-34';

-- TUESDAY (day_of_week = 2)
-- 09:00-10:00: CSS-B1 (IT-L4), MAD-B2 (B-303)
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time)
SELECT b.id, 6, 2, 1, s.id, t.id, r.id, '09:00:00', '10:00:00'
FROM branches b, subjects s, teachers t, rooms r
WHERE b.code = 'COMP' AND s.code = 'COMP604' AND t.email = 'hemantb@sjcem.edu.in' AND r.room_number = 'IT-L4';

-- 10:00-11:00: (continuation)
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time)
SELECT b.id, 6, 2, 2, s.id, t.id, r.id, '10:00:00', '11:00:00'
FROM branches b, subjects s, teachers t, rooms r
WHERE b.code = 'COMP' AND s.code = 'COMP605' AND t.email = 'juilek@sjcem.edu.in' AND r.room_number = 'B-303';

-- 11:00-12:00: MGT (Dr. Pradeepkumar Shetty) - Classroom
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time)
SELECT b.id, 6, 2, 3, s.id, t.id, r.id, '11:00:00', '12:00:00'
FROM branches b, subjects s, teachers t, rooms r
WHERE b.code = 'COMP' AND s.code = 'COMP601' AND t.email = 'pradeeps@sjcem.edu.in' AND r.room_number = 'CL-34';

-- 12:00-13:00: ETI - Classroom
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time)
SELECT b.id, 6, 2, 4, s.id, t.id, r.id, '12:00:00', '13:00:00'
FROM branches b, subjects s, teachers t, rooms r
WHERE b.code = 'COMP' AND s.code = 'COMP602' AND t.email = 'divyatar@sjcem.edu.in' AND r.room_number = 'CL-34';

-- 14:00-15:00: STE-B1 (CL), DFH-B2 (B-303)
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time)
SELECT b.id, 6, 2, 6, s.id, t.id, r.id, '14:00:00', '15:00:00'
FROM branches b, subjects s, teachers t, rooms r
WHERE b.code = 'COMP' AND s.code = 'COMP603' AND t.email = 'pritig@sjcem.edu.in' AND r.room_number = 'CL-34';

-- 15:00-16:00: MGT - Classroom
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time)
SELECT b.id, 6, 2, 7, s.id, t.id, r.id, '15:00:00', '16:00:00'
FROM branches b, subjects s, teachers t, rooms r
WHERE b.code = 'COMP' AND s.code = 'COMP601' AND t.email = 'pradeeps@sjcem.edu.in' AND r.room_number = 'CL-34';

-- 16:00-17:00: CPE (Mr. Hemant Bansal) - Classroom
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time)
SELECT b.id, 6, 2, 8, s.id, t.id, r.id, '16:00:00', '17:00:00'
FROM branches b, subjects s, teachers t, rooms r
WHERE b.code = 'COMP' AND s.code = 'COMP607' AND t.email = 'hemantb@sjcem.edu.in' AND r.room_number = 'CL-34';

-- WEDNESDAY (day_of_week = 3)
-- 10:00-11:00: DFH - Classroom
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time)
SELECT b.id, 6, 3, 2, s.id, t.id, r.id, '10:00:00', '11:00:00'
FROM branches b, subjects s, teachers t, rooms r
WHERE b.code = 'COMP' AND s.code = 'COMP606' AND t.email = 'karishmat@sjcem.edu.in' AND r.room_number = 'CL-34';

-- 11:00-12:00: MGT - Classroom
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time)
SELECT b.id, 6, 3, 3, s.id, t.id, r.id, '11:00:00', '12:00:00'
FROM branches b, subjects s, teachers t, rooms r
WHERE b.code = 'COMP' AND s.code = 'COMP601' AND t.email = 'pradeeps@sjcem.edu.in' AND r.room_number = 'CL-34';

-- 12:00-13:00: DFH - Classroom
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time)
SELECT b.id, 6, 3, 4, s.id, t.id, r.id, '12:00:00', '13:00:00'
FROM branches b, subjects s, teachers t, rooms r
WHERE b.code = 'COMP' AND s.code = 'COMP606' AND t.email = 'karishmat@sjcem.edu.in' AND r.room_number = 'CL-34';

-- 14:00-15:00: STE - Classroom
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time)
SELECT b.id, 6, 3, 6, s.id, t.id, r.id, '14:00:00', '15:00:00'
FROM branches b, subjects s, teachers t, rooms r
WHERE b.code = 'COMP' AND s.code = 'COMP603' AND t.email = 'pritig@sjcem.edu.in' AND r.room_number = 'CL-34';

-- 15:00-16:00: MGT - Classroom
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time)
SELECT b.id, 6, 3, 7, s.id, t.id, r.id, '15:00:00', '16:00:00'
FROM branches b, subjects s, teachers t, rooms r
WHERE b.code = 'COMP' AND s.code = 'COMP601' AND t.email = 'pradeeps@sjcem.edu.in' AND r.room_number = 'CL-34';

-- 16:00-17:00: ETI - Classroom
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time)
SELECT b.id, 6, 3, 8, s.id, t.id, r.id, '16:00:00', '17:00:00'
FROM branches b, subjects s, teachers t, rooms r
WHERE b.code = 'COMP' AND s.code = 'COMP602' AND t.email = 'divyatar@sjcem.edu.in' AND r.room_number = 'CL-34';

-- THURSDAY (day_of_week = 4)
-- 09:00-10:00: MAD-B1 (B-303), CSS-B2 (IT-L4)
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time)
SELECT b.id, 6, 4, 1, s.id, t.id, r.id, '09:00:00', '10:00:00'
FROM branches b, subjects s, teachers t, rooms r
WHERE b.code = 'COMP' AND s.code = 'COMP605' AND t.email = 'juilek@sjcem.edu.in' AND r.room_number = 'B-303';

-- 10:00-11:00: (continuation)
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time)
SELECT b.id, 6, 4, 2, s.id, t.id, r.id, '10:00:00', '11:00:00'
FROM branches b, subjects s, teachers t, rooms r
WHERE b.code = 'COMP' AND s.code = 'COMP604' AND t.email = 'hemantb@sjcem.edu.in' AND r.room_number = 'IT-L4';

-- 11:00-12:00: CSS - Classroom
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time)
SELECT b.id, 6, 4, 3, s.id, t.id, r.id, '11:00:00', '12:00:00'
FROM branches b, subjects s, teachers t, rooms r
WHERE b.code = 'COMP' AND s.code = 'COMP604' AND t.email = 'hemantb@sjcem.edu.in' AND r.room_number = 'CL-34';

-- 12:00-13:00: MGT - Classroom
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time)
SELECT b.id, 6, 4, 4, s.id, t.id, r.id, '12:00:00', '13:00:00'
FROM branches b, subjects s, teachers t, rooms r
WHERE b.code = 'COMP' AND s.code = 'COMP601' AND t.email = 'pradeeps@sjcem.edu.in' AND r.room_number = 'CL-34';

-- 14:00-15:00: DFH - Classroom
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time)
SELECT b.id, 6, 4, 6, s.id, t.id, r.id, '14:00:00', '15:00:00'
FROM branches b, subjects s, teachers t, rooms r
WHERE b.code = 'COMP' AND s.code = 'COMP606' AND t.email = 'karishmat@sjcem.edu.in' AND r.room_number = 'CL-34';

-- 15:00-16:00: CPE - Classroom
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time)
SELECT b.id, 6, 4, 7, s.id, t.id, r.id, '15:00:00', '16:00:00'
FROM branches b, subjects s, teachers t, rooms r
WHERE b.code = 'COMP' AND s.code = 'COMP607' AND t.email = 'hemantb@sjcem.edu.in' AND r.room_number = 'CL-34';

-- FRIDAY (day_of_week = 5)
-- 10:00-11:00: MAD - Classroom
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time)
SELECT b.id, 6, 5, 2, s.id, t.id, r.id, '10:00:00', '11:00:00'
FROM branches b, subjects s, teachers t, rooms r
WHERE b.code = 'COMP' AND s.code = 'COMP605' AND t.email = 'juilek@sjcem.edu.in' AND r.room_number = 'CL-34';

-- 11:00-12:00: STE - Classroom
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time)
SELECT b.id, 6, 5, 3, s.id, t.id, r.id, '11:00:00', '12:00:00'
FROM branches b, subjects s, teachers t, rooms r
WHERE b.code = 'COMP' AND s.code = 'COMP603' AND t.email = 'pritig@sjcem.edu.in' AND r.room_number = 'CL-34';

-- 12:00-13:00: DFH - Classroom
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time)
SELECT b.id, 6, 5, 4, s.id, t.id, r.id, '12:00:00', '13:00:00'
FROM branches b, subjects s, teachers t, rooms r
WHERE b.code = 'COMP' AND s.code = 'COMP606' AND t.email = 'karishmat@sjcem.edu.in' AND r.room_number = 'CL-34';

-- 14:00-15:00: ETI - Classroom
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time)
SELECT b.id, 6, 5, 6, s.id, t.id, r.id, '14:00:00', '15:00:00'
FROM branches b, subjects s, teachers t, rooms r
WHERE b.code = 'COMP' AND s.code = 'COMP602' AND t.email = 'divyatar@sjcem.edu.in' AND r.room_number = 'CL-34';

-- 15:00-16:00: STE-B1 & B2 - Classroom
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time)
SELECT b.id, 6, 5, 7, s.id, t.id, r.id, '15:00:00', '16:00:00'
FROM branches b, subjects s, teachers t, rooms r
WHERE b.code = 'COMP' AND s.code = 'COMP603' AND t.email = 'pritig@sjcem.edu.in' AND r.room_number = 'CL-34';

-- SATURDAY (day_of_week = 6) - 2nd and 4th Saturday only (handled by app logic)
-- 10:00-11:00: STE - Classroom
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time)
SELECT b.id, 6, 6, 2, s.id, t.id, r.id, '10:00:00', '11:00:00'
FROM branches b, subjects s, teachers t, rooms r
WHERE b.code = 'COMP' AND s.code = 'COMP603' AND t.email = 'pritig@sjcem.edu.in' AND r.room_number = 'CL-34';

-- 11:00-12:00: CSS-B1 (IT-L4), MAD-B2 (B-303)
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time)
SELECT b.id, 6, 6, 3, s.id, t.id, r.id, '11:00:00', '12:00:00'
FROM branches b, subjects s, teachers t, rooms r
WHERE b.code = 'COMP' AND s.code = 'COMP604' AND t.email = 'hemantb@sjcem.edu.in' AND r.room_number = 'IT-L4';

-- 12:00-13:00: (continuation)
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time)
SELECT b.id, 6, 6, 4, s.id, t.id, r.id, '12:00:00', '13:00:00'
FROM branches b, subjects s, teachers t, rooms r
WHERE b.code = 'COMP' AND s.code = 'COMP605' AND t.email = 'juilek@sjcem.edu.in' AND r.room_number = 'B-303';

-- 14:00-15:00: MAD-B1 (B-303), CSS-B2 (IT-L4)
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time)
SELECT b.id, 6, 6, 6, s.id, t.id, r.id, '14:00:00', '15:00:00'
FROM branches b, subjects s, teachers t, rooms r
WHERE b.code = 'COMP' AND s.code = 'COMP605' AND t.email = 'juilek@sjcem.edu.in' AND r.room_number = 'B-303';

-- 15:00-16:00: (continuation)
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time)
SELECT b.id, 6, 6, 7, s.id, t.id, r.id, '15:00:00', '16:00:00'
FROM branches b, subjects s, teachers t, rooms r
WHERE b.code = 'COMP' AND s.code = 'COMP604' AND t.email = 'hemantb@sjcem.edu.in' AND r.room_number = 'IT-L4';

-- =============================================
-- HELPER FUNCTION: Check if teacher is currently in a class
-- (Called from Flutter app for auto-location)
-- =============================================
CREATE OR REPLACE FUNCTION get_teacher_scheduled_room(
    p_teacher_id UUID,
    p_current_time TIME DEFAULT CURRENT_TIME,
    p_current_day INTEGER DEFAULT EXTRACT(DOW FROM CURRENT_DATE)::INTEGER
)
RETURNS UUID AS $$
DECLARE
    v_room_id UUID;
BEGIN
    SELECT room_id INTO v_room_id
    FROM timetable
    WHERE teacher_id = p_teacher_id
      AND day_of_week = p_current_day
      AND start_time <= p_current_time
      AND end_time > p_current_time
      AND is_active = true
    LIMIT 1;
    
    RETURN v_room_id;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- FUNCTION: Auto-update ALL teacher locations based on timetable
-- This should be called periodically (every minute) by the app or a cron job
-- =============================================
CREATE OR REPLACE FUNCTION update_all_teacher_locations()
RETURNS TABLE (
    teacher_id UUID,
    teacher_name VARCHAR,
    old_room_id UUID,
    new_room_id UUID,
    room_name VARCHAR
) AS $$
DECLARE
    v_current_time TIME := CURRENT_TIME;
    v_current_day INTEGER := EXTRACT(DOW FROM CURRENT_DATE)::INTEGER;
BEGIN
    RETURN QUERY
    WITH scheduled_rooms AS (
        SELECT DISTINCT ON (tt.teacher_id)
            tt.teacher_id,
            tt.room_id as scheduled_room_id
        FROM timetable tt
        WHERE tt.day_of_week = v_current_day
          AND tt.start_time <= v_current_time
          AND tt.end_time > v_current_time
          AND tt.is_active = true
        ORDER BY tt.teacher_id, tt.start_time DESC
    ),
    updated AS (
        UPDATE teachers t
        SET 
            current_room_id = sr.scheduled_room_id,
            current_room_updated_at = NOW()
        FROM scheduled_rooms sr
        WHERE t.id = sr.teacher_id
          AND (t.current_room_id IS DISTINCT FROM sr.scheduled_room_id)
        RETURNING t.id, t.name, t.current_room_id
    )
    SELECT 
        u.id as teacher_id,
        u.name as teacher_name,
        NULL::UUID as old_room_id,
        u.current_room_id as new_room_id,
        r.name as room_name
    FROM updated u
    LEFT JOIN rooms r ON u.current_room_id = r.id;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- FUNCTION: Clear teacher locations when class ends
-- Sets location to NULL if no current class
-- =============================================
CREATE OR REPLACE FUNCTION clear_teacher_locations_after_class()
RETURNS TABLE (
    teacher_id UUID,
    teacher_name VARCHAR,
    cleared BOOLEAN
) AS $$
DECLARE
    v_current_time TIME := CURRENT_TIME;
    v_current_day INTEGER := EXTRACT(DOW FROM CURRENT_DATE)::INTEGER;
BEGIN
    RETURN QUERY
    WITH teachers_with_class AS (
        SELECT DISTINCT tt.teacher_id
        FROM timetable tt
        WHERE tt.day_of_week = v_current_day
          AND tt.start_time <= v_current_time
          AND tt.end_time > v_current_time
          AND tt.is_active = true
    ),
    cleared_teachers AS (
        UPDATE teachers t
        SET 
            current_room_id = NULL,
            current_room_updated_at = NOW()
        WHERE t.current_room_id IS NOT NULL
          AND t.id NOT IN (SELECT twc.teacher_id FROM teachers_with_class twc)
        RETURNING t.id, t.name
    )
    SELECT 
        ct.id as teacher_id,
        ct.name as teacher_name,
        true as cleared
    FROM cleared_teachers ct;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- FUNCTION: Get teacher's current and next class
-- =============================================
CREATE OR REPLACE FUNCTION get_teacher_schedule_status(p_teacher_id UUID)
RETURNS TABLE (
    current_subject VARCHAR,
    current_room VARCHAR,
    current_end_time TIME,
    next_subject VARCHAR,
    next_room VARCHAR,
    next_start_time TIME
) AS $$
DECLARE
    v_current_time TIME := CURRENT_TIME;
    v_current_day INTEGER := EXTRACT(DOW FROM CURRENT_DATE)::INTEGER;
BEGIN
    RETURN QUERY
    SELECT 
        (SELECT s.name FROM timetable tt 
         JOIN subjects s ON tt.subject_id = s.id 
         WHERE tt.teacher_id = p_teacher_id 
           AND tt.day_of_week = v_current_day 
           AND tt.start_time <= v_current_time 
           AND tt.end_time > v_current_time
         LIMIT 1) as current_subject,
        (SELECT r.name FROM timetable tt 
         JOIN rooms r ON tt.room_id = r.id 
         WHERE tt.teacher_id = p_teacher_id 
           AND tt.day_of_week = v_current_day 
           AND tt.start_time <= v_current_time 
           AND tt.end_time > v_current_time
         LIMIT 1) as current_room,
        (SELECT tt.end_time FROM timetable tt 
         WHERE tt.teacher_id = p_teacher_id 
           AND tt.day_of_week = v_current_day 
           AND tt.start_time <= v_current_time 
           AND tt.end_time > v_current_time
         LIMIT 1) as current_end_time,
        (SELECT s.name FROM timetable tt 
         JOIN subjects s ON tt.subject_id = s.id 
         WHERE tt.teacher_id = p_teacher_id 
           AND tt.day_of_week = v_current_day 
           AND tt.start_time > v_current_time
         ORDER BY tt.start_time
         LIMIT 1) as next_subject,
        (SELECT r.name FROM timetable tt 
         JOIN rooms r ON tt.room_id = r.id 
         WHERE tt.teacher_id = p_teacher_id 
           AND tt.day_of_week = v_current_day 
           AND tt.start_time > v_current_time
         ORDER BY tt.start_time
         LIMIT 1) as next_room,
        (SELECT tt.start_time FROM timetable tt 
         WHERE tt.teacher_id = p_teacher_id 
           AND tt.day_of_week = v_current_day 
           AND tt.start_time > v_current_time
         ORDER BY tt.start_time
         LIMIT 1) as next_start_time;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- TRIGGER: Auto-update teacher location on timetable time
-- This trigger fires when the database time matches a class start time
-- =============================================
CREATE OR REPLACE FUNCTION auto_update_teacher_location_trigger()
RETURNS TRIGGER AS $$
BEGIN
    -- When a timetable entry is activated/modified, update teacher location if it's current time
    IF NEW.is_active = true THEN
        PERFORM update_all_teacher_locations();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_auto_location_on_timetable ON timetable;
CREATE TRIGGER trigger_auto_location_on_timetable
AFTER INSERT OR UPDATE ON timetable
FOR EACH ROW
EXECUTE FUNCTION auto_update_teacher_location_trigger();

-- =============================================
-- HELPER FUNCTION: Get conversation preview for private chats
-- =============================================
CREATE OR REPLACE FUNCTION get_conversation_preview(
    p_user_id UUID,
    p_other_user_id UUID
)
RETURNS TABLE (
    last_message TEXT,
    last_message_time TIMESTAMP WITH TIME ZONE,
    unread_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (SELECT message FROM private_messages 
         WHERE (sender_id = p_user_id AND receiver_id = p_other_user_id)
            OR (sender_id = p_other_user_id AND receiver_id = p_user_id)
         ORDER BY created_at DESC LIMIT 1) as last_message,
        (SELECT created_at FROM private_messages 
         WHERE (sender_id = p_user_id AND receiver_id = p_other_user_id)
            OR (sender_id = p_other_user_id AND receiver_id = p_user_id)
         ORDER BY created_at DESC LIMIT 1) as last_message_time,
        (SELECT COUNT(*) FROM private_messages 
         WHERE sender_id = p_other_user_id 
           AND receiver_id = p_user_id 
           AND is_read = false) as unread_count;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- VIEW: Active polls with vote counts
-- =============================================
CREATE OR REPLACE VIEW active_polls_with_stats AS
SELECT 
    p.*,
    t.name as creator_name,
    b.name as branch_name,
    COALESCE(SUM(po.vote_count), 0) as total_votes
FROM polls p
LEFT JOIN teachers t ON p.created_by = t.id
LEFT JOIN branches b ON p.branch_id = b.id
LEFT JOIN poll_options po ON p.id = po.poll_id
WHERE p.is_active = true
  AND (p.ends_at IS NULL OR p.ends_at > NOW())
GROUP BY p.id, t.name, b.name;

-- =============================================
-- VIEW: Today's timetable
-- =============================================
CREATE OR REPLACE VIEW todays_timetable AS
SELECT 
    tt.*,
    s.name as subject_name,
    s.code as subject_code,
    t.name as teacher_name,
    t.phone as teacher_phone,
    r.name as room_name,
    r.room_number,
    b.name as branch_name,
    b.code as branch_code
FROM timetable tt
LEFT JOIN subjects s ON tt.subject_id = s.id
LEFT JOIN teachers t ON tt.teacher_id = t.id
LEFT JOIN rooms r ON tt.room_id = r.id
LEFT JOIN branches b ON tt.branch_id = b.id
WHERE tt.day_of_week = EXTRACT(DOW FROM CURRENT_DATE)::INTEGER
  AND tt.is_active = true
ORDER BY tt.period_number;

-- =============================================
-- ADMIN: Create a teacher (use this in Supabase SQL editor)
-- Example usage:
-- SELECT create_teacher('john@sjcem.edu', 'hashedpassword', 'John Doe', '9876543210', 'IT', false, false);
-- =============================================
CREATE OR REPLACE FUNCTION create_teacher(
    p_email VARCHAR(255),
    p_password_hash VARCHAR(255),
    p_name VARCHAR(100),
    p_phone VARCHAR(20),
    p_branch_code VARCHAR(20),
    p_is_hod BOOLEAN DEFAULT FALSE,
    p_is_admin BOOLEAN DEFAULT FALSE
)
RETURNS UUID AS $$
DECLARE
    v_branch_id UUID;
    v_teacher_id UUID;
BEGIN
    SELECT id INTO v_branch_id FROM branches WHERE code = p_branch_code;
    
    INSERT INTO teachers (email, password_hash, name, phone, branch_id, is_hod, is_admin)
    VALUES (p_email, p_password_hash, p_name, p_phone, v_branch_id, p_is_hod, p_is_admin)
    RETURNING id INTO v_teacher_id;
    
    RETURN v_teacher_id;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- Grant permissions for anon key
-- =============================================
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO anon;
