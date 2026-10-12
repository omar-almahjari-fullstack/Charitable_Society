-- ============================================================
-- 🔒 سياسات RLS و بيانات افتراضية (Seeds) والتحققات
-- ============================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assistance_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.financial_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.monthly_coverage ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;

-- سياسات profiles
CREATE POLICY "Users can view own profile" ON public.profiles
    FOR SELECT USING (auth.uid() = id OR 
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'super_admin')));

CREATE POLICY "Users can update own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Admins can update profiles" ON public.profiles
    FOR UPDATE USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
    );

-- سياسات payments
CREATE POLICY "Users can view own payments" ON public.payments
    FOR SELECT USING (member_id = auth.uid() OR 
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'super_admin', 'treasurer')));

-- سياسات expenses
CREATE POLICY "All users can view expenses" ON public.expenses
    FOR SELECT USING (true);

CREATE POLICY "Treasurers can insert expenses" ON public.expenses
    FOR INSERT WITH CHECK (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'super_admin', 'treasurer'))
    );

-- سياسات assistance_requests
CREATE POLICY "Users can view own assistance" ON public.assistance_requests
    FOR SELECT USING (member_id = auth.uid() OR 
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'super_admin')));

CREATE POLICY "Users can insert assistance" ON public.assistance_requests
    FOR INSERT WITH CHECK (member_id = auth.uid());

-- سياسات announcements
CREATE POLICY "All users can view announcements" ON public.announcements
    FOR SELECT USING (true);

-- سياسات notifications
CREATE POLICY "Users can view own notifications" ON public.notifications
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can update own notifications" ON public.notifications
    FOR UPDATE USING (user_id = auth.uid());

-- سياسات financial_transactions
CREATE POLICY "Authenticated users can view transactions" ON public.financial_transactions
    FOR SELECT USING (auth.role() = 'authenticated');

-- سياسات wallets
CREATE POLICY "All users can view wallets" ON public.wallets
    FOR SELECT USING (true);

-- ============================================================
-- 🗃️ بيانات افتراضية (SEED)
-- ============================================================

-- إضافة محافظ افتراضية
INSERT INTO public.wallets (name, type, account_number, is_active) VALUES 
('بنك اليمن الدولي', 'bank', '123456789', true),
('بنك التضامن', 'bank', '987654321', true),
('كاش موبي', 'mobile', '777123456', true),
('مدى باي', 'mobile', '777654321', true),
('بتكوين', 'crypto', '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa', true),
('عملات رقمية', 'exchange', 'EXCH-001', true)
ON CONFLICT (id) DO NOTHING;

-- إعدادات الجمعية
INSERT INTO public.association_settings (
    association_name,
    association_address,
    association_phone,
    association_email,
    default_monthly_subscription,
    currency
) VALUES (
    'جمعية التكافل والتنمية القروية',
    'القرية الفلاحية، الجزائر',
    '0555000000',
    'info@association.dz',
    50.00,
    'د.ج'
) ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- ✅ التحقق من التثبيت
-- ============================================================

SELECT '✅ الجداول:' as section, table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE' ORDER BY table_name;
SELECT '✅ الدوال:' as section, proname FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname NOT LIKE 'pg_%' ORDER BY proname;
SELECT '✅ الترايق:' as section, tgname FROM pg_trigger WHERE tgname NOT LIKE 'pg_%' ORDER BY tgname;
SELECT '✅ سياسات RLS:' as section, policyname, tablename FROM pg_policies WHERE schemaname = 'public' ORDER BY tablename;
