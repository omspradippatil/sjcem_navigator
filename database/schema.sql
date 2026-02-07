-- SJCEM Navigator Database Schema
-- Supabase Free Tier Compatible (NO pg_cron)
-- Run this in Supabase SQL Editor
-- Pure schema - no sample data

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
    display_name VARCHAR(100),
    last_modified_by UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for room queries
CREATE INDEX IF NOT EXISTS idx_rooms_floor ON rooms(floor);
CREATE INDEX IF NOT EXISTS idx_rooms_type ON rooms(room_type);

-- Add foreign key for teacher current room
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
    period_number INTEGER NOT NULL CHECK (period_number >= 1 AND period_number <= 12),
    subject_id UUID REFERENCES subjects(id),
    teacher_id UUID REFERENCES teachers(id),
    room_id UUID REFERENCES rooms(id),
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    is_break BOOLEAN DEFAULT FALSE,
    break_name VARCHAR(50),
    batch VARCHAR(10),
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
-- PRIVATE MESSAGES
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
-- POLL VOTES TABLE
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
    action VARCHAR(20) DEFAULT 'enter',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for location history
CREATE INDEX IF NOT EXISTS idx_teacher_location_history ON teacher_location_history(teacher_id, created_at DESC);

-- =============================================
-- NAVIGATION WAYPOINTS
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
-- WAYPOINT CONNECTIONS
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
-- ANNOUNCEMENTS TABLE
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
-- STUDY FOLDERS TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS study_folders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    parent_id UUID REFERENCES study_folders(id) ON DELETE CASCADE,
    created_by UUID REFERENCES teachers(id) ON DELETE CASCADE NOT NULL,
    subject_id UUID REFERENCES subjects(id) ON DELETE SET NULL,
    branch_id UUID REFERENCES branches(id) ON DELETE SET NULL,
    semester INTEGER CHECK (semester >= 1 AND semester <= 8),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for study_folders
CREATE INDEX IF NOT EXISTS idx_study_folders_parent ON study_folders(parent_id);
CREATE INDEX IF NOT EXISTS idx_study_folders_created_by ON study_folders(created_by);
CREATE INDEX IF NOT EXISTS idx_study_folders_branch ON study_folders(branch_id);
CREATE INDEX IF NOT EXISTS idx_study_folders_subject ON study_folders(subject_id);

-- =============================================
-- STUDY FILES TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS study_files (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    folder_id UUID REFERENCES study_folders(id) ON DELETE CASCADE NOT NULL,
    file_url TEXT NOT NULL,
    file_type VARCHAR(50) NOT NULL DEFAULT 'unknown',
    file_size BIGINT NOT NULL DEFAULT 0,
    description TEXT,
    uploaded_by UUID REFERENCES teachers(id) ON DELETE CASCADE NOT NULL,
    download_count INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for study_files
CREATE INDEX IF NOT EXISTS idx_study_files_folder ON study_files(folder_id);
CREATE INDEX IF NOT EXISTS idx_study_files_uploaded_by ON study_files(uploaded_by);
CREATE INDEX IF NOT EXISTS idx_study_files_type ON study_files(file_type);

-- =============================================
-- FUNCTIONS
-- =============================================

-- Update vote count on poll_votes changes
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

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Log teacher location changes
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

-- Auto-update teacher location based on timetable
CREATE OR REPLACE FUNCTION auto_update_teacher_location(p_teacher_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_scheduled_room_id UUID;
    v_current_day INTEGER;
    v_current_time TIME;
BEGIN
    v_current_day := EXTRACT(DOW FROM CURRENT_DATE)::INTEGER;
    v_current_time := CURRENT_TIME;
    
    SELECT room_id INTO v_scheduled_room_id
    FROM timetable
    WHERE teacher_id = p_teacher_id
      AND day_of_week = v_current_day
      AND start_time <= v_current_time
      AND end_time > v_current_time
      AND is_active = true
      AND is_break = false
    LIMIT 1;
    
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

-- Get next class info for teacher
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

-- Auto-update all teachers locations
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

-- Get teacher scheduled room
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

-- Update room display name
CREATE OR REPLACE FUNCTION update_room_display_name(
    p_room_id UUID,
    p_new_display_name VARCHAR(100),
    p_teacher_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    v_is_authorized BOOLEAN;
BEGIN
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

-- Get conversation preview
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

-- Create teacher helper function
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

-- Increment download count
CREATE OR REPLACE FUNCTION increment_download_count(p_file_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE study_files 
    SET download_count = download_count + 1
    WHERE id = p_file_id;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- TRIGGERS
-- =============================================

DROP TRIGGER IF EXISTS trigger_update_vote_count ON poll_votes;
CREATE TRIGGER trigger_update_vote_count
AFTER INSERT OR DELETE ON poll_votes
FOR EACH ROW
EXECUTE FUNCTION update_vote_count();

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

DROP TRIGGER IF EXISTS trigger_teacher_location_change ON teachers;
CREATE TRIGGER trigger_teacher_location_change
AFTER UPDATE OF current_room_id ON teachers
FOR EACH ROW
EXECUTE FUNCTION log_teacher_location_change();

DROP TRIGGER IF EXISTS trigger_study_folders_updated_at ON study_folders;
CREATE TRIGGER trigger_study_folders_updated_at
BEFORE UPDATE ON study_folders
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_study_files_updated_at ON study_files;
CREATE TRIGGER trigger_study_files_updated_at
BEFORE UPDATE ON study_files
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- =============================================
-- VIEWS
-- =============================================

-- Active polls with vote counts
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

-- Todays timetable
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

-- Current ongoing classes
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

-- Teachers with current location details
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
-- ENABLE REALTIME
-- =============================================
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE branch_chat_messages;
    ALTER PUBLICATION supabase_realtime ADD TABLE private_messages;
    ALTER PUBLICATION supabase_realtime ADD TABLE teachers;
    ALTER PUBLICATION supabase_realtime ADD TABLE poll_votes;
    ALTER PUBLICATION supabase_realtime ADD TABLE poll_options;
    ALTER PUBLICATION supabase_realtime ADD TABLE announcements;
    ALTER PUBLICATION supabase_realtime ADD TABLE study_folders;
    ALTER PUBLICATION supabase_realtime ADD TABLE study_files;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- =============================================
-- ROW LEVEL SECURITY
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
ALTER TABLE study_folders ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_files ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
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

-- Create policies (allow all for anon key since using custom auth)
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
CREATE POLICY "Allow all for study_folders" ON study_folders FOR ALL USING (true);
CREATE POLICY "Allow all for study_files" ON study_files FOR ALL USING (true);
CREATE POLICY "HOD can update rooms" ON rooms FOR UPDATE USING (true);

-- =============================================
-- ADDITIONAL INDEXES
-- =============================================
CREATE INDEX IF NOT EXISTS idx_teachers_current_room ON teachers(current_room_id) WHERE current_room_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_timetable_current_time ON timetable(day_of_week, start_time, end_time) WHERE is_active = true;

-- =============================================
-- GRANT PERMISSIONS
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
-- SUPABASE STORAGE BUCKETS
-- =============================================
-- Note: Run these in Supabase SQL Editor with storage schema access

-- Create study-materials storage bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'study-materials',
    'study-materials',
    true,
    52428800, -- 50MB limit
    ARRAY['application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 
          'application/vnd.ms-excel', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          'application/vnd.ms-powerpoint', 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
          'image/jpeg', 'image/png', 'image/gif', 'image/webp',
          'text/plain', 'application/zip', 'application/x-rar-compressed']
)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for study-materials bucket
DROP POLICY IF EXISTS "Allow public read access" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated uploads" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated deletes" ON storage.objects;

-- Anyone can read/download files
CREATE POLICY "Allow public read access"
ON storage.objects FOR SELECT
USING (bucket_id = 'study-materials');

-- Allow uploads (using anon key since custom auth)
CREATE POLICY "Allow authenticated uploads"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'study-materials');

-- Allow deletes (using anon key since custom auth)
CREATE POLICY "Allow authenticated deletes"
ON storage.objects FOR DELETE
USING (bucket_id = 'study-materials');
