-- ====================================================================
-- FIX ANNOUNCEMENTS SCHEMA & COLUMNS (CONTENT / BODY / DESCRIPTION)
-- ====================================================================

-- 1. التأكد من إنشاء جدول announcements إن لم يكن موجوداً
CREATE TABLE IF NOT EXISTS public.announcements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    content TEXT,
    body TEXT,
    description TEXT,
    priority TEXT DEFAULT 'normal',
    is_published BOOLEAN DEFAULT true,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. إضافة أي أعمدة ناقصة
ALTER TABLE public.announcements ADD COLUMN IF NOT EXISTS content TEXT;
ALTER TABLE public.announcements ADD COLUMN IF NOT EXISTS body TEXT;
ALTER TABLE public.announcements ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE public.announcements ADD COLUMN IF NOT EXISTS priority TEXT DEFAULT 'normal';
ALTER TABLE public.announcements ADD COLUMN IF NOT EXISTS is_published BOOLEAN DEFAULT true;
ALTER TABLE public.announcements ADD COLUMN IF NOT EXISTS created_by UUID;
ALTER TABLE public.announcements ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

-- 3. مزامنة النصوص بين الحقول المختلفة
UPDATE public.announcements SET content = COALESCE(content, body, description);
UPDATE public.announcements SET body = COALESCE(body, content, description);
UPDATE public.announcements SET description = COALESCE(description, content, body);

-- 4. إتاحة صلاحيات القراءة والإضافة لقاعدة البيانات
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all selects on announcements" ON public.announcements;
CREATE POLICY "Allow all selects on announcements" ON public.announcements
    FOR SELECT TO authenticated, anon USING (true);

DROP POLICY IF EXISTS "Allow all inserts on announcements" ON public.announcements;
CREATE POLICY "Allow all inserts on announcements" ON public.announcements
    FOR INSERT TO authenticated, anon WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all updates on announcements" ON public.announcements;
CREATE POLICY "Allow all updates on announcements" ON public.announcements
    FOR UPDATE TO authenticated, anon USING (true);

DROP POLICY IF EXISTS "Allow all deletes on announcements" ON public.announcements;
CREATE POLICY "Allow all deletes on announcements" ON public.announcements
    FOR DELETE TO authenticated, anon USING (true);

-- 5. إعادة تحديث كاش Schema الخاص بـ PostgREST
NOTIFY pgrst, 'reload schema';
