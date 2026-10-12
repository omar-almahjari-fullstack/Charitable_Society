-- ============================================================
-- SQL SCRIPT: CLEAN TRIGGERS & AUTO-CONFIRM USERS (100% CLEAN)
-- ============================================================

-- 1. إزالة كافة التريجرات والدوال المعطلة
DROP TRIGGER IF EXISTS on_auth_user_created_auto_confirm ON auth.users;
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS on_auth_user_updated ON auth.users;
DROP TRIGGER IF EXISTS on_auth_user_auto_confirm ON auth.users;

DROP FUNCTION IF EXISTS public.handle_auto_confirm_user();
DROP FUNCTION IF EXISTS public.auto_confirm_all_users();
DROP FUNCTION IF EXISTS public.admin_create_member(text,text,text,text,text,text,text,text,numeric,text);
DROP FUNCTION IF EXISTS public.create_or_update_member_auth(text,text,text,text);

-- 2. إرجاع دالة معالجة المستخدم الجديد القياسية
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name, email, phone, role)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', 'عضو جديد'),
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'phone', '0000000000'),
        COALESCE(NEW.raw_user_meta_data->>'role', 'member')
    )
    ON CONFLICT (id) DO UPDATE SET
        email = COALESCE(EXCLUDED.email, profiles.email),
        full_name = CASE WHEN EXCLUDED.full_name != 'عضو جديد' THEN EXCLUDED.full_name ELSE profiles.full_name END,
        phone = CASE WHEN EXCLUDED.phone != '0000000000' THEN EXCLUDED.phone ELSE profiles.phone END;
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RETURN NEW;
END;
$$;

-- 3. تفعيل التريجر فقط عند إنشاء مستخدم جديد (AFTER INSERT)
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- 4. تأكيد وتفعيل كافة الحسابات لتسجيل الدخول الفوري
UPDATE auth.users 
SET email_confirmed_at = COALESCE(email_confirmed_at, NOW())
WHERE email_confirmed_at IS NULL;
