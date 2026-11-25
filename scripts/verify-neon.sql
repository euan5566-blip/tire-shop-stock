-- Read-only verification for the Tire Shop Stock Neon database.
-- Run with: psql "$DATABASE_URL" -f scripts/verify-neon.sql
-- This script does not insert, update, or delete business data.

WITH expected(table_name) AS (
  VALUES
    ('activity_logs'), ('app_settings'), ('categories'),
    ('customer_special_orders'), ('customers'), ('exchange_rates'),
    ('expenses'), ('inventory_orders'), ('invoices'),
    ('online_order_events'), ('online_order_items'), ('online_orders'),
    ('products'), ('profiles'), ('purchase_items'), ('purchase_orders'),
    ('quotation_items'), ('quotations'), ('repair_order_items'),
    ('repair_order_payments'), ('repair_orders'), ('return_items'),
    ('returns'), ('sale_items'), ('sale_payments'), ('sales'),
    ('service_catalog'), ('staff_payments'), ('stock_movements'),
    ('supplier_payments'), ('suppliers'), ('vehicles'), ('warranty_records')
)
SELECT
  e.table_name,
  CASE WHEN t.table_name IS NULL THEN 'MISSING' ELSE 'OK' END AS table_status
FROM expected e
LEFT JOIN information_schema.tables t
  ON t.table_schema = 'public'
 AND t.table_name = e.table_name
ORDER BY e.table_name;

-- Row counts for the main business tables (exact counts).
DO $$
DECLARE
  t text;
  n bigint;
  tables text[] := ARRAY[
    'products','customers','vehicles','sales','sale_items','expenses',
    'suppliers','stock_movements','app_settings','repair_orders',
    'repair_order_items','repair_order_payments','quotations','quotation_items',
    'returns','return_items','sale_payments','invoices','purchase_orders',
    'purchase_items','supplier_payments','online_orders','online_order_items',
    'online_order_events','inventory_orders','customer_special_orders',
    'warranty_records','profiles','categories','exchange_rates',
    'service_catalog','staff_payments','activity_logs'
  ];
BEGIN
  RAISE NOTICE '--- Exact public table row counts ---';
  FOREACH t IN ARRAY tables LOOP
    IF to_regclass(format('public.%I', t)) IS NULL THEN
      RAISE NOTICE '%: MISSING', t;
    ELSE
      EXECUTE format('SELECT count(*) FROM public.%I', t) INTO n;
      RAISE NOTICE '%: %', t, n;
    END IF;
  END LOOP;
END $$;

-- Confirm the application-critical product, sales and profile columns exist.
SELECT table_name, column_name
FROM information_schema.columns
WHERE table_schema = 'public'
  AND (
    (table_name = 'products' AND column_name IN
      ('id','name','stock_on_hand','min_stock','cost_lak','price_lak','cost_thb','price_thb','image_url','active'))
    OR
    (table_name = 'sales' AND column_name IN
      ('id','sale_no','sale_date','status','currency','total','paid_amount','balance_due'))
    OR
    (table_name = 'profiles' AND column_name IN
      ('id','full_name','role','active'))
  )
ORDER BY table_name, ordinal_position;
