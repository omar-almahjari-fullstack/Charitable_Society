-- ============================================================
-- AUDIT LOGS & ACTIVITY TRACKING SYSTEM MIGRATION
-- نظام التدقيق والرقابة وتتبع العمليات الشامل
-- ============================================================

-- 1. Create or Upgrade audit_logs Table
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    user_type TEXT DEFAULT 'member',
    action TEXT NOT NULL,
    module TEXT NOT NULL,
    entity TEXT NOT NULL,
    entity_id TEXT,
    old_values JSONB,
    new_values JSONB,
    ip_address TEXT,
    user_agent TEXT,
    status TEXT DEFAULT 'SUCCESS',
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Ensure all required columns exist if table already existed
ALTER TABLE audit_logs 
  ADD COLUMN IF NOT EXISTS user_type TEXT DEFAULT 'member',
  ADD COLUMN IF NOT EXISTS module TEXT,
  ADD COLUMN IF NOT EXISTS entity TEXT,
  ADD COLUMN IF NOT EXISTS entity_id TEXT,
  ADD COLUMN IF NOT EXISTS old_values JSONB,
  ADD COLUMN IF NOT EXISTS new_values JSONB,
  ADD COLUMN IF NOT EXISTS ip_address TEXT,
  ADD COLUMN IF NOT EXISTS user_agent TEXT,
  ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'SUCCESS',
  ADD COLUMN IF NOT EXISTS error_message TEXT;

-- 2. Performance & Search Indexes (فهارس مركبة لتسريع البحث والاستعلامات)
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity_entity_id ON audit_logs (entity, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs (user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs (action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_module ON audit_logs (module);
CREATE INDEX IF NOT EXISTS idx_audit_logs_status ON audit_logs (status);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_type ON audit_logs (user_type);

-- 3. Append-Only Protection (حظر الحذف والتعديل على السجلات برمجياً)
CREATE OR REPLACE FUNCTION prevent_audit_log_modification()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'Audit logs are immutable append-only records and cannot be updated or deleted!';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_prevent_audit_log_update_delete ON audit_logs;
CREATE TRIGGER trg_prevent_audit_log_update_delete
BEFORE UPDATE OR DELETE ON audit_logs
FOR EACH ROW
EXECUTE FUNCTION prevent_audit_log_modification();

-- 4. Row Level Security (RLS) Policies
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Allow insert for authenticated users
DROP POLICY IF EXISTS "Enable insert for authenticated users on audit_logs" ON audit_logs;
CREATE POLICY "Enable insert for authenticated users on audit_logs"
ON audit_logs FOR INSERT TO authenticated
WITH CHECK (true);

-- Allow select for Admins, Super Admins, Treasurers, and user's own actions
DROP POLICY IF EXISTS "Enable select for users on audit_logs" ON audit_logs;
CREATE POLICY "Enable select for users on audit_logs"
ON audit_logs FOR SELECT TO authenticated
USING (
  user_id = auth.uid() 
  OR EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() 
    AND profiles.role IN ('admin', 'super_admin', 'treasurer')
  )
);
