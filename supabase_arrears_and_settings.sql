-- ============================================================
-- SQL SCRIPT FOR ASSOCIATION SETTINGS, ARREARS & DUPLICATE PAYMENT PREVENTION
-- ============================================================

-- 1. إنشاء/تعديل جدول إعدادات الجمعية العامة لتشمل تاريخ بداية الجمعية
CREATE TABLE IF NOT EXISTS public.association_settings (
    id INT PRIMARY KEY DEFAULT 1,
    association_name TEXT DEFAULT 'جمعية التكافل والتنمية القروية',
    default_monthly_subscription DECIMAL DEFAULT 1000.0,
    max_assistance_amount DECIMAL DEFAULT 50000.0,
    association_start_date DATE DEFAULT '2024-01-01',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- إدراج الصف الإفتراضي إذا لم يكن موجوداً
INSERT INTO public.association_settings (id, association_name, default_monthly_subscription, max_assistance_amount, association_start_date)
VALUES (1, 'جمعية التكافل والتنمية القروية', 1000.0, 50000.0, '2024-01-01')
ON CONFLICT (id) DO UPDATE SET
    default_monthly_subscription = COALESCE(association_settings.default_monthly_subscription, 1000.0),
    association_start_date = COALESCE(association_settings.association_start_date, '2024-01-01');

-- سياسات الأمان وتصاريح القراءة والكتابة لجدول الإعدادات
ALTER TABLE public.association_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all users to read association settings" ON public.association_settings;
CREATE POLICY "Allow all users to read association settings" 
ON public.association_settings FOR SELECT 
USING (true);

DROP POLICY IF EXISTS "Allow authenticated users to upsert association settings" ON public.association_settings;
CREATE POLICY "Allow authenticated users to upsert association settings" 
ON public.association_settings FOR ALL 
TO authenticated 
USING (true) 
WITH CHECK (true);

DROP POLICY IF EXISTS "Allow anon users to upsert association settings" ON public.association_settings;
CREATE POLICY "Allow anon users to upsert association settings" 
ON public.association_settings FOR ALL 
TO anon 
USING (true) 
WITH CHECK (true);

GRANT ALL ON public.association_settings TO anon, authenticated, service_role;

-- 2. تنظيف أي سجلات دفع مكررة سابقاً في قاعدة البيانات قبل إنشاء الفهرس الفريد
DELETE FROM public.payments
WHERE ctid NOT IN (
    SELECT min(ctid)
    FROM public.payments
    GROUP BY member_id, payment_month, payment_year
);

-- إنشاء الفهرس الفريد لمنع تكرار سداد نفس الشهر لنفس العضو مستقبلاً
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_member_payment_period 
ON public.payments (member_id, payment_month, payment_year);

-- 3. دالة حساب الأشهر المتأخرة المحسوبة ديناميكياً
CREATE OR REPLACE FUNCTION get_missing_months(p_member_id UUID)
RETURNS TABLE(missing_month INTEGER, missing_year INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_assoc_start_date DATE;
    v_join_date DATE;
    v_start_month INTEGER;
    v_start_year INTEGER;
    v_current_month INTEGER;
    v_current_year INTEGER;
BEGIN
    -- جلب تاريخ بداية الجمعية من الإعدادات العامة (افتراضياً 2026-05-01)
    SELECT COALESCE(association_start_date::DATE, '2026-05-01'::DATE)
    INTO v_assoc_start_date
    FROM public.association_settings
    LIMIT 1;

    IF v_assoc_start_date IS NULL THEN
        v_assoc_start_date := '2026-05-01'::DATE;
    END IF;

    v_start_month := EXTRACT(MONTH FROM v_assoc_start_date)::INTEGER;
    v_start_year := EXTRACT(YEAR FROM v_assoc_start_date)::INTEGER;
    v_current_month := EXTRACT(MONTH FROM CURRENT_DATE)::INTEGER;
    v_current_year := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;

    RETURN QUERY
    WITH all_months AS (
        SELECT 
            y.y AS year_val,
            m.m AS month_val
        FROM generate_series(v_start_year, v_current_year) AS y(y),
             generate_series(1, 12) AS m(m)
    )
    SELECT am.month_val AS missing_month, am.year_val AS missing_year
    FROM all_months am
    WHERE NOT (am.year_val = v_current_year AND am.month_val > v_current_month)
      AND NOT (am.year_val = v_start_year AND am.month_val < v_start_month)
      -- استبعاد الأشهر المسددة في جدول payments
      AND NOT EXISTS (
        SELECT 1 FROM public.payments p
        WHERE p.member_id = p_member_id
          AND p.payment_month = am.month_val
          AND p.payment_year = am.year_val
      )
      -- استبعاد الأشهر المسددة في جدول monthly_coverage
      AND NOT EXISTS (
        SELECT 1 FROM public.monthly_coverage mc
        WHERE mc.member_id = p_member_id
          AND mc.month = am.month_val
          AND mc.year = am.year_val
          AND mc.is_paid = true
      )
    ORDER BY am.year_val ASC, am.month_val ASC;
END;
$$;

-- تعديل جدول المعاملات المالية لضمان وجود قيم افتراضية للأرصدة
ALTER TABLE IF EXISTS public.financial_transactions 
ALTER COLUMN balance_before SET DEFAULT 0.00,
ALTER COLUMN balance_after SET DEFAULT 0.00;

-- 4. دالة تسجيل الدفعة مع الفحص المانع لتكرار سداد نفس الشهر وحساب الأرصدة
CREATE OR REPLACE FUNCTION register_payment(
    p_member_id UUID,
    p_amount DECIMAL,
    p_payment_method TEXT,
    p_wallet_type TEXT DEFAULT NULL,
    p_wallet_transaction_id TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL,
    p_payment_month INTEGER DEFAULT NULL,
    p_payment_year INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_payment_id UUID;
    v_receipt_number TEXT;
    v_member_name TEXT;
    v_monthly_subscription DECIMAL;
    v_user_id UUID;
    v_payment_month INTEGER;
    v_payment_year INTEGER;
    v_current_balance DECIMAL;
    v_next_balance DECIMAL;
BEGIN
    -- الحصول على بيانات العضو
    SELECT full_name, COALESCE(monthly_subscription, 1000.0)
    INTO v_member_name, v_monthly_subscription
    FROM public.profiles
    WHERE id = p_member_id;

    IF v_member_name IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'المستفيد غير موجود في السجل');
    END IF;

    v_user_id := auth.uid();
    v_payment_month := COALESCE(p_payment_month, EXTRACT(MONTH FROM CURRENT_DATE)::INTEGER);
    v_payment_year := COALESCE(p_payment_year, EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER);

    -- الفحص المانع لتكرار سداد نفس الشهر لنفس العضو
    IF EXISTS (
        SELECT 1 FROM public.payments
        WHERE member_id = p_member_id
          AND payment_month = v_payment_month
          AND payment_year = v_payment_year
    ) THEN
        RETURN json_build_object(
            'success', false, 
            'error', 'تم سداد اشتراك شهر (' || v_payment_month || '/' || v_payment_year || ') لهذا العضو سابقاً. لا يمكن تكرار السداد لنفس الشهر.'
        );
    END IF;

    -- إنشاء رقم السند
    v_receipt_number := 'REC-' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || '-' || LPAD(floor(random() * 1000000)::text, 6, '0');

    -- إدراج الدفعة
    INSERT INTO public.payments (
        member_id,
        amount,
        payment_month,
        payment_year,
        payment_date,
        payment_method,
        receipt_number,
        wallet_type,
        wallet_transaction_id,
        notes,
        created_by
    ) VALUES (
        p_member_id,
        p_amount,
        v_payment_month,
        v_payment_year,
        CURRENT_DATE,
        p_payment_method,
        v_receipt_number,
        p_wallet_type,
        p_wallet_transaction_id,
        p_notes,
        v_user_id
    ) RETURNING id INTO v_payment_id;

    -- إدراج الأشهر المغطاة
    INSERT INTO public.monthly_coverage (member_id, payment_id, month, year, is_paid)
    VALUES (p_member_id, v_payment_id, v_payment_month, v_payment_year, true)
    ON CONFLICT DO NOTHING;

    -- تحديث حالة العضو
    UPDATE public.profiles
    SET status = 'active', last_payment_month = v_payment_month
    WHERE id = p_member_id;

    -- حساب الرصيد المالي الحالي والقادم
    SELECT COALESCE(SUM(income_amount) - SUM(expense_amount), 0.00)
    INTO v_current_balance
    FROM public.financial_transactions;

    v_next_balance := v_current_balance + p_amount;

    -- تسجيل القيد المالي في الإيرادات
    INSERT INTO public.financial_transactions (
        transaction_number,
        transaction_type,
        income_amount,
        expense_amount,
        category,
        reference_table,
        reference_id,
        description,
        balance_before,
        balance_after,
        created_by
    ) VALUES (
        'INC-' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || '-' || LPAD(floor(random() * 1000000)::text, 6, '0'),
        'income',
        p_amount,
        0.00,
        'اشتراك شهري',
        'payments',
        v_payment_id,
        'تحصيل اشتراك شهر ' || v_payment_month || '/' || v_payment_year || ' للعضو ' || v_member_name,
        v_current_balance,
        v_next_balance,
        v_user_id
    );

    RETURN json_build_object('success', true, 'payment_id', v_payment_id, 'receipt_number', v_receipt_number);
END;
$$;
