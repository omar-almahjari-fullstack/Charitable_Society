-- ============================================================
-- SQL SCRIPT FOR SUPABASE ADMIN USER CONFIRMATION & AUTO-CONFIRM
-- ============================================================

-- 1. التفعيل التلقائي الفوري لجميع الحسابات الجديدة عند التسجيل
CREATE OR REPLACE FUNCTION public.auto_confirm_new_user()
RETURNS TRIGGER AS $$
BEGIN
  NEW.email_confirmed_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ربط التريجر مع جدول المستخدمين
DROP TRIGGER IF EXISTS trigger_auto_confirm_new_user ON auth.users;
CREATE TRIGGER trigger_auto_confirm_new_user
BEFORE INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.auto_confirm_new_user();

-- 2. تأكيد البريد الإلكتروني فوراً لجميع الحسابات المسجلة سابقاً
UPDATE auth.users
SET email_confirmed_at = NOW()
WHERE email_confirmed_at IS NULL;

-- 3. حذف الدوال القديمة لتفادي خطأ (cannot change return type of existing function)
DROP FUNCTION IF EXISTS public.confirm_user_by_admin(UUID);
DROP FUNCTION IF EXISTS public.deactivate_user_by_admin(UUID);

-- 4. إنشاء دالة تأكيد وتفعيل العضو من قِبل المدير من داخل التطبيق
CREATE OR REPLACE FUNCTION public.confirm_user_by_admin(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE public.profiles
  SET status = 'active', updated_at = NOW()
  WHERE id = p_user_id;

  UPDATE auth.users
  SET email_confirmed_at = COALESCE(email_confirmed_at, NOW())
  WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. إنشاء دالة تعليق وإيقاف حساب العضو من قِبل المدير
CREATE OR REPLACE FUNCTION public.deactivate_user_by_admin(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE public.profiles
  SET status = 'suspended', updated_at = NOW()
  WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. سياسة السماح للمدير والمسؤولين بتعديل كافة بيانات الأعضاء في جدول profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated update profiles" ON public.profiles;
CREATE POLICY "Allow authenticated update profiles"
ON public.profiles FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);
