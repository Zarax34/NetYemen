-- DEMO SEED DATA
-- Inserted via idempotency (ON CONFLICT DO NOTHING for fixed UUIDs)
-- 
-- ROLLBACK:
-- DELETE FROM public.payment_destinations WHERE id IN ('d1111111-1111-1111-1111-111111111111', 'd2222222-2222-2222-2222-222222222222', 'd3333333-3333-3333-3333-333333333333');
-- DELETE FROM public.network_packages WHERE network_id IN ('b1111111-1111-1111-1111-111111111111', 'b2222222-2222-2222-2222-222222222222', 'b3333333-3333-3333-3333-333333333333');
-- DELETE FROM public.networks WHERE id IN ('b1111111-1111-1111-1111-111111111111', 'b2222222-2222-2222-2222-222222222222', 'b3333333-3333-3333-3333-333333333333');
-- Note: package_inventory_balances are deleted via CASCADE from network_packages.

INSERT INTO public.networks (
    id, commercial_name, description, governorate, city, district, 
    status, verification_status, created_by, approved_by, approved_at
) VALUES
('b1111111-1111-1111-1111-111111111111', 'تجريبي - شبكة النور', 'شبكة تجريبية', 'صنعاء', 'صنعاء', 'السبعين', 'active', 'verified', '44118f3d-2489-454b-9fd9-4ae238905562', '44118f3d-2489-454b-9fd9-4ae238905562', now()),
('b2222222-2222-2222-2222-222222222222', 'تجريبي - شبكة عدن', 'شبكة تجريبية', 'عدن', 'عدن', 'كريتر', 'active', 'verified', '44118f3d-2489-454b-9fd9-4ae238905562', '44118f3d-2489-454b-9fd9-4ae238905562', now()),
('b3333333-3333-3333-3333-333333333333', 'تجريبي - شبكة تعز', 'شبكة تجريبية', 'تعز', 'تعز', 'المظفر', 'active', 'verified', '44118f3d-2489-454b-9fd9-4ae238905562', '44118f3d-2489-454b-9fd9-4ae238905562', now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.network_packages (
    id, network_id, name, description, price, currency, duration_value, duration_unit, speed_mbps, package_type, status, is_public, sort_order, created_by
) VALUES
('c1111111-1111-1111-1111-111111111111', 'b1111111-1111-1111-1111-111111111111', 'تجريبي - باقة يومية', 'وصف الباقة اليومية', 500, 'YER', 1, 'day', 2, 'time', 'active', true, 1, '44118f3d-2489-454b-9fd9-4ae238905562'),
('c1111111-1111-1111-1111-222222222222', 'b1111111-1111-1111-1111-111111111111', 'تجريبي - باقة اسبوعية', 'وصف الباقة الأسبوعية', 2500, 'YER', 1, 'week', 2, 'time', 'active', true, 2, '44118f3d-2489-454b-9fd9-4ae238905562'),
('c2222222-2222-2222-2222-111111111111', 'b2222222-2222-2222-2222-222222222222', 'تجريبي - باقة شهرية', 'وصف الباقة الشهرية', 8000, 'YER', 1, 'month', 4, 'time', 'active', true, 1, '44118f3d-2489-454b-9fd9-4ae238905562'),
('c2222222-2222-2222-2222-222222222222', 'b2222222-2222-2222-2222-222222222222', 'تجريبي - باقة يومية', 'وصف الباقة اليومية', 600, 'YER', 1, 'day', 2, 'time', 'active', true, 2, '44118f3d-2489-454b-9fd9-4ae238905562'),
('c3333333-3333-3333-3333-111111111111', 'b3333333-3333-3333-3333-333333333333', 'تجريبي - باقة يومية', 'وصف', 400, 'YER', 1, 'day', 1, 'time', 'active', true, 1, '44118f3d-2489-454b-9fd9-4ae238905562'),
('c3333333-3333-3333-3333-222222222222', 'b3333333-3333-3333-3333-333333333333', 'تجريبي - باقة أسبوعية', 'وصف', 2000, 'YER', 1, 'week', 2, 'time', 'active', true, 2, '44118f3d-2489-454b-9fd9-4ae238905562')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.package_inventory_balances (
    package_id, network_id, total_units, available_units, is_available
) VALUES
('c1111111-1111-1111-1111-111111111111', 'b1111111-1111-1111-1111-111111111111', 100, 100, true),
('c1111111-1111-1111-1111-222222222222', 'b1111111-1111-1111-1111-111111111111', 100, 100, true),
('c2222222-2222-2222-2222-111111111111', 'b2222222-2222-2222-2222-222222222222', 100, 100, true),
('c2222222-2222-2222-2222-222222222222', 'b2222222-2222-2222-2222-222222222222', 100, 100, true),
('c3333333-3333-3333-3333-111111111111', 'b3333333-3333-3333-3333-333333333333', 100, 100, true),
('c3333333-3333-3333-3333-222222222222', 'b3333333-3333-3333-3333-333333333333', 100, 100, true)
ON CONFLICT (package_id) DO UPDATE SET total_units = EXCLUDED.total_units, available_units = EXCLUDED.available_units, is_available = EXCLUDED.is_available;

INSERT INTO public.payment_destinations (
    id, provider_type, display_name, account_holder_name, account_identifier, instructions, currency, is_active, sort_order
) VALUES
('d1111111-1111-1111-1111-111111111111', 'bank_account', 'تجريبي - بنك الكريمي', 'شركة نت يمن', '123456789', 'يرجى التحويل إلى هذا الحساب', 'YER', true, 1),
('d2222222-2222-2222-2222-222222222222', 'mobile_wallet', 'تجريبي - جوالي', 'نت يمن', '777000000', 'التحويل عبر رقم الهاتف', 'YER', true, 2),
('d3333333-3333-3333-3333-333333333333', 'bank_account', 'تجريبي - بنك التضامن', 'شركة نت يمن', '987654321', 'تحويل عبر بنك التضامن', 'YER', true, 3)
ON CONFLICT (id) DO NOTHING;
