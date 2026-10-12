-- ====================================================================
-- SUPABASE NOTIFICATIONS SYSTEM & DATABASE FIX (BODY & MESSAGE)
-- ====================================================================

-- 1. التأكد من إنشاء الجدول وتجهيز الأعمدة
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT,
    message TEXT,
    type TEXT NOT NULL DEFAULT 'general',
    payload JSONB DEFAULT '{}'::jsonb,
    is_read BOOLEAN DEFAULT false,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- إزالة أي قيد NOT NULL من user_id لتمكين الإشعارات العامة
ALTER TABLE public.notifications ALTER COLUMN user_id DROP NOT NULL;

-- إضافة أي أعمدة ناقصة ومزامنتها
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS body TEXT;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS message TEXT;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS payload JSONB DEFAULT '{}'::jsonb;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS created_by UUID;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS type TEXT DEFAULT 'general';
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT false;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

-- مزامنة القيم بين body و message
UPDATE public.notifications SET body = message WHERE body IS NULL AND message IS NOT NULL;
UPDATE public.notifications SET message = body WHERE message IS NULL AND body IS NOT NULL;

-- 2. جدول تتبع قراءة الإعلانات العامة
CREATE TABLE IF NOT EXISTS public.notification_reads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_id UUID REFERENCES public.notifications(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    read_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(notification_id, user_id)
);

-- 3. تفعيل سياسات الأمان RLS المفتوحة والمحمية
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_reads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all inserts on notifications" ON public.notifications;
CREATE POLICY "Allow all inserts on notifications" ON public.notifications
    FOR INSERT TO authenticated, anon WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all selects on notifications" ON public.notifications;
CREATE POLICY "Allow all selects on notifications" ON public.notifications
    FOR SELECT TO authenticated, anon USING (true);

DROP POLICY IF EXISTS "Allow all updates on notifications" ON public.notifications;
CREATE POLICY "Allow all updates on notifications" ON public.notifications
    FOR UPDATE TO authenticated, anon USING (true);

DROP POLICY IF EXISTS "Allow all deletes on notifications" ON public.notifications;
CREATE POLICY "Allow all deletes on notifications" ON public.notifications
    FOR DELETE TO authenticated, anon USING (true);

DROP POLICY IF EXISTS "Users can manage their broadcast reads" ON public.notification_reads;
CREATE POLICY "Users can manage their broadcast reads" ON public.notification_reads
    FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 4. إتاحة البث اللحظي عبر Supabase Realtime
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'notifications'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
    END IF;
END $$;

-- 5. إعادة تحميل كاش الـ Schema لـ PostgREST
NOTIFY pgrst, 'reload schema';
