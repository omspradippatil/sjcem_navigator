-- SJCEM Navigator Database Schema
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
    semester INTEGER NOT NULL DEFAULT 1,
    anonymous_id VARCHAR(20) NOT NULL UNIQUE,
    phone VARCHAR(20),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

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
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

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
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add foreign key for teacher current room
ALTER TABLE teachers 
ADD CONSTRAINT fk_teacher_current_room 
FOREIGN KEY (current_room_id) REFERENCES rooms(id);

-- =============================================
-- SUBJECTS TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS subjects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    code VARCHAR(20) NOT NULL UNIQUE,
    branch_id UUID REFERENCES branches(id),
    semester INTEGER NOT NULL,
    credits INTEGER DEFAULT 3,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

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
    semester INTEGER NOT NULL,
    day_of_week INTEGER NOT NULL CHECK (day_of_week >= 0 AND day_of_week <= 6),
    period_number INTEGER NOT NULL,
    subject_id UUID REFERENCES subjects(id),
    teacher_id UUID REFERENCES teachers(id),
    room_id UUID REFERENCES rooms(id),
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(branch_id, semester, day_of_week, period_number)
);

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
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================
-- PRIVATE MESSAGES (Student to Student)
-- =============================================
CREATE TABLE IF NOT EXISTS private_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sender_id UUID NOT NULL,
    receiver_id UUID NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_private_messages_conversation 
ON private_messages(sender_id, receiver_id);

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
    ends_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

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
-- TEACHER LOCATION HISTORY
-- =============================================
CREATE TABLE IF NOT EXISTS teacher_location_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    teacher_id UUID REFERENCES teachers(id) ON DELETE CASCADE,
    room_id UUID REFERENCES rooms(id),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

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
-- FUNCTIONS FOR VOTE COUNT UPDATE
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
        SET vote_count = vote_count - 1 
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
-- FUNCTION TO GENERATE ANONYMOUS ID
-- =============================================
CREATE OR REPLACE FUNCTION generate_anonymous_id()
RETURNS VARCHAR(20) AS $$
DECLARE
    new_id VARCHAR(20);
BEGIN
    new_id := 'User#' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');
    WHILE EXISTS (SELECT 1 FROM students WHERE anonymous_id = new_id) LOOP
        new_id := 'User#' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');
    END LOOP;
    RETURN new_id;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- ENABLE REALTIME FOR REQUIRED TABLES
-- =============================================
ALTER PUBLICATION supabase_realtime ADD TABLE branch_chat_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE private_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE teachers;
ALTER PUBLICATION supabase_realtime ADD TABLE poll_votes;
ALTER PUBLICATION supabase_realtime ADD TABLE poll_options;

-- =============================================
-- ROW LEVEL SECURITY POLICIES (Basic)
-- =============================================
ALTER TABLE students ENABLE ROW LEVEL SECURITY;
ALTER TABLE teachers ENABLE ROW LEVEL SECURITY;
ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE branch_chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE private_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE polls ENABLE ROW LEVEL SECURITY;
ALTER TABLE poll_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE poll_votes ENABLE ROW LEVEL SECURITY;

-- Allow public read for rooms
CREATE POLICY "Allow public read rooms" ON rooms FOR SELECT USING (true);

-- Allow public read for branches
ALTER TABLE branches ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read branches" ON branches FOR SELECT USING (true);

-- Allow public read for subjects
ALTER TABLE subjects ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read subjects" ON subjects FOR SELECT USING (true);

-- Allow public read for timetable
ALTER TABLE timetable ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read timetable" ON timetable FOR SELECT USING (true);

-- Allow all operations for anon key (since we're using custom auth)
CREATE POLICY "Allow all for students" ON students FOR ALL USING (true);
CREATE POLICY "Allow all for teachers" ON teachers FOR ALL USING (true);
CREATE POLICY "Allow all for branch_chat" ON branch_chat_messages FOR ALL USING (true);
CREATE POLICY "Allow all for private_messages" ON private_messages FOR ALL USING (true);
CREATE POLICY "Allow all for polls" ON polls FOR ALL USING (true);
CREATE POLICY "Allow all for poll_options" ON poll_options FOR ALL USING (true);
CREATE POLICY "Allow all for poll_votes" ON poll_votes FOR ALL USING (true);

-- =============================================
-- SAMPLE DATA FOR TESTING
-- =============================================

-- Insert sample rooms based on the floor map
INSERT INTO rooms (name, room_number, floor, x_coordinate, y_coordinate, room_type) VALUES
    ('Gents Washroom', 'GW-301', 3, 80, 60, 'washroom'),
    ('Classroom', 'A-302', 3, 80, 160, 'classroom'),
    ('Faculty Room', 'A-301', 3, 80, 260, 'faculty'),
    ('IT Dept Office', 'A-315', 3, 80, 380, 'office'),
    ('IT Lab 1', 'A-314', 3, 80, 450, 'lab'),
    ('IT Lab 2', 'A-313', 3, 80, 550, 'lab'),
    ('IT Lab 3', 'A-312', 3, 200, 550, 'lab'),
    ('IT Lab 4', 'A-311', 3, 320, 550, 'lab'),
    ('Classroom', 'A-303', 3, 220, 60, 'classroom'),
    ('Classroom', 'A-304', 3, 380, 60, 'classroom'),
    ('Classroom', 'A-305', 3, 520, 60, 'classroom'),
    ('B-Wing MMS', 'A-306', 3, 520, 160, 'classroom'),
    ('Auditorium', 'A-307', 3, 520, 280, 'auditorium'),
    ('Room', 'A-308', 3, 520, 400, 'classroom'),
    ('TV Engineering Lab', 'A-309', 3, 450, 550, 'lab'),
    ('TV Engineering Lab', 'A-310', 3, 450, 550, 'lab'),
    ('Ladies Washroom', 'LW-301', 3, 600, 550, 'washroom')
ON CONFLICT (room_number) DO NOTHING;
