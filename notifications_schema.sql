-- ====================================================================
-- NOTIFICATIONS CENTER SYSTEM SCHEMA & MIGRATION SCRIPT
-- ====================================================================

-- 1. إنشاء جدول الإشعارات والتنبيهات (notifications)
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT,
    body TEXT,
    type TEXT NOT NULL DEFAULT 'SYSTEM',
    action_url TEXT,
    payload JSONB DEFAULT '{}'::jsonb,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    read_at TIMESTAMPTZ,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- السماح بحقل user_id أن يكون NULL لدعم الإشعارات العامة الموجهة لجميع الأعضاء (Broadcast)
ALTER TABLE public.notifications ALTER COLUMN user_id DROP NOT NULL;

-- التأكد من إضافة وتوافق كافة الأعمدة في حال كان الجدول منشأ مسبقاً
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS title TEXT;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS message TEXT;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS body TEXT;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS type TEXT DEFAULT 'SYSTEM';
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS action_url TEXT;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS payload JSONB DEFAULT '{}'::jsonb;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT FALSE;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS created_by UUID;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- مزامنة النصوص بين الحقلين message و body لضمان التوافق التام
UPDATE public.notifications SET message = COALESCE(message, body, '');
UPDATE public.notifications SET body = COALESCE(body, message, '');


-- 2. جدول تتبع قراءة التنبيهات العامة للمستخدمين (notification_reads)
CREATE TABLE IF NOT EXISTS public.notification_reads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_id UUID REFERENCES public.notifications(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    read_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(notification_id, user_id)
);


-- 3. إنشاء الفهارس (Indexes) لتسريع الاستعلامات والفلترة
CREATE INDEX IF NOT EXISTS idx_notifications_user_is_read ON public.notifications (user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON public.notifications (type);
CREATE INDEX IF NOT EXISTS idx_notification_reads_user ON public.notification_reads (user_id, notification_id);


-- 4. دالة و Trigger لتحديث حقل updated_at تلقائياً عند أي تعديل
CREATE OR REPLACE FUNCTION public.handle_notifications_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    IF NEW.is_read = TRUE AND OLD.is_read = FALSE AND NEW.read_at IS NULL THEN
        NEW.read_at = NOW();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_notifications_updated_at ON public.notifications;
CREATE TRIGGER trg_notifications_updated_at
    BEFORE UPDATE ON public.notifications
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_notifications_updated_at();


-- 5. تفعيل سياسات الأمان على مستوى الصفوف (Row Level Security - RLS)
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_reads ENABLE ROW LEVEL SECURITY;

-- سياسات جدول notifications
DROP POLICY IF EXISTS "Allow users to select their notifications" ON public.notifications;
CREATE POLICY "Allow users to select their notifications" ON public.notifications
    FOR SELECT TO authenticated, anon 
    USING (user_id = auth.uid() OR user_id IS NULL);

DROP POLICY IF EXISTS "Allow insert notifications" ON public.notifications;
CREATE POLICY "Allow insert notifications" ON public.notifications
    FOR INSERT TO authenticated, anon 
    WITH CHECK (true);

DROP POLICY IF EXISTS "Allow users to update their notifications" ON public.notifications;
CREATE POLICY "Allow users to update their notifications" ON public.notifications
    FOR UPDATE TO authenticated, anon 
    USING (user_id = auth.uid() OR user_id IS NULL)
    WITH CHECK (true);

DROP POLICY IF EXISTS "Allow users to delete their notifications" ON public.notifications;
CREATE POLICY "Allow users to delete their notifications" ON public.notifications
    FOR DELETE TO authenticated, anon 
    USING (user_id = auth.uid() OR user_id IS NULL);

-- سياسات جدول notification_reads
DROP POLICY IF EXISTS "Allow users to manage their broadcast reads" ON public.notification_reads;
CREATE POLICY "Allow users to manage their broadcast reads" ON public.notification_reads
    FOR ALL TO authenticated, anon 
    USING (user_id = auth.uid() OR auth.uid() IS NULL)
    WITH CHECK (user_id = auth.uid() OR auth.uid() IS NULL);


-- 6. تفعيل البث اللحظي عبر Supabase Realtime
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


-- 7. بيانات تجريبية وبذرية للاختبار المباشر (Seed / Mock Test Data)
INSERT INTO public.notifications (user_id, title, message, body, type, action_url, payload, is_read, created_at)
VALUES 
    (
        NULL,
        'مرحباً بك في مركز التنبيهات الذكي 🌿',
        'تم إطلاق مركز التنبيهات الجديد لتلقي كافة التحديثات المالية والإدارية والقرارات العامة فور صدورها.',
        'تم إطلاق مركز التنبيهات الجديد لتلقي كافة التحديثات المالية والإدارية والقرارات العامة فور صدورها.',
        'SYSTEM',
        '/announcements',
        '{"route": "/announcements", "priority": "high"}'::jsonb,
        FALSE,
        NOW() - INTERVAL '1 hour'
    ),
    (
        NULL,
        'تذكير سداد الاشتراكات الشهرية 💳',
        'يرجى من جميع الأعضاء الكرام تسوية الاشتراكات الشهرية لضمان استمرارية الخدمات التكافلية.',
        'يرجى من جميع الأعضاء الكرام تسوية الاشتراكات الشهرية لضمان استمرارية الخدمات التكافلية.',
        'SUBSCRIPTION',
        '/subscriptions',
        '{"route": "/subscriptions", "category": "finance"}'::jsonb,
        FALSE,
        NOW() - INTERVAL '3 hours'
    ),
    (
        NULL,
        'فتح باب تقديم طلبات الإعانة والمساعدات 🤝',
        'تعلن لجنة التكافل عن استقبال طلبات المساعدات للحالات المستحقة عبر قسم المساعدات بالتطبيق.',
        'تعلن لجنة التكافل عن استقبال طلبات المساعدات للحالات المستحقة عبر قسم المساعدات بالتطبيق.',
        'ASSISTANCE',
        '/assistance',
        '{"route": "/assistance"}'::jsonb,
        TRUE,
        NOW() - INTERVAL '1 day'
    ),
    (
        NULL,
        'تنبيه أمني: تحديث بيانات الحساب 🔒',
        'يرجى مراجعة وتحديث رقم الهاتف والعنوان في الملف الشخصي لضمان وصول الإشعارات بشكل دقيق.',
        'يرجى مراجعة وتحديث رقم الهاتف والعنوان في الملف الشخصي لضمان وصول الإشعارات بشكل دقيق.',
        'ALERT',
        '/settings',
        '{"route": "/settings"}'::jsonb,
        TRUE,
        NOW() - INTERVAL '2 days'
    )
ON CONFLICT DO NOTHING;

-- 8. إعادة تحميل كاش الـ Schema الخاص بـ PostgREST
NOTIFY pgrst, 'reload schema';
