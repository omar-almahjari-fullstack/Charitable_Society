-- ============================================================
-- 🔧 الدوال (FUNCTIONS) و Triggers
-- هذا الملف يضم الدوال المركبة وfunctions المستخدمة من قبل التطبيق
-- ============================================================

-- 2.1 دالة الحصول على الأشهر المتأخرة
CREATE OR REPLACE FUNCTION get_missing_months(p_member_id UUID)
RETURNS TABLE(missing_month INTEGER, missing_year INTEGER) AS $$
BEGIN
    RETURN QUERY
    WITH months AS (
        SELECT 
            EXTRACT(MONTH FROM CURRENT_DATE)::INTEGER AS current_month,
            EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER AS current_year,
            COALESCE(
                EXTRACT(MONTH FROM join_date)::INTEGER, 
                EXTRACT(MONTH FROM CURRENT_DATE)::INTEGER
            ) AS join_month,
            COALESCE(
                EXTRACT(YEAR FROM join_date)::INTEGER, 
                EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER
            ) AS join_year
        FROM public.profiles
        WHERE id = p_member_id
    ),
    all_months AS (
        SELECT 
            y.y,
            m.m
        FROM generate_series(
            (SELECT join_year FROM months)::INTEGER, 
            (SELECT current_year FROM months)::INTEGER
        ) AS y(y),
        generate_series(1, 12) AS m(m)
    )
    SELECT am.m AS missing_month, am.y AS missing_year
    FROM all_months am
    CROSS JOIN months m
    WHERE NOT (am.y = m.current_year AND am.m > m.current_month)
      AND NOT (am.y = m.join_year AND am.m < m.join_month)
      AND NOT EXISTS (
        SELECT 1 FROM public.monthly_coverage mc
        WHERE mc.member_id = p_member_id
        AND mc.month = am.m
        AND mc.year = am.y
        AND mc.is_paid = true
      )
    ORDER BY am.y, am.m;
END;
$$ LANGUAGE plpgsql;

-- 2.2 دالة إنشاء المستخدم الجديد
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name, email, phone, role, avatar_url)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', 'عضو جديد'),
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'phone', '0000000000'),
        COALESCE(NEW.raw_user_meta_data->>'role', 'member'),
        COALESCE(NEW.raw_user_meta_data->>'avatar_url', NULL)
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2.3 دالة تسجيل الدفعة (register_payment)
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
    v_months_covered INT;
    v_current_balance DECIMAL;
    v_coverage_month DATE;
    v_remaining_amount DECIMAL;
    v_user_id UUID;
    v_payment_month INTEGER;
    v_payment_year INTEGER;
BEGIN
    -- الحصول على اسم العضو وقيمة الاشتراك
    SELECT full_name, monthly_subscription 
    INTO v_member_name, v_monthly_subscription
    FROM public.profiles
    WHERE id = p_member_id;
    
    IF v_member_name IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Member not found');
    END IF;
    
    -- الحصول على user_id
    v_user_id := auth.uid();
    
    -- تعيين الشهر والسنة
    v_payment_month := COALESCE(p_payment_month, EXTRACT(MONTH FROM CURRENT_DATE));
    v_payment_year := COALESCE(p_payment_year, EXTRACT(YEAR FROM CURRENT_DATE));
    
    -- حساب عدد الأشهر المغطاة
    v_months_covered := FLOOR(p_amount / v_monthly_subscription);
    
    IF v_months_covered <= 0 THEN
        RETURN json_build_object('success', false, 'error', 'المبلغ أقل من قيمة الاشتراك الشهري');
    END IF;
    
    -- إنشاء رقم السند
    v_receipt_number := 'REC-' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || '-' || 
                         LPAD(floor(random() * 1000000)::text, 6, '0');
    
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
    
    -- إنشاء سجل الأشهر المغطاة
    v_remaining_amount := p_amount;
    v_coverage_month := DATE_TRUNC('month', CURRENT_DATE);
    
    WHILE v_remaining_amount >= v_monthly_subscription LOOP
        INSERT INTO public.monthly_coverage (member_id, payment_id, month, year, is_paid)
        VALUES (
            p_member_id,
            v_payment_id,
            EXTRACT(MONTH FROM v_coverage_month),
            EXTRACT(YEAR FROM v_coverage_month),
            true
        );
        
        v_remaining_amount := v_remaining_amount - v_monthly_subscription;
        v_coverage_month := v_coverage_month + INTERVAL '1 month';
    END LOOP;
    
    -- تحديث حالة العضو
    UPDATE public.profiles 
    SET 
        status = 'active',
        last_payment_month = v_payment_month
    WHERE id = p_member_id;
    
    -- تسجيل المعاملة المالية
    SELECT COALESCE(SUM(income_amount) - SUM(expense_amount), 0)
    INTO v_current_balance
    FROM public.financial_transactions;
    
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
        0,
        'اشتراك شهري',
        'payments',
        v_payment_id,
        'تحصيل اشتراك من ' || v_member_name || ' (تغطي ' || v_months_covered || ' أشهر)',
        v_current_balance,
        v_current_balance + p_amount,
        v_user_id
    );
    
    -- إنشاء إشعار
    INSERT INTO public.notifications (
        user_id,
        title,
        message,
        is_read
    ) VALUES (
        p_member_id,
        'تم تسجيل دفعة جديدة',
        'تم تسجيل دفعة بقيمة ' || p_amount || ' د.ج تغطي ' || v_months_covered || ' أشهر',
        false
    );
    
    -- تسجيل في سجل التدقيق
    INSERT INTO public.audit_logs (
        user_id,
        action,
        table_name,
        record_id,
        new_data
    ) VALUES (
        v_user_id,
        'create_payment',
        'payments',
        v_payment_id,
        json_build_object(
            'member_id', p_member_id,
            'amount', p_amount,
            'receipt_number', v_receipt_number,
            'months_covered', v_months_covered
        )
    );
    
    RETURN json_build_object(
        'success', true,
        'payment_id', v_payment_id,
        'receipt_number', v_receipt_number,
        'months_covered', v_months_covered,
        'amount', p_amount
    );
END;
$$;

-- ============================================================
-- ⚡ الترايق (TRIGGERS)
-- ============================================================

-- 3.1 Trigger لإنشاء الملف الشخصي عند التسجيل
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- 3.2 Trigger لتسجيل المعاملات المالية عند إضافة دفعة
CREATE OR REPLACE FUNCTION process_payment_ledger()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_bal NUMERIC(10, 2);
    next_bal NUMERIC(10, 2);
    tx_num TEXT;
    member_name TEXT;
BEGIN
    SELECT full_name INTO member_name
    FROM public.profiles
    WHERE id = NEW.member_id;
    
    SELECT COALESCE(SUM(income_amount) - SUM(expense_amount), 0)
    INTO current_bal
    FROM public.financial_transactions;
    
    next_bal := current_bal + NEW.amount;
    
    tx_num := 'INC-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || 
              LPAD(floor(random() * 1000000)::text, 6, '0');
    
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
        tx_num,
        'income',
        NEW.amount,
        0,
        'اشتراك شهري',
        'payments',
        NEW.id,
        'تحصيل اشتراك من ' || COALESCE(member_name, 'عضو'),
        current_bal,
        next_bal,
        NEW.created_by
    );
    
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_payment_inserted ON public.payments;
CREATE TRIGGER on_payment_inserted
    AFTER INSERT ON public.payments
    FOR EACH ROW
    EXECUTE FUNCTION process_payment_ledger();

-- 3.3 Trigger لتسجيل المعاملات المالية عند إضافة مصروف
CREATE OR REPLACE FUNCTION process_expense_ledger()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_bal NUMERIC(10, 2);
    next_bal NUMERIC(10, 2);
    tx_num TEXT;
BEGIN
    SELECT COALESCE(SUM(income_amount) - SUM(expense_amount), 0)
    INTO current_bal
    FROM public.financial_transactions;
    
    next_bal := current_bal - NEW.amount;
    
    tx_num := 'EXP-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || 
              LPAD(floor(random() * 1000000)::text, 6, '0');
    
    INSERT INTO public.financial_transactions (
        transaction_number,
        transaction_type,
        expense_amount,
        income_amount,
        category,
        reference_table,
        reference_id,
        description,
        balance_before,
        balance_after,
        created_by
    ) VALUES (
        tx_num,
        'expense',
        NEW.amount,
        0,
        NEW.category,
        'expenses',
        NEW.id,
        NEW.title || ' - المستفيد: ' || NEW.beneficiary,
        current_bal,
        next_bal,
        NEW.created_by
    );
    
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_expense_inserted ON public.expenses;
CREATE TRIGGER on_expense_inserted
    AFTER INSERT ON public.expenses
    FOR EACH ROW
    EXECUTE FUNCTION process_expense_ledger();
