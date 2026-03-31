# 📊 Supabase Schema Updates for New Features

## Required Tables & Migrations

### 1. Enhancement to `poll_options` → `poll_scheduling`

```sql
-- New table for poll scheduling
CREATE TABLE IF NOT EXISTS poll_scheduling (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    poll_id UUID NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
    scheduled_publish_at TIMESTAMP,
    auto_close_after_minutes INT,
    segment_by_semesters INT[] -- [1, 2, 3]
    segment_by_branches TEXT[] -- ['CSE', 'ECE']
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Index for performance
CREATE INDEX idx_poll_scheduling_poll_id ON poll_scheduling(poll_id);

-- RLS Policy
ALTER TABLE poll_scheduling ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can view poll scheduling"
ON poll_scheduling FOR SELECT
USING (auth.role() = 'authenticated');

CREATE POLICY "Admin users can manage poll scheduling"
ON poll_scheduling FOR ALL
USING (auth.role() = 'service_role');
```

---

### 2. New Table: `poll_insights`

```sql
-- Poll results and analytics
CREATE TABLE IF NOT EXISTS poll_insights (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    poll_id UUID NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
    total_votes INT DEFAULT 0,
    participation_rate FLOAT,
    started_at TIMESTAMP,
    closed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_poll_insights_poll_id ON poll_insights(poll_id);

ALTER TABLE poll_insights ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can view poll insights"
ON poll_insights FOR SELECT
USING (auth.role() = 'authenticated');
```

---

### 3. Enhancement to `chat_messages` → `chat_threads` + `reactions`

```sql
-- Chat threads (replies to messages)
CREATE TABLE IF NOT EXISTS chat_threads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    parent_message_id UUID NOT NULL REFERENCES chat_messages(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES students(id) ON DELETE SET NULL,
    author_name TEXT,
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_chat_threads_parent_id ON chat_threads(parent_message_id);

-- Message reactions (emoji voting)
CREATE TABLE IF NOT EXISTS chat_reactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    message_id UUID NOT NULL REFERENCES chat_messages(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    emoji TEXT NOT NULL, -- '👍', '❤️', etc.
    created_at TIMESTAMP DEFAULT NOW(),
    
    -- Prevent duplicate reactions
    UNIQUE(message_id, user_id, emoji)
);

CREATE INDEX idx_chat_reactions_message_id ON chat_reactions(message_id);

-- Chat message moderation
CREATE TABLE IF NOT EXISTS chat_reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    message_id UUID NOT NULL REFERENCES chat_messages(id) ON DELETE CASCADE,
    reported_by_id UUID NOT NULL REFERENCES students(id) ON DELETE SET NULL,
    reason TEXT NOT NULL, -- profanity, harassment, spam, off-topic
    details TEXT,
    status TEXT DEFAULT 'reported', -- reported, reviewing, resolved, dismissed
    created_at TIMESTAMP DEFAULT NOW(),
    resolved_at TIMESTAMP
);

CREATE INDEX idx_chat_reports_status ON chat_reports(status);

-- User mutes
CREATE TABLE IF NOT EXISTS user_mutes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    muted_by_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    muted_user_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    muted_until TIMESTAMP, -- NULL = permanent
    reason TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    
    -- Prevent duplicate mutes
    UNIQUE(muted_by_id, muted_user_id)
);

-- Pinned messages in branch chat
ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN DEFAULT FALSE;
ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS thread_id UUID REFERENCES chat_threads(id);
ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS mentions UUID[];

-- RLS Policies
ALTER TABLE chat_threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_mutes ENABLE ROW LEVEL SECURITY;

-- Simplified RLS - use service_role for complex logic
CREATE POLICY "Authenticated users can view chat threads"
ON chat_threads FOR SELECT
USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can create reactions"
ON chat_reactions FOR INSERT
WITH CHECK (user_id = auth.uid() OR auth.role() = 'service_role');
```

---

### 4. Enhancement to `study_files` Table

```sql
-- Add new columns to existing study_files table
ALTER TABLE study_files 
ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS teacher TEXT,
ADD COLUMN IF NOT EXISTS subject TEXT,
ADD COLUMN IF NOT EXISTS semester INT,
ADD COLUMN IF NOT EXISTS branch TEXT,
ADD COLUMN IF NOT EXISTS access_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_accessed_at TIMESTAMP;

-- Create bookmarks table
CREATE TABLE IF NOT EXISTS study_bookmarks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    file_id UUID NOT NULL REFERENCES study_files(id) ON DELETE CASCADE,
    notes TEXT,
    bookmarked_at TIMESTAMP DEFAULT NOW(),
    
    -- Prevent duplicate bookmarks
    UNIQUE(student_id, file_id)
);

CREATE INDEX idx_study_bookmarks_student_id ON study_bookmarks(student_id);
CREATE INDEX idx_study_bookmarks_file_id ON study_bookmarks(file_id);

-- Recently accessed tracking
CREATE TABLE IF NOT EXISTS study_recent_files (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    file_id UUID NOT NULL REFERENCES study_files(id) ON DELETE CASCADE,
    last_accessed_at TIMESTAMP DEFAULT NOW(),
    access_count INT DEFAULT 1,
    
    -- Most recent per student/file
    UNIQUE(student_id, file_id)
);

-- Full-text search index (Postgres native)
CREATE INDEX idx_study_files_fts ON study_files 
USING GIN (to_tsvector('english', name || ' ' || subject || ' ' || COALESCE(teacher, '')));

ALTER TABLE study_bookmarks ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_recent_files ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Students can only see their own bookmarks"
ON study_bookmarks FOR ALL
USING (student_id = auth.uid());

CREATE POLICY "Students can only see their own recent files"
ON study_recent_files FOR ALL
USING (student_id = auth.uid());
```

---

### 5. Announcements Table (Existing - Verify Permissions)

```sql
-- Existing notices table - just verify schema
-- ALTER TABLE notices ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN DEFAULT FALSE;
-- ALTER TABLE notices ADD COLUMN IF NOT EXISTS segment_by_branch_id UUID;

-- Verify RLS allows student read
ALTER TABLE notices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can view active notices"
ON notices FOR SELECT
USING (
    auth.role() = 'authenticated' AND
    is_active = TRUE AND
    (expires_at IS NULL OR expires_at > NOW())
);
```

---

## Supabase Service Methods to Implement

```dart
// In supabase_service.dart

// Announcements
static Future<List<Announcement>> getAnnouncements({
  required String branchId,
  bool activeOnly = true,
}) {
  // SELECT * FROM notices
  // WHERE (branch_id = branchId OR branch_id IS NULL)
  // AND (activeOnly ? is_active = true AND expires_at > NOW())
}

// Poll Scheduling
static Future<PollScheduling?> getPollScheduling(String pollId) {
  // SELECT * FROM poll_scheduling WHERE poll_id = pollId
}

static Future<void> schedulePoll(PollScheduling scheduling) {
  // INSERT/UPDATE poll_scheduling
}

// Poll Insights
static Future<PollInsights?> getPollInsights(String pollId) {
  // SELECT * FROM poll_insights WHERE poll_id = pollId
  // Compute participation_rate = (total_votes / eligible_students) * 100
}

// Study Materials Search
static Future<List<StudySearchResult>> searchStudyMaterials(
  StudyMaterialsSearchQuery query,
) {
  // WHERE name ILIKE '%{query.keywords}%'
  // AND (teacher IN filters OR semester IN filters, etc.)
  // ORDER BY relevance DESC (using FTS score)
  // Use to_tsvector for full-text search
}

// Chat Threads
static Future<List<ChatThread>> getChatThreadReplies(String parentMessageId) {
  // SELECT * FROM chat_threads WHERE parent_message_id = parentMessageId
}

// Poll Options with vote trendsRealtimeChannel subscribeToPollTrends(
  String pollId,
  Function(List<OptionTrend>) onUpdate,
) {
  // Subscribe to poll_options updates
  // Compute percentage and trends
}
```

---

## Optional: Realtime Triggers

For auto-computing insights, set up Postgres function:

```sql
-- Function to update poll insights
CREATE OR REPLACE FUNCTION update_poll_insights()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE poll_insights SET
    total_votes = (SELECT COUNT(*) FROM poll_options WHERE poll_id = NEW.poll_id),
    updated_at = NOW()
  WHERE poll_id = NEW.poll_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger after vote insert
CREATE TRIGGER trigger_poll_vote_count
AFTER INSERT ON poll_options
FOR EACH ROW
EXECUTE FUNCTION update_poll_insights();
```

---

## RLS Security Checklist

- [ ] Announcements: Admins can create, students can view active ones
- [ ] Poll scheduling: Only creator and admins can see/edit
- [ ] Chat threads: Accessible to branch members only
- [ ] Chat reactions: User can only add their own
- [ ] Chat reports: Reporters remain anonymous to reported user
- [ ] Study bookmarks: Private to student only
- [ ] Study recent files: Private to student only

---

## Performance Optimization

```sql
-- After creating tables, add these indexes

-- Full-text search
CREATE INDEX idx_study_files_fts ON study_files 
USING GIN (to_tsvector('english', name));

-- Polling hot queries
CREATE INDEX idx_poll_insights_poll_id ON poll_insights(poll_id);
CREATE INDEX idx_poll_scheduling_poll_id ON poll_scheduling(poll_id);

-- Chat hot queries
CREATE INDEX idx_chat_threads_parent_id ON chat_threads(parent_message_id);
CREATE INDEX idx_chat_reactions_message_id ON chat_reactions(message_id);

-- Study bookmarks
CREATE INDEX idx_study_bookmarks_student_id ON study_bookmarks(student_id);
CREATE INDEX idx_study_recent_files_student_id ON study_recent_files(student_id);

-- Announcements
CREATE INDEX idx_notices_branch_id ON notices(branch_id);
CREATE INDEX idx_notices_active ON notices(is_active);
```

---

## Testing Queries

```sql
-- Test FTS search
SELECT name, subject, teacher
FROM study_files
WHERE to_tsvector('english', name || ' ' || subject) @@
      plainto_tsquery('english', 'database design')
LIMIT 10;

-- Test poll segmentation
SELECT * FROM poll_scheduling
WHERE (segment_by_branches IS NULL OR "CSE" = ANY(segment_by_branches))
  AND (segment_by_semesters IS NULL OR 3 = ANY(segment_by_semesters));

-- Test active announcements
SELECT * FROM notices
WHERE is_active = TRUE
  AND (expires_at IS NULL OR expires_at > NOW())
  AND (branch_id IS NULL OR branch_id = 'b123')
ORDER BY is_pinned DESC, created_at DESC;
```

---

**Status**: 📋 Schema-ready for implementation
**Priority**: Implement announcements first (simplest), then search, then polls
