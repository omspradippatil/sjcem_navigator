-- SJCEM Navigator Database Schema
-- Supabase Free Tier Compatible (NO pg_cron)
-- Run this in Supabase SQL Editor
-- Updated: January 2026 with 3rd Floor Map, Teachers, and Auto-Location

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
-- ROOMS TABLE (HODs/Teachers can rename rooms)
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
    display_name VARCHAR(100), -- Custom display name (can be changed by HOD)
    last_modified_by UUID, -- Teacher who last modified
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
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
-- TIMETABLE TABLE (with break slot support)
-- =============================================
CREATE TABLE IF NOT EXISTS timetable (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    branch_id UUID REFERENCES branches(id),
    semester INTEGER NOT NULL CHECK (semester >= 1 AND semester <= 8),
    day_of_week INTEGER NOT NULL CHECK (day_of_week >= 0 AND day_of_week <= 6),
    period_number INTEGER NOT NULL CHECK (period_number >= 1 AND period_number <= 12),
    subject_id UUID REFERENCES subjects(id),
    teacher_id UUID REFERENCES teachers(id),
    room_id UUID REFERENCES rooms(id),
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    is_break BOOLEAN DEFAULT FALSE, -- For lunch/break slots
    break_name VARCHAR(50), -- 'Lunch Break', 'Short Break' etc.
    batch VARCHAR(10), -- For lab batches: 'B1', 'B2', etc.
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(branch_id, semester, day_of_week, period_number, batch)
);

-- Index for timetable queries
CREATE INDEX IF NOT EXISTS idx_timetable_lookup ON timetable(branch_id, semester, day_of_week);
CREATE INDEX IF NOT EXISTS idx_timetable_teacher ON timetable(teacher_id);
CREATE INDEX IF NOT EXISTS idx_timetable_time ON timetable(day_of_week, start_time, end_time);

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
-- FUNCTION: Auto-update teacher location based on timetable
-- Called periodically by app or can be triggered
-- =============================================
CREATE OR REPLACE FUNCTION auto_update_teacher_location(p_teacher_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_scheduled_room_id UUID;
    v_current_day INTEGER;
    v_current_time TIME;
BEGIN
    v_current_day := EXTRACT(DOW FROM CURRENT_DATE)::INTEGER;
    v_current_time := CURRENT_TIME;
    
    -- Get the scheduled room for current time
    SELECT room_id INTO v_scheduled_room_id
    FROM timetable
    WHERE teacher_id = p_teacher_id
      AND day_of_week = v_current_day
      AND start_time <= v_current_time
      AND end_time > v_current_time
      AND is_active = true
      AND is_break = false
    LIMIT 1;
    
    -- Update teacher location if scheduled room found
    IF v_scheduled_room_id IS NOT NULL THEN
        UPDATE teachers 
        SET current_room_id = v_scheduled_room_id,
            current_room_updated_at = NOW()
        WHERE id = p_teacher_id;
        RETURN TRUE;
    END IF;
    
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- FUNCTION: Get next class info for teacher
-- =============================================
CREATE OR REPLACE FUNCTION get_teacher_next_class(p_teacher_id UUID)
RETURNS TABLE (
    subject_name VARCHAR(100),
    room_name VARCHAR(100),
    room_number VARCHAR(20),
    start_time TIME,
    end_time TIME,
    branch_name VARCHAR(100),
    semester INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.name as subject_name,
        r.name as room_name,
        r.room_number,
        tt.start_time,
        tt.end_time,
        b.name as branch_name,
        tt.semester
    FROM timetable tt
    LEFT JOIN subjects s ON tt.subject_id = s.id
    LEFT JOIN rooms r ON tt.room_id = r.id
    LEFT JOIN branches b ON tt.branch_id = b.id
    WHERE tt.teacher_id = p_teacher_id
      AND tt.day_of_week = EXTRACT(DOW FROM CURRENT_DATE)::INTEGER
      AND tt.start_time > CURRENT_TIME
      AND tt.is_active = true
      AND tt.is_break = false
    ORDER BY tt.start_time
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- FUNCTION: Auto-update all teachers' locations
-- Can be called periodically
-- =============================================
CREATE OR REPLACE FUNCTION auto_update_all_teacher_locations()
RETURNS INTEGER AS $$
DECLARE
    v_teacher_record RECORD;
    v_updated_count INTEGER := 0;
BEGIN
    FOR v_teacher_record IN 
        SELECT DISTINCT t.id 
        FROM teachers t
        INNER JOIN timetable tt ON tt.teacher_id = t.id
        WHERE t.is_active = true
    LOOP
        IF auto_update_teacher_location(v_teacher_record.id) THEN
            v_updated_count := v_updated_count + 1;
        END IF;
    END LOOP;
    
    RETURN v_updated_count;
END;
$$ LANGUAGE plpgsql;

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
-- 3RD FLOOR ROOMS DATA (Based on actual floor plan)
-- =============================================
-- Clear existing room data for floor 3
DELETE FROM rooms WHERE floor = 3;

-- Insert rooms based on 3rd Floor Plan
INSERT INTO rooms (name, room_number, floor, x_coordinate, y_coordinate, room_type, capacity, display_name) VALUES
    -- Top Row (Left to Right)
    ('Tutorial Room', 'B-304', 3, 50, 40, 'classroom', 40, 'Tutorial'),
    ('Classroom', 'B-305', 3, 130, 40, 'classroom', 60, 'B-305'),
    ('Classroom', 'B-306', 3, 210, 40, 'classroom', 60, 'B-306'),
    ('Boys Washroom', 'BW-301', 3, 350, 40, 'washroom', 0, 'Boys WC'),
    ('Drinking Water', 'DW-301', 3, 400, 40, 'utility', 0, 'Water'),
    ('Girls Washroom', 'GW-301', 3, 450, 40, 'washroom', 0, 'Girls WC'),
    ('Classroom', 'B-307A', 3, 550, 40, 'classroom', 60, 'B-307A'),
    ('Classroom', 'B-307', 3, 650, 40, 'classroom', 60, 'B-307'),
    ('Basic Electronics Lab', 'B-316', 3, 780, 40, 'lab', 40, 'Basic Electronics Lab'),
    
    -- Second Row (Left to Right)
    ('IT Lab', 'B-303', 3, 50, 120, 'lab', 40, 'IT Lab B-303'),
    ('Faculty Room', 'B-302', 3, 130, 120, 'faculty', 20, 'Faculty Room'),
    ('Classroom', 'B-301', 3, 210, 120, 'classroom', 60, 'Classroom B-301'),
    ('Faculty Room', 'B-314A', 3, 550, 120, 'faculty', 15, 'Faculty Room'),
    ('Classroom', 'B-315', 3, 650, 120, 'classroom', 60, 'B-315'),
    ('Faculty Room', 'B-313', 3, 730, 120, 'faculty', 15, 'Faculty Room'),
    ('AML Lab', 'B-312', 3, 780, 120, 'lab', 40, 'AML Lab'),
    ('AML Lab 2', 'B-311', 3, 830, 120, 'lab', 40, 'AML Lab'),
    ('Classroom', 'B-310', 3, 880, 120, 'classroom', 60, 'Classroom B-310'),
    
    -- Left Column (Data Science Labs)
    ('Data Science Lab', 'A-306', 3, 50, 250, 'lab', 40, 'DS Lab A-306'),
    ('Data Science Lab', 'A-305', 3, 50, 320, 'lab', 40, 'DS Lab A-305'),
    ('Data Science Lab', 'A-304', 3, 50, 400, 'lab', 40, 'DS Lab A-304'),
    ('Data Science Lab', 'A-303', 3, 50, 480, 'lab', 40, 'DS Lab A-303'),
    
    -- Center Area
    ('Auditorium', 'A-307', 3, 210, 300, 'auditorium', 200, 'Auditorium'),
    ('Open Courtyard 1', 'COURT-1', 3, 210, 200, 'open_area', 0, 'Open to Sky'),
    ('Open Courtyard 2', 'COURT-2', 3, 210, 420, 'open_area', 0, 'Open to Sky'),
    
    -- Right Column (IT Labs)
    ('IT Project Lab', 'A-310', 3, 550, 250, 'lab', 40, 'IT Project Lab'),
    ('IT Lab', 'A-311', 3, 550, 340, 'lab', 40, 'IT Lab A-311'),
    ('IT Lab', 'A-312', 3, 550, 420, 'lab', 40, 'IT Lab A-312'),
    
    -- Bottom Row (Left to Right)
    ('Classroom', 'A-302', 3, 50, 560, 'classroom', 60, 'Classroom 34'),
    ('Faculty Room', 'A-301', 3, 130, 560, 'faculty', 20, 'Faculty Room'),
    ('Dept Office', 'A-315A', 3, 250, 560, 'office', 10, 'Dept Office'),
    ('IT Lab', 'A-314', 3, 350, 560, 'lab', 40, 'IT Lab (IT-L4)'),
    ('IT Lab', 'A-313', 3, 450, 560, 'lab', 40, 'IT Lab'),
    
    -- Staircases and Corridors
    ('Lift 1', 'LIFT-1', 3, 100, 180, 'utility', 0, 'Lift'),
    ('Lift 2', 'LIFT-2', 3, 520, 180, 'utility', 0, 'Lift'),
    ('Staircase West', 'STAIR-W', 3, 100, 140, 'staircase', 0, 'Staircase'),
    ('Staircase East', 'STAIR-E', 3, 520, 140, 'staircase', 0, 'Staircase'),
    ('Main Corridor', 'COR-MAIN', 3, 300, 100, 'corridor', 0, '3.65M Wide Passage'),
    ('Bottom Corridor', 'COR-BOTTOM', 3, 300, 540, 'corridor', 0, '3.00M Wide Passage'),
    
    -- Additional classrooms from timetable
    ('IT Lab L4', 'IT-L4', 3, 350, 560, 'lab', 40, 'IT Lab L4 (CSS Lab)'),
    ('Classroom 34', 'CL-34', 3, 50, 560, 'classroom', 60, 'Classroom 34'),
    ('Lab B-303', 'LAB-B303', 3, 50, 120, 'lab', 40, 'DFH/MAD Lab')
ON CONFLICT (room_number) DO UPDATE SET
    name = EXCLUDED.name,
    x_coordinate = EXCLUDED.x_coordinate,
    y_coordinate = EXCLUDED.y_coordinate,
    room_type = EXCLUDED.room_type,
    capacity = EXCLUDED.capacity,
    display_name = EXCLUDED.display_name;

-- =============================================
-- TEACHERS DATA (From Timetable - Password: 1234)
-- Password hash for '1234' using SHA-256
-- =============================================
-- SHA-256 hash of '1234' = 03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4

-- Insert COMP branch teachers
INSERT INTO teachers (email, password_hash, name, phone, branch_id, is_hod, is_admin)
SELECT 
    'pradeeps@sjcem.edu.in',
    '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4',
    'Dr. Pradeepkumar Shetty',
    NULL,
    id,
    TRUE,  -- HOD
    FALSE
FROM branches WHERE code = 'COMP'
ON CONFLICT (email) DO NOTHING;

INSERT INTO teachers (email, password_hash, name, phone, branch_id, is_hod, is_admin)
SELECT 
    'divyar@sjcem.edu.in',
    '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4',
    'Ms. Divyaa Raut',
    NULL,
    id,
    FALSE,
    FALSE
FROM branches WHERE code = 'COMP'
ON CONFLICT (email) DO NOTHING;

INSERT INTO teachers (email, password_hash, name, phone, branch_id, is_hod, is_admin)
SELECT 
    'pritig@sjcem.edu.in',
    '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4',
    'Ms. Priti Ghodke',
    NULL,
    id,
    FALSE,
    FALSE
FROM branches WHERE code = 'COMP'
ON CONFLICT (email) DO NOTHING;

INSERT INTO teachers (email, password_hash, name, phone, branch_id, is_hod, is_admin)
SELECT 
    'hemantb@sjcem.edu.in',
    '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4',
    'Mr. Hemant Bansal',
    NULL,
    id,
    FALSE,
    FALSE
FROM branches WHERE code = 'COMP'
ON CONFLICT (email) DO NOTHING;

INSERT INTO teachers (email, password_hash, name, phone, branch_id, is_hod, is_admin)
SELECT 
    'juleek@sjcem.edu.in',
    '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4',
    'Ms. Juilee Kini',
    NULL,
    id,
    FALSE,
    FALSE
FROM branches WHERE code = 'COMP'
ON CONFLICT (email) DO NOTHING;

INSERT INTO teachers (email, password_hash, name, phone, branch_id, is_hod, is_admin)
SELECT 
    'karishmat@sjcem.edu.in',
    '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4',
    'Mrs. Karishma Tamboli',
    NULL,
    id,
    FALSE,
    FALSE
FROM branches WHERE code = 'COMP'
ON CONFLICT (email) DO NOTHING;

-- =============================================
-- SUBJECTS DATA (Computer Engineering - Sem 6)
-- Based on timetable
-- =============================================
INSERT INTO subjects (name, code, branch_id, semester, credits, is_lab)
SELECT 'Management', '315301', id, 6, 3, false FROM branches WHERE code = 'COMP'
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name;

INSERT INTO subjects (name, code, branch_id, semester, credits, is_lab)
SELECT 'Emerging Trends in Computer Engineering And Information Technology', '316313', id, 6, 3, false FROM branches WHERE code = 'COMP'
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name;

INSERT INTO subjects (name, code, branch_id, semester, credits, is_lab)
SELECT 'Software Testing', '316314', id, 6, 3, false FROM branches WHERE code = 'COMP'
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name;

INSERT INTO subjects (name, code, branch_id, semester, credits, is_lab)
SELECT 'Client Side Scripting', '316605', id, 6, 3, false FROM branches WHERE code = 'COMP'
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name;

INSERT INTO subjects (name, code, branch_id, semester, credits, is_lab)
SELECT 'Mobile Application Development', '316006', id, 6, 3, false FROM branches WHERE code = 'COMP'
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name;

INSERT INTO subjects (name, code, branch_id, semester, credits, is_lab)
SELECT 'Digital Forensics and Hacking Techniques', '316315', id, 6, 3, false FROM branches WHERE code = 'COMP'
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name;

INSERT INTO subjects (name, code, branch_id, semester, credits, is_lab)
SELECT 'Capstone Project', '316004', id, 6, 4, false FROM branches WHERE code = 'COMP'
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name;

-- Lab versions
INSERT INTO subjects (name, code, branch_id, semester, credits, is_lab)
SELECT 'Client Side Scripting Lab', 'CSS-LAB', id, 6, 2, true FROM branches WHERE code = 'COMP'
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name;

INSERT INTO subjects (name, code, branch_id, semester, credits, is_lab)
SELECT 'Mobile Application Development Lab', 'MAD-LAB', id, 6, 2, true FROM branches WHERE code = 'COMP'
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name;

INSERT INTO subjects (name, code, branch_id, semester, credits, is_lab)
SELECT 'Digital Forensics Lab', 'DFH-LAB', id, 6, 2, true FROM branches WHERE code = 'COMP'
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name;

INSERT INTO subjects (name, code, branch_id, semester, credits, is_lab)
SELECT 'Software Testing Lab', 'STE-LAB', id, 6, 2, true FROM branches WHERE code = 'COMP'
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name;

-- =============================================
-- TEACHER-SUBJECT MAPPING
-- =============================================
-- Dr. Pradeepkumar Shetty - Management (MAN)
INSERT INTO teacher_subjects (teacher_id, subject_id)
SELECT t.id, s.id
FROM teachers t, subjects s
WHERE t.email = 'pradeeps@sjcem.edu.in' AND s.code = '315301'
ON CONFLICT (teacher_id, subject_id) DO NOTHING;

-- Ms. Divyaa Raut - ETI
INSERT INTO teacher_subjects (teacher_id, subject_id)
SELECT t.id, s.id
FROM teachers t, subjects s
WHERE t.email = 'divyar@sjcem.edu.in' AND s.code = '316313'
ON CONFLICT (teacher_id, subject_id) DO NOTHING;

-- Ms. Priti Ghodke - SFT (Software Testing)
INSERT INTO teacher_subjects (teacher_id, subject_id)
SELECT t.id, s.id
FROM teachers t, subjects s
WHERE t.email = 'pritig@sjcem.edu.in' AND s.code = '316314'
ON CONFLICT (teacher_id, subject_id) DO NOTHING;

-- Mr. Hemant Bansal - CSS (Client Side Scripting)
INSERT INTO teacher_subjects (teacher_id, subject_id)
SELECT t.id, s.id
FROM teachers t, subjects s
WHERE t.email = 'hemantb@sjcem.edu.in' AND s.code = '316605'
ON CONFLICT (teacher_id, subject_id) DO NOTHING;

-- Ms. Juilee Kini - MAD (Mobile Application Development)
INSERT INTO teacher_subjects (teacher_id, subject_id)
SELECT t.id, s.id
FROM teachers t, subjects s
WHERE t.email = 'juleek@sjcem.edu.in' AND s.code = '316006'
ON CONFLICT (teacher_id, subject_id) DO NOTHING;

-- Mrs. Karishma Tamboli - DFH (Digital Forensics)
INSERT INTO teacher_subjects (teacher_id, subject_id)
SELECT t.id, s.id
FROM teachers t, subjects s
WHERE t.email = 'karishmat@sjcem.edu.in' AND s.code = '316315'
ON CONFLICT (teacher_id, subject_id) DO NOTHING;

-- Mr. Hemant Bansal - CPE (Capstone Project)
INSERT INTO teacher_subjects (teacher_id, subject_id)
SELECT t.id, s.id
FROM teachers t, subjects s
WHERE t.email = 'hemantb@sjcem.edu.in' AND s.code = '316004'
ON CONFLICT (teacher_id, subject_id) DO NOTHING;

-- =============================================
-- TIMETABLE DATA (Third Year Computer - Sem VI)
-- Class: Classroom 34
-- =============================================

-- Clear existing timetable for COMP Sem 6
DELETE FROM timetable WHERE branch_id = (SELECT id FROM branches WHERE code = 'COMP') AND semester = 6;

-- Helper to insert timetable entries
-- Day of Week: 0=Sunday, 1=Monday, 2=Tuesday, 3=Wednesday, 4=Thursday, 5=Friday, 6=Saturday

-- =============================================
-- MONDAY (day_of_week = 1)
-- =============================================
-- Period 1: 09:00 - 10:00 (No class scheduled per timetable)
-- Period 2: 10:00 - 11:00 - MAD
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 1, 2, 
    (SELECT id FROM subjects WHERE code = '316006'),
    (SELECT id FROM teachers WHERE email = 'juleek@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'CL-34'),
    '10:00', '11:00', NULL
FROM branches b WHERE b.code = 'COMP';

-- Period 3: 11:00 - 12:00 - DFH-B1 (B-303), STE-B2 (CL)
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 1, 3, 
    (SELECT id FROM subjects WHERE code = 'DFH-LAB'),
    (SELECT id FROM teachers WHERE email = 'karishmat@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'B-303'),
    '11:00', '12:00', 'B1'
FROM branches b WHERE b.code = 'COMP';

INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 1, 3, 
    (SELECT id FROM subjects WHERE code = 'STE-LAB'),
    (SELECT id FROM teachers WHERE email = 'pritig@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'CL-34'),
    '11:00', '12:00', 'B2'
FROM branches b WHERE b.code = 'COMP';

-- Period 4: 12:00 - 13:00 - ETI
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 1, 4, 
    (SELECT id FROM subjects WHERE code = '316313'),
    (SELECT id FROM teachers WHERE email = 'divyar@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'CL-34'),
    '12:00', '13:00', NULL
FROM branches b WHERE b.code = 'COMP';

-- LUNCH BREAK: 13:00 - 14:00
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, start_time, end_time, is_break, break_name)
SELECT b.id, 6, 1, 5, '13:00', '14:00', TRUE, 'Lunch Break'
FROM branches b WHERE b.code = 'COMP';

-- Period 5: 14:00 - 15:00 - CSS
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 1, 6, 
    (SELECT id FROM subjects WHERE code = '316605'),
    (SELECT id FROM teachers WHERE email = 'hemantb@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'CL-34'),
    '14:00', '15:00', NULL
FROM branches b WHERE b.code = 'COMP';

-- Period 6: 15:00 - 16:00 - STE
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 1, 7, 
    (SELECT id FROM subjects WHERE code = '316314'),
    (SELECT id FROM teachers WHERE email = 'pritig@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'CL-34'),
    '15:00', '16:00', NULL
FROM branches b WHERE b.code = 'COMP';

-- Period 7: 16:00 - 17:00 - ETI
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 1, 8, 
    (SELECT id FROM subjects WHERE code = '316313'),
    (SELECT id FROM teachers WHERE email = 'divyar@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'CL-34'),
    '16:00', '17:00', NULL
FROM branches b WHERE b.code = 'COMP';

-- =============================================
-- TUESDAY (day_of_week = 2)
-- =============================================
-- Period 1: 09:00 - 10:00 - CSS-B1 (IT-L4), MAD-B2 (B-303)
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 2, 1, 
    (SELECT id FROM subjects WHERE code = 'CSS-LAB'),
    (SELECT id FROM teachers WHERE email = 'hemantb@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'IT-L4'),
    '09:00', '10:00', 'B1'
FROM branches b WHERE b.code = 'COMP';

INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 2, 1, 
    (SELECT id FROM subjects WHERE code = 'MAD-LAB'),
    (SELECT id FROM teachers WHERE email = 'juleek@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'B-303'),
    '09:00', '10:00', 'B2'
FROM branches b WHERE b.code = 'COMP';

-- Period 2: 10:00 - 11:00 (continued labs)
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 2, 2, 
    (SELECT id FROM subjects WHERE code = 'CSS-LAB'),
    (SELECT id FROM teachers WHERE email = 'hemantb@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'IT-L4'),
    '10:00', '11:00', 'B1'
FROM branches b WHERE b.code = 'COMP';

INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 2, 2, 
    (SELECT id FROM subjects WHERE code = 'MAD-LAB'),
    (SELECT id FROM teachers WHERE email = 'juleek@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'B-303'),
    '10:00', '11:00', 'B2'
FROM branches b WHERE b.code = 'COMP';

-- Period 3: 11:00 - 12:00 - MGT
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 2, 3, 
    (SELECT id FROM subjects WHERE code = '315301'),
    (SELECT id FROM teachers WHERE email = 'pradeeps@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'CL-34'),
    '11:00', '12:00', NULL
FROM branches b WHERE b.code = 'COMP';

-- Period 4: 12:00 - 13:00 - DFH
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 2, 4, 
    (SELECT id FROM subjects WHERE code = '316315'),
    (SELECT id FROM teachers WHERE email = 'karishmat@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'CL-34'),
    '12:00', '13:00', NULL
FROM branches b WHERE b.code = 'COMP';

-- LUNCH BREAK: 13:00 - 14:00
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, start_time, end_time, is_break, break_name)
SELECT b.id, 6, 2, 5, '13:00', '14:00', TRUE, 'Lunch Break'
FROM branches b WHERE b.code = 'COMP';

-- Period 5: 14:00 - 15:00 - STE-B1 (CL), DFH-B2 (B-303)
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 2, 6, 
    (SELECT id FROM subjects WHERE code = 'STE-LAB'),
    (SELECT id FROM teachers WHERE email = 'pritig@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'CL-34'),
    '14:00', '15:00', 'B1'
FROM branches b WHERE b.code = 'COMP';

INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 2, 6, 
    (SELECT id FROM subjects WHERE code = 'DFH-LAB'),
    (SELECT id FROM teachers WHERE email = 'karishmat@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'B-303'),
    '14:00', '15:00', 'B2'
FROM branches b WHERE b.code = 'COMP';

-- Period 6: 15:00 - 16:00 - MGT
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 2, 7, 
    (SELECT id FROM subjects WHERE code = '315301'),
    (SELECT id FROM teachers WHERE email = 'pradeeps@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'CL-34'),
    '15:00', '16:00', NULL
FROM branches b WHERE b.code = 'COMP';

-- Period 7: 16:00 - 17:00 - CPE
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 2, 8, 
    (SELECT id FROM subjects WHERE code = '316004'),
    (SELECT id FROM teachers WHERE email = 'hemantb@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'CL-34'),
    '16:00', '17:00', NULL
FROM branches b WHERE b.code = 'COMP';

-- =============================================
-- WEDNESDAY (day_of_week = 3)
-- =============================================
-- Period 1: 09:00 - 10:00 (No class)
-- Period 2: 10:00 - 11:00 - DFH
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 3, 2, 
    (SELECT id FROM subjects WHERE code = '316315'),
    (SELECT id FROM teachers WHERE email = 'karishmat@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'CL-34'),
    '10:00', '11:00', NULL
FROM branches b WHERE b.code = 'COMP';

-- Period 3: 11:00 - 12:00 - MGT
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 3, 3, 
    (SELECT id FROM subjects WHERE code = '315301'),
    (SELECT id FROM teachers WHERE email = 'pradeeps@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'CL-34'),
    '11:00', '12:00', NULL
FROM branches b WHERE b.code = 'COMP';

-- Period 4: 12:00 - 13:00 - DFH
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 3, 4, 
    (SELECT id FROM subjects WHERE code = '316315'),
    (SELECT id FROM teachers WHERE email = 'karishmat@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'CL-34'),
    '12:00', '13:00', NULL
FROM branches b WHERE b.code = 'COMP';

-- LUNCH BREAK: 13:00 - 14:00
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, start_time, end_time, is_break, break_name)
SELECT b.id, 6, 3, 5, '13:00', '14:00', TRUE, 'Lunch Break'
FROM branches b WHERE b.code = 'COMP';

-- Period 5: 14:00 - 15:00 - STE
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 3, 6, 
    (SELECT id FROM subjects WHERE code = '316314'),
    (SELECT id FROM teachers WHERE email = 'pritig@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'CL-34'),
    '14:00', '15:00', NULL
FROM branches b WHERE b.code = 'COMP';

-- Period 6: 15:00 - 16:00 - MGT
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 3, 7, 
    (SELECT id FROM subjects WHERE code = '315301'),
    (SELECT id FROM teachers WHERE email = 'pradeeps@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'CL-34'),
    '15:00', '16:00', NULL
FROM branches b WHERE b.code = 'COMP';

-- Period 7: 16:00 - 17:00 - ETI
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 3, 8, 
    (SELECT id FROM subjects WHERE code = '316313'),
    (SELECT id FROM teachers WHERE email = 'divyar@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'CL-34'),
    '16:00', '17:00', NULL
FROM branches b WHERE b.code = 'COMP';

-- =============================================
-- THURSDAY (day_of_week = 4)
-- =============================================
-- Period 1: 09:00 - 10:00 - MAD-B1 (B-303), CSS-B2 (IT-L4)
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 4, 1, 
    (SELECT id FROM subjects WHERE code = 'MAD-LAB'),
    (SELECT id FROM teachers WHERE email = 'juleek@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'B-303'),
    '09:00', '10:00', 'B1'
FROM branches b WHERE b.code = 'COMP';

INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 4, 1, 
    (SELECT id FROM subjects WHERE code = 'CSS-LAB'),
    (SELECT id FROM teachers WHERE email = 'hemantb@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'IT-L4'),
    '09:00', '10:00', 'B2'
FROM branches b WHERE b.code = 'COMP';

-- Period 2: 10:00 - 11:00 (continued labs)
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 4, 2, 
    (SELECT id FROM subjects WHERE code = 'MAD-LAB'),
    (SELECT id FROM teachers WHERE email = 'juleek@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'B-303'),
    '10:00', '11:00', 'B1'
FROM branches b WHERE b.code = 'COMP';

INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 4, 2, 
    (SELECT id FROM subjects WHERE code = 'CSS-LAB'),
    (SELECT id FROM teachers WHERE email = 'hemantb@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'IT-L4'),
    '10:00', '11:00', 'B2'
FROM branches b WHERE b.code = 'COMP';

-- Period 3: 11:00 - 12:00 - CSS
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 4, 3, 
    (SELECT id FROM subjects WHERE code = '316605'),
    (SELECT id FROM teachers WHERE email = 'hemantb@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'CL-34'),
    '11:00', '12:00', NULL
FROM branches b WHERE b.code = 'COMP';

-- Period 4: 12:00 - 13:00 - MGT
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 4, 4, 
    (SELECT id FROM subjects WHERE code = '315301'),
    (SELECT id FROM teachers WHERE email = 'pradeeps@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'CL-34'),
    '12:00', '13:00', NULL
FROM branches b WHERE b.code = 'COMP';

-- LUNCH BREAK: 13:00 - 14:00
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, start_time, end_time, is_break, break_name)
SELECT b.id, 6, 4, 5, '13:00', '14:00', TRUE, 'Lunch Break'
FROM branches b WHERE b.code = 'COMP';

-- Period 5: 14:00 - 15:00 - DFH
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 4, 6, 
    (SELECT id FROM subjects WHERE code = '316315'),
    (SELECT id FROM teachers WHERE email = 'karishmat@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'CL-34'),
    '14:00', '15:00', NULL
FROM branches b WHERE b.code = 'COMP';

-- Period 6: 15:00 - 16:00 - CPE
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 4, 7, 
    (SELECT id FROM subjects WHERE code = '316004'),
    (SELECT id FROM teachers WHERE email = 'hemantb@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'CL-34'),
    '15:00', '16:00', NULL
FROM branches b WHERE b.code = 'COMP';

-- Period 7: 16:00 - 17:00 - DFH
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 4, 8, 
    (SELECT id FROM subjects WHERE code = '316315'),
    (SELECT id FROM teachers WHERE email = 'karishmat@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'CL-34'),
    '16:00', '17:00', NULL
FROM branches b WHERE b.code = 'COMP';

-- =============================================
-- FRIDAY (day_of_week = 5)
-- =============================================
-- Period 2: 10:00 - 11:00 - MAD
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 5, 2, 
    (SELECT id FROM subjects WHERE code = '316006'),
    (SELECT id FROM teachers WHERE email = 'juleek@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'CL-34'),
    '10:00', '11:00', NULL
FROM branches b WHERE b.code = 'COMP';

-- Period 3: 11:00 - 12:00 - STE
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 5, 3, 
    (SELECT id FROM subjects WHERE code = '316314'),
    (SELECT id FROM teachers WHERE email = 'pritig@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'CL-34'),
    '11:00', '12:00', NULL
FROM branches b WHERE b.code = 'COMP';

-- Period 4: 12:00 - 13:00 - DFH
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 5, 4, 
    (SELECT id FROM subjects WHERE code = '316315'),
    (SELECT id FROM teachers WHERE email = 'karishmat@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'CL-34'),
    '12:00', '13:00', NULL
FROM branches b WHERE b.code = 'COMP';

-- LUNCH BREAK: 13:00 - 14:00
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, start_time, end_time, is_break, break_name)
SELECT b.id, 6, 5, 5, '13:00', '14:00', TRUE, 'Lunch Break'
FROM branches b WHERE b.code = 'COMP';

-- Period 5: 14:00 - 15:00 - ETI
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 5, 6, 
    (SELECT id FROM subjects WHERE code = '316313'),
    (SELECT id FROM teachers WHERE email = 'divyar@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'CL-34'),
    '14:00', '15:00', NULL
FROM branches b WHERE b.code = 'COMP';

-- Period 6: 15:00 - 16:00 - STE-B1 & B2 (CL)
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 5, 7, 
    (SELECT id FROM subjects WHERE code = 'STE-LAB'),
    (SELECT id FROM teachers WHERE email = 'pritig@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'CL-34'),
    '15:00', '16:00', NULL
FROM branches b WHERE b.code = 'COMP';

-- Period 7: 16:00 - 17:00 (continued lab)
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 5, 8, 
    (SELECT id FROM subjects WHERE code = 'STE-LAB'),
    (SELECT id FROM teachers WHERE email = 'pritig@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'CL-34'),
    '16:00', '17:00', NULL
FROM branches b WHERE b.code = 'COMP';

-- =============================================
-- SATURDAY (day_of_week = 6) - Only 2nd & 4th Saturday
-- =============================================
-- Period 1: 09:00 - 10:00 - STE
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 6, 1, 
    (SELECT id FROM subjects WHERE code = '316314'),
    (SELECT id FROM teachers WHERE email = 'pritig@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'CL-34'),
    '09:00', '10:00', NULL
FROM branches b WHERE b.code = 'COMP';

-- Period 2: 10:00 - 11:00 - CSS-B1 (IT-L4), MAD-B2 (B-303)
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 6, 2, 
    (SELECT id FROM subjects WHERE code = 'CSS-LAB'),
    (SELECT id FROM teachers WHERE email = 'hemantb@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'IT-L4'),
    '10:00', '11:00', 'B1'
FROM branches b WHERE b.code = 'COMP';

INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 6, 2, 
    (SELECT id FROM subjects WHERE code = 'MAD-LAB'),
    (SELECT id FROM teachers WHERE email = 'juleek@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'B-303'),
    '10:00', '11:00', 'B2'
FROM branches b WHERE b.code = 'COMP';

-- Period 3: 11:00 - 12:00 (continued labs)
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 6, 3, 
    (SELECT id FROM subjects WHERE code = 'CSS-LAB'),
    (SELECT id FROM teachers WHERE email = 'hemantb@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'IT-L4'),
    '11:00', '12:00', 'B1'
FROM branches b WHERE b.code = 'COMP';

INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 6, 3, 
    (SELECT id FROM subjects WHERE code = 'MAD-LAB'),
    (SELECT id FROM teachers WHERE email = 'juleek@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'B-303'),
    '11:00', '12:00', 'B2'
FROM branches b WHERE b.code = 'COMP';

-- Period 4: 12:00 - 13:00 - MAD-B1 (B-303), CSS-B2 (IT-L4)
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 6, 4, 
    (SELECT id FROM subjects WHERE code = 'MAD-LAB'),
    (SELECT id FROM teachers WHERE email = 'juleek@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'B-303'),
    '12:00', '13:00', 'B1'
FROM branches b WHERE b.code = 'COMP';

INSERT INTO timetable (branch_id, semester, day_of_week, period_number, subject_id, teacher_id, room_id, start_time, end_time, batch)
SELECT 
    b.id, 6, 6, 4, 
    (SELECT id FROM subjects WHERE code = 'CSS-LAB'),
    (SELECT id FROM teachers WHERE email = 'hemantb@sjcem.edu.in'),
    (SELECT id FROM rooms WHERE room_number = 'IT-L4'),
    '12:00', '13:00', 'B2'
FROM branches b WHERE b.code = 'COMP';

-- LUNCH BREAK: 13:00 - 14:00
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, start_time, end_time, is_break, break_name)
SELECT b.id, 6, 6, 5, '13:00', '14:00', TRUE, 'Lunch Break'
FROM branches b WHERE b.code = 'COMP';

-- Period 5: 14:00 - 15:00 - Mentoring
INSERT INTO timetable (branch_id, semester, day_of_week, period_number, start_time, end_time, is_break, break_name)
SELECT b.id, 6, 6, 6, '14:00', '15:00', FALSE, 'Mentoring'
FROM branches b WHERE b.code = 'COMP';

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
      AND is_break = false
    LIMIT 1;
    
    RETURN v_room_id;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- FUNCTION: Update room name (HOD/Teacher authority)
-- =============================================
CREATE OR REPLACE FUNCTION update_room_display_name(
    p_room_id UUID,
    p_new_display_name VARCHAR(100),
    p_teacher_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    v_is_authorized BOOLEAN;
BEGIN
    -- Check if teacher is HOD or Admin
    SELECT (is_hod OR is_admin) INTO v_is_authorized
    FROM teachers WHERE id = p_teacher_id;
    
    IF v_is_authorized THEN
        UPDATE rooms 
        SET display_name = p_new_display_name,
            last_modified_by = p_teacher_id,
            updated_at = NOW()
        WHERE id = p_room_id;
        RETURN TRUE;
    END IF;
    
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

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
DROP VIEW IF EXISTS todays_timetable;
CREATE OR REPLACE VIEW todays_timetable AS
SELECT 
    tt.id,
    tt.branch_id,
    tt.semester,
    tt.day_of_week,
    tt.period_number,
    tt.subject_id,
    tt.teacher_id,
    tt.room_id,
    tt.start_time,
    tt.end_time,
    tt.is_break,
    tt.break_name,
    tt.batch,
    tt.is_active,
    tt.created_at,
    s.name as subject_name,
    s.code as subject_code,
    t.name as teacher_name,
    t.phone as teacher_phone,
    t.email as teacher_email,
    r.name as room_name,
    r.room_number,
    COALESCE(r.display_name, r.name) as room_display_name,
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
-- VIEW: Current ongoing classes
-- =============================================
DROP VIEW IF EXISTS current_ongoing_classes;
CREATE OR REPLACE VIEW current_ongoing_classes AS
SELECT 
    tt.id,
    tt.branch_id,
    tt.semester,
    tt.day_of_week,
    tt.period_number,
    tt.subject_id,
    tt.teacher_id,
    tt.room_id,
    tt.start_time,
    tt.end_time,
    tt.is_break,
    tt.break_name,
    tt.batch,
    tt.is_active,
    tt.created_at,
    s.name as subject_name,
    s.code as subject_code,
    t.name as teacher_name,
    t.email as teacher_email,
    r.name as room_name,
    r.room_number,
    COALESCE(r.display_name, r.name) as room_display_name,
    b.name as branch_name,
    b.code as branch_code
FROM timetable tt
LEFT JOIN subjects s ON tt.subject_id = s.id
LEFT JOIN teachers t ON tt.teacher_id = t.id
LEFT JOIN rooms r ON tt.room_id = r.id
LEFT JOIN branches b ON tt.branch_id = b.id
WHERE tt.day_of_week = EXTRACT(DOW FROM CURRENT_DATE)::INTEGER
  AND tt.start_time <= CURRENT_TIME
  AND tt.end_time > CURRENT_TIME
  AND tt.is_active = true
  AND tt.is_break = false;

-- =============================================
-- VIEW: Teachers with current location details
-- =============================================
CREATE OR REPLACE VIEW teachers_with_location AS
SELECT 
    t.*,
    r.name as current_room_name,
    r.room_number as current_room_number,
    COALESCE(r.display_name, r.name) as current_room_display_name,
    r.floor as current_floor,
    b.name as branch_name,
    b.code as branch_code
FROM teachers t
LEFT JOIN rooms r ON t.current_room_id = r.id
LEFT JOIN branches b ON t.branch_id = b.id
WHERE t.is_active = true;

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

-- Grant permissions on views
GRANT SELECT ON todays_timetable TO anon;
GRANT SELECT ON current_ongoing_classes TO anon;
GRANT SELECT ON teachers_with_location TO anon;
GRANT SELECT ON active_polls_with_stats TO anon;

-- =============================================
-- ADDITIONAL POLICIES FOR ROOM UPDATES (HOD/Teacher authority)
-- =============================================
DROP POLICY IF EXISTS "HOD can update rooms" ON rooms;
CREATE POLICY "HOD can update rooms" ON rooms 
FOR UPDATE USING (true);

-- =============================================
-- INDEX for faster teacher location queries
-- =============================================
CREATE INDEX IF NOT EXISTS idx_teachers_current_room ON teachers(current_room_id) WHERE current_room_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_timetable_current_time ON timetable(day_of_week, start_time, end_time) WHERE is_active = true;
