-- ====================================================================
-- SUPABASE FULL-STACK NOTIFICATIONS, ADS & PUBLIC DATA SYSTEM
-- ====================================================================

-- 1. جدول الإشعارات (NOTIFICATIONS TABLE)
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

-- السماح بالقيم الفارغة (NULL) لحقل user_id لدعم إشعارات البث العام
ALTER TABLE public.notifications ALTER COLUMN user_id DROP NOT NULL;

-- التأكد من وجود كافة الأعمدة والمزامنة
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS body TEXT;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS message TEXT;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS payload JSONB DEFAULT '{}'::jsonb;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS created_by UUID;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS type TEXT DEFAULT 'general';
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT false;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

-- مزامنة النص بين body و message لتجنب خطأ Schema Cache
UPDATE public.notifications SET body = message WHERE body IS NULL AND message IS NOT NULL;
UPDATE public.notifications SET message = body WHERE message IS NULL AND body IS NOT NULL;


-- 2. جدول تتبع قراءة الإشعارات العامة (NOTIFICATION READS TABLE)
CREATE TABLE IF NOT EXISTS public.notification_reads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_id UUID REFERENCES public.notifications(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    read_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(notification_id, user_id)
);


-- 3. جدول الإعلانات والبنرات العامة (ADS TABLE)
CREATE TABLE IF NOT EXISTS public.ads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT,
    image_url TEXT,
    target_url TEXT DEFAULT '/announcements',
    placement TEXT DEFAULT 'home_banner',
    is_active BOOLEAN DEFAULT true,
    start_date TIMESTAMPTZ DEFAULT NOW(),
    end_date TIMESTAMPTZ,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);


-- 4. جدول البيانات والإعدادات العامة (ASSOCIATION SETTINGS TABLE)
CREATE TABLE IF NOT EXISTS public.association_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    setting_key TEXT UNIQUE NOT NULL,
    setting_value TEXT NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);


-- 5. تفعيل سياسات الأمان RLS المفتوحة والمحمية (RLS POLICIES)
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_reads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.association_settings ENABLE ROW LEVEL SECURITY;

-- سياسات جدول notifications
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

-- سياسات جدول notification_reads
DROP POLICY IF EXISTS "Users can manage their broadcast reads" ON public.notification_reads;
CREATE POLICY "Users can manage their broadcast reads" ON public.notification_reads
    FOR ALL TO authenticated, anon USING (true) WITH CHECK (true);

-- سياسات جدول ads
DROP POLICY IF EXISTS "Allow all selects on ads" ON public.ads;
CREATE POLICY "Allow all selects on ads" ON public.ads
    FOR SELECT TO authenticated, anon USING (true);

DROP POLICY IF EXISTS "Allow all modifications on ads" ON public.ads;
CREATE POLICY "Allow all modifications on ads" ON public.ads
    FOR ALL TO authenticated WITH CHECK (true);

-- سياسات جدول association_settings
DROP POLICY IF EXISTS "Allow all selects on association_settings" ON public.association_settings;
CREATE POLICY "Allow all selects on association_settings" ON public.association_settings
    FOR SELECT TO authenticated, anon USING (true);

DROP POLICY IF EXISTS "Allow all updates on association_settings" ON public.association_settings;
CREATE POLICY "Allow all updates on association_settings" ON public.association_settings
    FOR ALL TO authenticated WITH CHECK (true);


-- 6. تفعيل البث اللحظي عبر Supabase Realtime (REALTIME PUBLICATION)
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

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'ads'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.ads;
    END IF;
END $$;


-- 7. بيانات تجريبية وسجل بذري للتأكد من المزامنة والعمليات (SEEDER DATA)
INSERT INTO public.association_settings (setting_key, setting_value, description)
VALUES 
    ('association_name', 'جمعية التكافل والتنمية القروية', 'الاسم الرسمي للجمعية'),
    ('association_start_date', '2026-01-01', 'تاريخ الانطلاق الفعلي للجمعية'),
    ('monthly_subscription_default', '1000', 'قيمة الاشتراك الشهري الافتراضية'),
    ('currency', 'ر.ي', 'العملة الرسمية المعتمدة')
ON CONFLICT (setting_key) DO UPDATE 
SET setting_value = EXCLUDED.setting_value, updated_at = NOW();

-- إضافة بنرات إعلانات تجريبية نشطة
INSERT INTO public.ads (title, description, placement, is_active, target_url)
VALUES 
    ('مبادرة سداد الاشتراكات السنوية 🌿', 'يسر إدارة الجمعية الإعلان عن فتح باب سداد الاشتراكات السنوية مقدماً مع توثيق السندات إلكترونياً.', 'home_banner', true, '/subscriptions'),
    ('صندوق الدعم المالي والتكافل الاجتماعي 🤝', 'يمكن لجميع الأعضاء تقديم طلبات المساعدة والعلاج عبر قسم المساعدات للتصديق من اللجنة.', 'home_banner', true, '/assistance')
ON CONFLICT DO NOTHING;

-- إضافة تنبيه بث عام إلكتروني
INSERT INTO public.notifications (user_id, title, body, message, type, payload, is_read)
VALUES 
    (NULL, 'مرحباً بكم في منظومة التكافل القروية 🚀', 'تم إطلاق مركز التنبيهات ونظام الإعلانات التفاعلي بالكامل.', 'تم إطلاق مركز التنبيهات ونظام الإعلانات التفاعلي بالكامل.', 'announcement', '{"route": "/announcements"}'::jsonb, false)
ON CONFLICT DO NOTHING;

-- 8. إعادة تحميل كاش الـ Schema لـ PostgREST
NOTIFY pgrst, 'reload schema';
