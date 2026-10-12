-- =========================================================
-- DATABASE SCHEMA: VILLAGE CHARITY ASSOCIATION (جمعية الخير القروية)
-- SUPABASE POSTGRESQL FULL ARCHITECTURE
-- =========================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ---------------------------------------------------------
-- 1. TABLE: PROFILES
-- Stores information for members, treasurers, and admins
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    phone TEXT NOT NULL,
    national_id TEXT UNIQUE,
    address TEXT,
    birth_date DATE,
    gender TEXT CHECK (gender IN ('male', 'female')),
    avatar_url TEXT,
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('member', 'treasurer', 'admin', 'super_admin')),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
    monthly_subscription NUMERIC(10, 2) NOT NULL DEFAULT 50.00,
    join_date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ---------------------------------------------------------
-- 2. TABLE: PAYMENTS
-- Stores member subscription payments
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    member_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    amount NUMERIC(10, 2) NOT NULL CHECK (amount > 0),
    payment_month INTEGER NOT NULL CHECK (payment_month BETWEEN 1 AND 12),
    payment_year INTEGER NOT NULL CHECK (payment_year >= 2020),
    payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    payment_method TEXT NOT NULL DEFAULT 'cash' CHECK (payment_method IN ('cash', 'bank_transfer', 'check', 'online')),
    receipt_number TEXT UNIQUE NOT NULL,
    receipt_image TEXT,
    notes TEXT,
    created_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ---------------------------------------------------------
-- 3. TABLE: EXPENSES
-- Stores association expenses by category
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.expenses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    description TEXT,
    category TEXT NOT NULL CHECK (category IN ('aid', 'maintenance', 'electricity', 'water', 'projects', 'salaries', 'other')),
    amount NUMERIC(10, 2) NOT NULL CHECK (amount > 0),
    beneficiary TEXT NOT NULL,
    receipt_image TEXT,
    expense_date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ---------------------------------------------------------
-- 4. TABLE: ASSISTANCE_REQUESTS
-- Stores member requests for financial aid
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.assistance_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    member_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    requested_amount NUMERIC(10, 2) NOT NULL CHECK (requested_amount > 0),
    approved_amount NUMERIC(10, 2) DEFAULT 0.00,
    document_url TEXT,
    image_url TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'completed')),
    rejection_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ---------------------------------------------------------
-- 5. TABLE: ANNOUNCEMENTS
-- Association general announcements
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.announcements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    image_url TEXT,
    created_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ---------------------------------------------------------
-- 6. TABLE: NOTIFICATIONS
-- Direct user notification messages
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ---------------------------------------------------------
-- 7. TABLE: AUDIT_LOGS
-- System audit log for important operations
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.profiles(id),
    action TEXT NOT NULL,
    table_name TEXT NOT NULL,
    record_id UUID,
    old_data JSONB,
    new_data JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ---------------------------------------------------------
-- 8. TABLE: FINANCIAL_TRANSACTIONS
-- Immutable Double-Entry Ledger System
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.financial_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transaction_number TEXT UNIQUE NOT NULL,
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('income', 'expense')),
    income_amount NUMERIC(10, 2) DEFAULT 0.00,
    expense_amount NUMERIC(10, 2) DEFAULT 0.00,
    category TEXT NOT NULL,
    reference_table TEXT NOT NULL,
    reference_id UUID NOT NULL,
    description TEXT NOT NULL,
    balance_before NUMERIC(10, 2) NOT NULL,
    balance_after NUMERIC(10, 2) NOT NULL,
    created_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ---------------------------------------------------------
-- DATABASE FUNCTIONS & TRIGGERS FOR BALANCE & LEDGER
-- ---------------------------------------------------------

-- Function to handle new user registration profile creation
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
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger on auth.users for new registration
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- Function to record payment income in financial_transactions ledger
CREATE OR REPLACE FUNCTION public.process_payment_ledger()
RETURNS TRIGGER AS $$
DECLARE
    current_bal NUMERIC(10, 2);
    next_bal NUMERIC(10, 2);
    tx_num TEXT;
BEGIN
    SELECT COALESCE(SUM(income_amount) - SUM(expense_amount), 0.00)
    INTO current_bal
    FROM public.financial_transactions;

    next_bal := current_bal + NEW.amount;
    tx_num := 'INC-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || SUBSTRING(NEW.id::text, 1, 6);

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
        0.00,
        'اشتراك شهري',
        'payments',
        NEW.id,
        'تحصيل اشتراك شهري - شهر ' || NEW.payment_month || '/' || NEW.payment_year,
        current_bal,
        next_bal,
        NEW.created_by
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_payment_inserted
    AFTER INSERT ON public.payments
    FOR EACH ROW EXECUTE FUNCTION public.process_payment_ledger();


-- Function to record expense in financial_transactions ledger
CREATE OR REPLACE FUNCTION public.process_expense_ledger()
RETURNS TRIGGER AS $$
DECLARE
    current_bal NUMERIC(10, 2);
    next_bal NUMERIC(10, 2);
    tx_num TEXT;
BEGIN
    SELECT COALESCE(SUM(income_amount) - SUM(expense_amount), 0.00)
    INTO current_bal
    FROM public.financial_transactions;

    next_bal := current_bal - NEW.amount;
    tx_num := 'EXP-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || SUBSTRING(NEW.id::text, 1, 6);

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
        'expense',
        0.00,
        NEW.amount,
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_expense_inserted
    AFTER INSERT ON public.expenses
    FOR EACH ROW EXECUTE FUNCTION public.process_expense_ledger();

-- ---------------------------------------------------------
-- DATABASE VIEWS
-- ---------------------------------------------------------

-- View: Current Association Balance
CREATE OR REPLACE VIEW public.current_balance_view AS
SELECT 
    COALESCE(SUM(income_amount), 0.00) AS total_income,
    COALESCE(SUM(expense_amount), 0.00) AS total_expenses,
    COALESCE(SUM(income_amount) - SUM(expense_amount), 0.00) AS current_balance
FROM public.financial_transactions;

-- View: Monthly Financial Statistics
CREATE OR REPLACE VIEW public.monthly_statistics_view AS
SELECT 
    EXTRACT(YEAR FROM created_at) AS year,
    EXTRACT(MONTH FROM created_at) AS month,
    SUM(income_amount) AS total_income,
    SUM(expense_amount) AS total_expenses,
    (SUM(income_amount) - SUM(expense_amount)) AS net_change
FROM public.financial_transactions
GROUP BY EXTRACT(YEAR FROM created_at), EXTRACT(MONTH FROM created_at)
ORDER BY year DESC, month DESC;

-- View: Member Payment Status
CREATE OR REPLACE VIEW public.member_payment_status_view AS
SELECT 
    p.id AS member_id,
    p.full_name,
    p.phone,
    p.monthly_subscription,
    p.status,
    COALESCE(SUM(pay.amount), 0.00) AS total_paid,
    COUNT(pay.id) AS payments_count
FROM public.profiles p
LEFT JOIN public.payments pay ON p.id = pay.member_id
WHERE p.role = 'member'
GROUP BY p.id, p.full_name, p.phone, p.monthly_subscription, p.status;

-- ---------------------------------------------------------
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ---------------------------------------------------------

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assistance_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.financial_transactions ENABLE ROW LEVEL SECURITY;

-- Profiles: Members see own profile; Treasurers/Admins see all
CREATE POLICY "Users view own profile" ON public.profiles
    FOR SELECT USING (auth.uid() = id OR EXISTS (
        SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('treasurer', 'admin', 'super_admin')
    ));

CREATE POLICY "Admins update profiles" ON public.profiles
    FOR UPDATE USING (EXISTS (
        SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
    ));

-- Payments: Members see own payments; Treasurers/Admins manage payments
CREATE POLICY "Members view own payments" ON public.payments
    FOR SELECT USING (member_id = auth.uid() OR EXISTS (
        SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('treasurer', 'admin', 'super_admin')
    ));

CREATE POLICY "Treasurers insert payments" ON public.payments
    FOR INSERT WITH CHECK (EXISTS (
        SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('treasurer', 'admin', 'super_admin')
    ));

-- Expenses: Treasurers and Admins manage expenses
CREATE POLICY "All authenticated view expenses" ON public.expenses
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Treasurers insert expenses" ON public.expenses
    FOR INSERT WITH CHECK (EXISTS (
        SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('treasurer', 'admin', 'super_admin')
    ));

-- ============================================================
-- 🗄️ قاعدة بيانات نظام إدارة جمعية التكافل والتنمية القروية
-- النسخة الكاملة - جميع الجداول و العروض (Views)
-- ============================================================

-- 1️⃣ تفعيل الملحقات
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 📋 الجداول الرئيسية
-- ============================================================

-- 1.1 جدول الملفات الشخصية
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    phone TEXT NOT NULL,
    national_id TEXT UNIQUE,
    address TEXT,
    birth_date DATE,
    gender TEXT CHECK (gender IN ('male', 'female')),
    avatar_url TEXT,
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('member', 'treasurer', 'admin', 'super_admin')),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
    monthly_subscription NUMERIC(10, 2) NOT NULL DEFAULT 50.00,
    join_date DATE NOT NULL DEFAULT CURRENT_DATE,
    last_payment_month INTEGER,
    payment_status TEXT DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 1.2 جدول الدفعات
CREATE TABLE IF NOT EXISTS public.payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    member_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    amount NUMERIC(10, 2) NOT NULL CHECK (amount > 0),
    payment_month INTEGER NOT NULL CHECK (payment_month BETWEEN 1 AND 12),
    payment_year INTEGER NOT NULL CHECK (payment_year >= 2020),
    payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    payment_method TEXT NOT NULL DEFAULT 'cash' CHECK (payment_method IN ('cash', 'bank_transfer', 'check', 'online', 'mobile_money', 'crypto')),
    receipt_number TEXT UNIQUE NOT NULL,
    wallet_type TEXT,
    wallet_transaction_id TEXT,
    coverage_months INTEGER[],
    notes TEXT,
    created_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 1.3 جدول تغطية الأشهر
CREATE TABLE IF NOT EXISTS public.monthly_coverage (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    member_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    payment_id UUID NOT NULL REFERENCES public.payments(id) ON DELETE CASCADE,
    month INTEGER NOT NULL CHECK (month BETWEEN 1 AND 12),
    year INTEGER NOT NULL CHECK (year >= 2020),
    is_paid BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(member_id, month, year)
);

-- 1.4 جدول المحافظ
CREATE TABLE IF NOT EXISTS public.wallets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('bank', 'mobile', 'crypto', 'exchange')),
    account_number TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 1.5 جدول المصروفات
CREATE TABLE IF NOT EXISTS public.expenses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    description TEXT,
    category TEXT NOT NULL CHECK (category IN ('aid', 'maintenance', 'electricity', 'water', 'projects', 'salaries', 'other')),
    amount NUMERIC(10, 2) NOT NULL CHECK (amount > 0),
    beneficiary TEXT NOT NULL,
    receipt_image TEXT,
    expense_date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 1.6 جدول طلبات المساعدة
CREATE TABLE IF NOT EXISTS public.assistance_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    member_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    requested_amount NUMERIC(10, 2) NOT NULL CHECK (requested_amount > 0),
    approved_amount NUMERIC(10, 2) DEFAULT 0.00,
    document_url TEXT,
    image_url TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'completed')),
    rejection_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 1.7 جدول الإعلانات
CREATE TABLE IF NOT EXISTS public.announcements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    image_url TEXT,
    created_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 1.8 جدول الإشعارات
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 1.9 جدول سجل التدقيق
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.profiles(id),
    action TEXT NOT NULL,
    table_name TEXT NOT NULL,
    record_id UUID,
    old_data JSONB,
    new_data JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 1.10 جدول المعاملات المالية
CREATE TABLE IF NOT EXISTS public.financial_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transaction_number TEXT UNIQUE NOT NULL,
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('income', 'expense')),
    income_amount NUMERIC(10, 2) DEFAULT 0.00,
    expense_amount NUMERIC(10, 2) DEFAULT 0.00,
    category TEXT NOT NULL,
    reference_table TEXT NOT NULL,
    reference_id UUID NOT NULL,
    description TEXT NOT NULL,
    balance_before NUMERIC(10, 2) NOT NULL,
    balance_after NUMERIC(10, 2) NOT NULL,
    created_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 1.11 جدول إعدادات الجمعية
CREATE TABLE IF NOT EXISTS public.association_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    association_name TEXT NOT NULL DEFAULT 'جمعية التكافل والتنمية القروية',
    association_logo_url TEXT,
    association_address TEXT,
    association_phone TEXT,
    association_email TEXT,
    default_monthly_subscription NUMERIC(10, 2) NOT NULL DEFAULT 50.00,
    currency TEXT DEFAULT 'د.ج',
    max_assistance_amount NUMERIC(10, 2) DEFAULT 10000.00,
    fiscal_year_start DATE DEFAULT '2026-01-01',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================
+-- 📊 VIEWS
-- ============================================================

-- عرض حالة الدفعات للأعضاء
CREATE OR REPLACE VIEW public.member_payment_status AS
SELECT 
    p.id AS member_id,
    p.full_name,
    p.phone,
    p.monthly_subscription,
    p.status,
    COALESCE(
        (SELECT json_agg(json_build_object('month', missing_month, 'year', missing_year))
         FROM get_missing_months(p.id)
        ), '[]'::json
    ) AS missing_months,
    COALESCE(
        (SELECT COUNT(*) FROM public.monthly_coverage mc 
         WHERE mc.member_id = p.id AND mc.is_paid = true)
    , 0) AS paid_months_count
FROM public.profiles p
WHERE p.role = 'member';

-- عرض الرصيد الحالي
CREATE OR REPLACE VIEW public.current_balance_view AS
SELECT 
    COALESCE(SUM(income_amount), 0) AS total_income,
    COALESCE(SUM(expense_amount), 0) AS total_expenses,
    COALESCE(SUM(income_amount) - SUM(expense_amount), 0) AS current_balance
FROM public.financial_transactions;

-- عرض إحصائيات المحافظ
CREATE OR REPLACE VIEW public.wallet_statistics AS
SELECT 
    wallet_type,
    COUNT(*) AS transaction_count,
    SUM(amount) AS total_amount,
    AVG(amount) AS avg_amount
FROM public.payments
WHERE wallet_type IS NOT NULL AND wallet_type != ''
GROUP BY wallet_type
ORDER BY total_amount DESC;
