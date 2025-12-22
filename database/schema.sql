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
-- SAMPLE DATA: ROOMS (Based on floor map)
-- =============================================
INSERT INTO rooms (name, room_number, floor, x_coordinate, y_coordinate, room_type) VALUES
    ('Gents Washroom', 'GW-301', 3, 80, 60, 'washroom'),
    ('Classroom 302', 'A-302', 3, 80, 160, 'classroom'),
    ('Faculty Room', 'A-301', 3, 80, 260, 'faculty'),
    ('IT Dept Office', 'A-315', 3, 80, 380, 'office'),
    ('IT Lab 1', 'A-314', 3, 80, 450, 'lab'),
    ('IT Lab 2', 'A-313', 3, 80, 550, 'lab'),
    ('IT Lab 3', 'A-312', 3, 200, 550, 'lab'),
    ('IT Lab 4', 'A-311', 3, 320, 550, 'lab'),
    ('Classroom 303', 'A-303', 3, 220, 60, 'classroom'),
    ('Classroom 304', 'A-304', 3, 380, 60, 'classroom'),
    ('Classroom 305', 'A-305', 3, 520, 60, 'classroom'),
    ('B-Wing MMS', 'A-306', 3, 520, 160, 'classroom'),
    ('Auditorium', 'A-307', 3, 520, 280, 'auditorium'),
    ('Room 308', 'A-308', 3, 520, 400, 'classroom'),
    ('TV Engineering Lab', 'A-309', 3, 450, 550, 'lab'),
    ('Electronics Lab', 'A-310', 3, 580, 550, 'lab'),
    ('Ladies Washroom', 'LW-301', 3, 620, 60, 'washroom'),
    ('Staircase A', 'STAIR-A', 3, 120, 320, 'staircase'),
    ('Staircase B', 'STAIR-B', 3, 580, 320, 'staircase'),
    ('Corridor Junction', 'COR-1', 3, 300, 100, 'corridor'),
    ('Corridor Junction 2', 'COR-2', 3, 300, 500, 'corridor')
ON CONFLICT (room_number) DO NOTHING;

-- =============================================
-- SAMPLE DATA: SUBJECTS (IT Branch)
-- =============================================
INSERT INTO subjects (name, code, branch_id, semester, credits, is_lab) 
SELECT 'Data Structures', 'IT301', id, 3, 4, false FROM branches WHERE code = 'IT'
ON CONFLICT (code) DO NOTHING;

INSERT INTO subjects (name, code, branch_id, semester, credits, is_lab) 
SELECT 'Database Management', 'IT302', id, 3, 4, false FROM branches WHERE code = 'IT'
ON CONFLICT (code) DO NOTHING;

INSERT INTO subjects (name, code, branch_id, semester, credits, is_lab) 
SELECT 'Computer Networks', 'IT303', id, 3, 3, false FROM branches WHERE code = 'IT'
ON CONFLICT (code) DO NOTHING;

INSERT INTO subjects (name, code, branch_id, semester, credits, is_lab) 
SELECT 'Operating Systems', 'IT304', id, 3, 3, false FROM branches WHERE code = 'IT'
ON CONFLICT (code) DO NOTHING;

INSERT INTO subjects (name, code, branch_id, semester, credits, is_lab) 
SELECT 'DS Lab', 'IT305', id, 3, 2, true FROM branches WHERE code = 'IT'
ON CONFLICT (code) DO NOTHING;

INSERT INTO subjects (name, code, branch_id, semester, credits, is_lab) 
SELECT 'DBMS Lab', 'IT306', id, 3, 2, true FROM branches WHERE code = 'IT'
ON CONFLICT (code) DO NOTHING;

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
