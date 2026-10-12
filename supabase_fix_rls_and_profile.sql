-- ====================================================================
-- DEFINITIVE FIX: RLS POLICIES, DELETE PERMISSION & PROFILE DATA CAPTURE
-- ====================================================================

-- 1. تحديث دالة handle_new_user لتخزين قيمة الاشتراك (1000) ورقم الهوية وعنوان السكن فوراً
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (
        id, 
        full_name, 
        email, 
        phone, 
        role, 
        status, 
        national_id, 
        address, 
        monthly_subscription,
        avatar_url,
        join_date,
        updated_at
    )
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', 'عضو جديد'),
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'phone', '0000000000'),
        COALESCE(NEW.raw_user_meta_data->>'role', 'member'),
        COALESCE(NEW.raw_user_meta_data->>'status', 'active'),
        NEW.raw_user_meta_data->>'national_id',
        NEW.raw_user_meta_data->>'address',
        COALESCE((NEW.raw_user_meta_data->>'monthly_subscription')::NUMERIC, 1000.00),
        NEW.raw_user_meta_data->>'avatar_url',
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        email = COALESCE(EXCLUDED.email, profiles.email),
        full_name = CASE WHEN EXCLUDED.full_name != 'عضو جديد' THEN EXCLUDED.full_name ELSE profiles.full_name END,
        phone = CASE WHEN EXCLUDED.phone != '0000000000' THEN EXCLUDED.phone ELSE profiles.phone END,
        national_id = COALESCE(EXCLUDED.national_id, profiles.national_id),
        address = COALESCE(EXCLUDED.address, profiles.address),
        monthly_subscription = COALESCE(EXCLUDED.monthly_subscription, profiles.monthly_subscription),
        avatar_url = COALESCE(EXCLUDED.avatar_url, profiles.avatar_url),
        updated_at = NOW();
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RETURN NEW;
END;
$$;

-- 2. تفعيل التريجر عند إضافة مستخدم جديد
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- 3. تصحيح سياسات الأمان RLS في جدول profiles للسماح للمدراء بالإدراج والتعديل والحذف
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
DROP POLICY IF EXISTS "Profiles are viewable by authenticated users" ON public.profiles;
DROP POLICY IF EXISTS "Allow read profiles" ON public.profiles;
DROP POLICY IF EXISTS "Allow authenticated read profiles" ON public.profiles;

CREATE POLICY "Allow read profiles" ON public.profiles
    FOR SELECT
    TO authenticated, anon
    USING (true);

DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Admins and users can insert profiles" ON public.profiles;

CREATE POLICY "Admins and users can insert profiles" ON public.profiles
    FOR INSERT
    TO authenticated, anon
    WITH CHECK (
        auth.uid() = id 
        OR (SELECT role FROM public.profiles WHERE id = auth.uid()) IN ('admin', 'super_admin')
        OR auth.role() = 'anon'
    );

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Admins and users can update profiles" ON public.profiles;

CREATE POLICY "Admins and users can update profiles" ON public.profiles
    FOR UPDATE
    TO authenticated
    USING (
        auth.uid() = id 
        OR (SELECT role FROM public.profiles WHERE id = auth.uid()) IN ('admin', 'super_admin')
    )
    WITH CHECK (
        auth.uid() = id 
        OR (SELECT role FROM public.profiles WHERE id = auth.uid()) IN ('admin', 'super_admin')
    );

-- سياسة الحذف للمدراء
DROP POLICY IF EXISTS "Admins can delete profiles" ON public.profiles;
CREATE POLICY "Admins can delete profiles" ON public.profiles
    FOR DELETE
    TO authenticated
    USING (
        (SELECT role FROM public.profiles WHERE id = auth.uid()) IN ('admin', 'super_admin')
    );

-- 4. تحديث قيمة الاشتراك الافتراضية في الجدول إلى 1000 ر.ي بدلاً من 50
ALTER TABLE public.profiles ALTER COLUMN monthly_subscription SET DEFAULT 1000.00;

-- 5. إصلاح أي أعضاء حاليين لديهم قيمة اشتراك 50 وتحويلها إلى 1000 فوراً
UPDATE public.profiles 
SET monthly_subscription = 1000.00 
WHERE monthly_subscription = 50.00 OR monthly_subscription IS NULL;
