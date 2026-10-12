-- ============================================================
-- SQL MIGRATION FOR SYSTEM AUDIT LOGS & NOTIFICATIONS
-- ============================================================

-- 1. إنشاء جدول سجل العمليات والتدقيق الشامل (audit_logs)
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    user_name TEXT DEFAULT 'مستخدم غير معروف',
    user_role TEXT DEFAULT 'member',
    action TEXT NOT NULL,
    category TEXT DEFAULT 'عام',
    description TEXT NOT NULL,
    target_id TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. إتاحة الصلاحيات لجدول الرقابة والتدقيق
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow select for authenticated users" ON public.audit_logs;
CREATE POLICY "Allow select for authenticated users"
ON public.audit_logs FOR SELECT
TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow insert for authenticated users" ON public.audit_logs;
CREATE POLICY "Allow insert for authenticated users"
ON public.audit_logs FOR INSERT
TO authenticated WITH CHECK (true);

-- 3. ضمان هيكلة جدول الإشعارات notifications
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type TEXT DEFAULT 'info',
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow users select own notifications" ON public.notifications;
CREATE POLICY "Allow users select own notifications"
ON public.notifications FOR SELECT
TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Allow authenticated insert notifications" ON public.notifications;
CREATE POLICY "Allow authenticated insert notifications"
ON public.notifications FOR INSERT
TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Allow users update own notifications" ON public.notifications;
CREATE POLICY "Allow users update own notifications"
ON public.notifications FOR UPDATE
TO authenticated USING (auth.uid() = user_id);
