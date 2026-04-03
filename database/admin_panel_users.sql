-- Admin panel user accounts for teacher/HOD/admin scoped access
-- Run in Supabase SQL Editor

CREATE TABLE IF NOT EXISTS admin_panel_users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(60) NOT NULL UNIQUE,
    password_hash VARCHAR(64) NOT NULL,
    display_name VARCHAR(120),
    role VARCHAR(20) NOT NULL CHECK (role IN ('teacher', 'hod', 'admin')),
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

DO $$
DECLARE
    constraint_name text;
BEGIN
    FOR constraint_name IN
        SELECT tc.constraint_name
        FROM information_schema.table_constraints tc
        JOIN information_schema.constraint_column_usage ccu
          ON ccu.constraint_name = tc.constraint_name
         AND ccu.constraint_schema = tc.constraint_schema
        WHERE tc.table_schema = 'public'
          AND tc.table_name = 'admin_panel_users'
          AND tc.constraint_type = 'CHECK'
          AND ccu.column_name = 'role'
    LOOP
        EXECUTE format('ALTER TABLE public.admin_panel_users DROP CONSTRAINT %I', constraint_name);
    END LOOP;

    EXECUTE 'ALTER TABLE public.admin_panel_users ADD CONSTRAINT admin_panel_users_role_check CHECK (role IN (''teacher'', ''hod'', ''admin''))';
END $$;

CREATE INDEX IF NOT EXISTS idx_admin_panel_users_branch ON admin_panel_users(branch_id);
CREATE INDEX IF NOT EXISTS idx_admin_panel_users_active ON admin_panel_users(is_active);

-- Permissions for browser-based admin panel using anon key
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.admin_panel_users TO anon, authenticated;

-- RLS policies (open by design for this panel's custom password gate)
ALTER TABLE public.admin_panel_users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS admin_panel_users_select ON public.admin_panel_users;
DROP POLICY IF EXISTS admin_panel_users_insert ON public.admin_panel_users;
DROP POLICY IF EXISTS admin_panel_users_update ON public.admin_panel_users;
DROP POLICY IF EXISTS admin_panel_users_delete ON public.admin_panel_users;

CREATE POLICY admin_panel_users_select
ON public.admin_panel_users
FOR SELECT
TO anon, authenticated
USING (true);

CREATE POLICY admin_panel_users_insert
ON public.admin_panel_users
FOR INSERT
TO anon, authenticated
WITH CHECK (true);

CREATE POLICY admin_panel_users_update
ON public.admin_panel_users
FOR UPDATE
TO anon, authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY admin_panel_users_delete
ON public.admin_panel_users
FOR DELETE
TO anon, authenticated
USING (true);

-- Optional seed record (password hash below is SHA-256 for: om)
-- INSERT INTO admin_panel_users (username, password_hash, display_name, role, branch_id, is_active)
-- VALUES ('hod_mech', 'bf4f6cce4e4f1e0f6f9ddf4f8186d2c5d7f8e17c4f9c67f6cf5dd3f2fcec2f16', 'HOD Mechanical', 'hod', '<branch-uuid>', TRUE);

-- Activity log for admin panel actions
CREATE TABLE IF NOT EXISTS admin_panel_activity (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    admin_panel_user_id UUID REFERENCES admin_panel_users(id) ON DELETE SET NULL,
    username TEXT NOT NULL,
    branch_id UUID REFERENCES branches(id) ON DELETE SET NULL,
    module_key TEXT NOT NULL,
    action TEXT NOT NULL,
    details TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_panel_activity_branch ON admin_panel_activity(branch_id);
CREATE INDEX IF NOT EXISTS idx_admin_panel_activity_created_at ON admin_panel_activity(created_at DESC);

GRANT SELECT, INSERT ON TABLE public.admin_panel_activity TO anon, authenticated;

ALTER TABLE public.admin_panel_activity ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS admin_panel_activity_select ON public.admin_panel_activity;
DROP POLICY IF EXISTS admin_panel_activity_insert ON public.admin_panel_activity;

CREATE POLICY admin_panel_activity_select
ON public.admin_panel_activity
FOR SELECT
TO anon, authenticated
USING (true);

CREATE POLICY admin_panel_activity_insert
ON public.admin_panel_activity
FOR INSERT
TO anon, authenticated
WITH CHECK (true);
