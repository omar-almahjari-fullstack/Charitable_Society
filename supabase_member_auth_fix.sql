-- ====================================================================
-- FULL-STACK SUPABASE AUTH & ADMIN MEMBER CREATION DEFINITIVE FIX
-- ====================================================================

-- 1. التأكد من تفعيل إضافة التشفير pgcrypto
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- 2. دالة التأكيد التلقائي للبريد الإلكتروني لأي مستخدم جديد
CREATE OR REPLACE FUNCTION public.handle_auto_confirm_user()
RETURNS TRIGGER AS $$
BEGIN
    NEW.email_confirmed_at := COALESCE(NEW.email_confirmed_at, NOW());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created_auto_confirm ON auth.users;
CREATE TRIGGER on_auth_user_created_auto_confirm
    BEFORE INSERT OR UPDATE ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_auto_confirm_user();

-- 3. دالة معالجة المستخدم الجديد handle_new_user دون تعارض
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. الدالة الشاملة لإضافة عضو من لوحة التحكم مع تفعيل كلمة المرور الافتراضية
CREATE OR REPLACE FUNCTION public.admin_create_member(
    p_full_name TEXT,
    p_phone TEXT,
    p_email TEXT DEFAULT NULL,
    p_password TEXT DEFAULT '123456',
    p_role TEXT DEFAULT 'member',
    p_status TEXT DEFAULT 'active',
    p_national_id TEXT DEFAULT NULL,
    p_address TEXT DEFAULT NULL,
    p_monthly_subscription NUMERIC DEFAULT 1000.00,
    p_avatar_url TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_effective_email TEXT;
    v_encrypted_pw TEXT;
    v_existing_profile_id UUID;
BEGIN
    -- 1. التحقق من صحة المدخلات
    IF p_full_name IS NULL OR TRIM(p_full_name) = '' THEN
        RAISE EXCEPTION 'الاسم الكامل مطلوب';
    END IF;

    IF p_phone IS NULL OR TRIM(p_phone) = '' THEN
        RAISE EXCEPTION 'رقم الهاتف مطلوب';
    END IF;

    -- 2. إنشاء البريد الإلكتروني الافتراضي القياسي
    IF p_email IS NOT NULL AND TRIM(p_email) != '' AND p_email LIKE '%@%' THEN
        v_effective_email := LOWER(TRIM(p_email));
    ELSE
        v_effective_email := 'member_' || TRIM(p_phone) || '@takaful.com';
    END IF;

    -- 3. تشفير كلمة المرور بنظام Blowfish المتوافق 100% مع Supabase Auth (Bcrypt)
    v_encrypted_pw := extensions.crypt(COALESCE(NULLIF(TRIM(p_password), ''), '123456'), extensions.gen_salt('bf', 10));

    -- 4. فحص ما إذا كان العضو موجوداً مسبقاً في auth.users
    SELECT id INTO v_user_id FROM auth.users WHERE email = v_effective_email LIMIT 1;

    IF v_user_id IS NOT NULL THEN
        -- تحديث كلمة المرور وتأكيد البريد فوراً
        UPDATE auth.users
        SET 
            encrypted_password = v_encrypted_pw,
            email_confirmed_at = COALESCE(email_confirmed_at, NOW()),
            raw_user_meta_data = jsonb_build_object('full_name', p_full_name, 'phone', p_phone, 'role', p_role),
            updated_at = NOW()
        WHERE id = v_user_id;
    ELSE
        -- فحص ما إذا كان العضو موجوداً في profiles لنستخدم نفس المعرف
        SELECT id INTO v_existing_profile_id FROM public.profiles WHERE phone = p_phone LIMIT 1;
        v_user_id := COALESCE(v_existing_profile_id, gen_random_uuid());

        -- إنشاء المستخدم في auth.users
        INSERT INTO auth.users (
            instance_id,
            id,
            aud,
            role,
            email,
            encrypted_password,
            email_confirmed_at,
            raw_app_meta_data,
            raw_user_meta_data,
            created_at,
            updated_at,
            confirmation_token,
            recovery_token
        ) VALUES (
            '00000000-0000-0000-0000-000000000000',
            v_user_id,
            'authenticated',
            'authenticated',
            v_effective_email,
            v_encrypted_pw,
            NOW(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('full_name', p_full_name, 'phone', p_phone, 'role', p_role),
            NOW(),
            NOW(),
            '',
            ''
        ) ON CONFLICT (id) DO UPDATE SET
            encrypted_password = v_encrypted_pw,
            email_confirmed_at = COALESCE(auth.users.email_confirmed_at, NOW()),
            email = v_effective_email;

        -- إنشاء سجل الهوية في auth.identities
        INSERT INTO auth.identities (
            id,
            user_id,
            identity_data,
            provider,
            provider_id,
            last_sign_in_at,
            created_at,
            updated_at
        ) VALUES (
            gen_random_uuid(),
            v_user_id,
            jsonb_build_object('sub', v_user_id::text, 'email', v_effective_email),
            'email',
            v_effective_email,
            NOW(),
            NOW(),
            NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;

    -- 5. إدراج أو تحديث سجل العضو في public.profiles
    INSERT INTO public.profiles (
        id,
        full_name,
        phone,
        email,
        role,
        status,
        national_id,
        address,
        monthly_subscription,
        avatar_url,
        join_date,
        updated_at
    ) VALUES (
        v_user_id,
        p_full_name,
        p_phone,
        v_effective_email,
        p_role,
        p_status,
        p_national_id,
        p_address,
        p_monthly_subscription,
        p_avatar_url,
        NOW(),
        NOW()
    ) ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        email = EXCLUDED.email,
        role = EXCLUDED.role,
        status = EXCLUDED.status,
        national_id = EXCLUDED.national_id,
        address = EXCLUDED.address,
        monthly_subscription = EXCLUDED.monthly_subscription,
        avatar_url = COALESCE(EXCLUDED.avatar_url, profiles.avatar_url),
        updated_at = NOW();

    RETURN jsonb_build_object(
        'success', true,
        'user_id', v_user_id,
        'email', v_effective_email
    );
END;
$$;

-- 5. مزامنة وتأكيد وتعيين كلمة المرور 123456 لجميع الأعضاء الحاليين المسجلين في profiles
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT id, full_name, phone, email, role, status, national_id, address, monthly_subscription, avatar_url 
             FROM public.profiles 
             WHERE phone IS NOT NULL LOOP
        PERFORM public.admin_create_member(
            r.full_name,
            r.phone,
            r.email,
            '123456',
            COALESCE(r.role, 'member'),
            COALESCE(r.status, 'active'),
            r.national_id,
            r.address,
            COALESCE(r.monthly_subscription, 1000.00),
            r.avatar_url
        );
    END LOOP;
END $$;
