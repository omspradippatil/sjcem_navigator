-- =============================================
-- PUSH NOTIFICATIONS MIGRATION
-- Run this in the Supabase SQL Editor
-- =============================================

-- device_tokens: stores each user's OneSignal player_id
-- Upserted by the Flutter app on login, deleted on logout.
-- GitHub Actions reads this table to know which devices to push to.

CREATE TABLE IF NOT EXISTS device_tokens (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL UNIQUE,
    user_type   VARCHAR(20) NOT NULL CHECK (user_type IN ('student', 'teacher')),
    branch_id   UUID,                        -- soft reference, no FK constraint
    player_id   TEXT NOT NULL,
    created_at  TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at  TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for efficient querying by branch (used heavily by GitHub Actions)
CREATE INDEX IF NOT EXISTS idx_device_tokens_branch ON device_tokens(branch_id);
CREATE INDEX IF NOT EXISTS idx_device_tokens_user   ON device_tokens(user_id);

-- Auto-update updated_at on row change
DROP TRIGGER IF EXISTS trigger_device_tokens_updated_at ON device_tokens;
CREATE TRIGGER trigger_device_tokens_updated_at
    BEFORE UPDATE ON device_tokens
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
