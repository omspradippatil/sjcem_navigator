-- =============================================
-- RUN THIS FIRST AS postgres SUPERUSER
-- Command: psql -h localhost -U postgres -d flutterdb -f setup_permissions.sql
-- =============================================

-- Grant schema permissions to flutteruser
GRANT ALL ON SCHEMA public TO flutteruser;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO flutteruser;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO flutteruser;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO flutteruser;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO flutteruser;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO flutteruser;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO flutteruser;

-- Enable UUID extension (requires superuser)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Verify permissions
SELECT 'Permissions granted successfully to flutteruser' AS status;
