
-- Fresh rebuild of the tire-shop and auto-service POS.
-- Keep Supabase Auth users so existing owners can still sign in; reset app tables/data.
drop table if exists public.activity_logs, public.invoices, public.return_items, public.returns,
  public.online_order_events, public.online_order_items, public.online_orders,
  public.sale_payments, public.sale_items, public.sales,
  public.repair_order_payments, public.repair_order_items, public.repair_orders,
  public.purchase_items, public.purchase_orders, public.stock_movements,
  public.service_catalog, public.vehicles, public.customers, public.suppliers,
  public.products, public.categories, public.exchange_rates, public.app_settings,
  public.profiles cascade;

drop sequence if exists public.ro_no_seq, public.sale_no_seq, public.online_order_no_seq,
  public.return_no_seq, public.invoice_no_seq, public.purchase_no_seq cascade;

create sequence public.ro_no_seq start 1;
create sequence public.sale_no_seq start 1;
create sequence public.online_order_no_seq start 1;
create sequence public.return_no_seq start 1;
create sequence public.invoice_no_seq start 1;
create sequence public.purchase_no_seq start 1;

create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null default '',
 role text not null default 'staff' check (role in ('owner','manager','technician','cashier')),
 active boolean not null default true,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);

create table public.app_settings (
 key text primary key,
 value jsonb not null default '{}'::jsonb,
 updated_by uuid references public.profiles(id),
 updated_at timestamptz not null default now()
);
create table public.exchange_rates (
 id uuid primary key default gen_random_uuid(),
 base_currency text not null default 'LAK' check(base_currency in ('LAK','THB','USD')),
 quote_currency text not null check(quote_currency in ('LAK','THB','USD')),
 rate numeric(18,6) not null check(rate>0),
 effective_at timestamptz not null default now(),
 created_by uuid references public.profiles(id)
);

create table public.categories (
 id uuid primary key default gen_random_uuid(),
 name text not null unique,
 kind text not null default 'product' check(kind in ('product','service','labor')),
 active boolean not null default true,
 created_at timestamptz not null default now()
);
create table public.suppliers (
 id uuid primary key default gen_random_uuid(),
 name text not null,
 phone text,
 address text,
 tax_id text,
 note text,
 active boolean not null default true,
 created_at timestamptz not null default now()
);
create table public.products (
 id uuid primary key default gen_random_uuid(),
 sku text unique,
 barcode text unique,
 name text not null,
 category_id uuid references public.categories(id) on delete set null,
 category text,
 brand text,
 model text,
 size text,
 unit text not null default 'ອັນ',
 image_url text,
 cost_lak numeric(18,2) not null default 0,
 price_lak numeric(18,2) not null default 0,
 cost_thb numeric(18,2) not null default 0,
 price_thb numeric(18,2) not null default 0,
 cost_usd numeric(18,2) not null default 0,
 price_usd numeric(18,2) not null default 0,
 stock_on_hand numeric(14,3) not null default 0,
 min_stock numeric(14,3) not null default 0,
 active boolean not null default true,
 note text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 check(stock_on_hand>=0),
 check(min_stock>=0)
);

create table public.customers (
 id uuid primary key default gen_random_uuid(),
 customer_code text unique,
 name text not null,
 phone text,
 address text,
 email text,
 note text,
 active boolean not null default true,
 created_at timestamptz not null default now()
);
create table public.vehicles (
 id uuid primary key default gen_random_uuid(),
 customer_id uuid not null references public.customers(id) on delete cascade,
 plate text not null,
 vin text,
 brand text,
 model text,
 year integer,
 color text,
 engine_no text,
 note text,
 created_at timestamptz not null default now(),
 unique(customer_id,plate)
);
create table public.service_catalog (
 id uuid primary key default gen_random_uuid(),
 name text not null,
 category_id uuid references public.categories(id) on delete set null,
 description text,
 default_labor_price_lak numeric(18,2) not null default 0,
 default_labor_price_thb numeric(18,2) not null default 0,
 default_labor_price_usd numeric(18,2) not null default 0,
 active boolean not null default true,
 created_at timestamptz not null default now()
);

create table public.repair_orders (
 id uuid primary key default gen_random_uuid(),
 ro_no text not null unique default ('RO-'||to_char(current_date,'YYMM')||'-'||lpad(nextval('public.ro_no_seq')::text,5,'0')),
 customer_id uuid not null references public.customers(id),
 vehicle_id uuid not null references public.vehicles(id),
 complaint text not null,
 diagnosis text,
 work_type text not null default 'ສ້ອມທົ່ວໄປ',
 status text not null default 'open' check(status in ('open','diagnosing','waiting_parts','in_progress','ready','delivered','cancelled')),
 assigned_to uuid references public.profiles(id) on delete set null,
 opened_at timestamptz not null default now(),
 promised_at timestamptz,
 completed_at timestamptz,
 currency text not null default 'LAK' check(currency in ('LAK','THB','USD')),
 exchange_rate numeric(18,6) not null default 1,
 parts_total numeric(18,2) not null default 0,
 labor_total numeric(18,2) not null default 0,
 discount numeric(18,2) not null default 0,
 total numeric(18,2) not null default 0,
 paid_amount numeric(18,2) not null default 0,
 balance_due numeric(18,2) not null default 0,
 note text,
 created_by uuid references public.profiles(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table public.repair_order_items (
 id uuid primary key default gen_random_uuid(),
 repair_order_id uuid not null references public.repair_orders(id) on delete cascade,
 line_type text not null check(line_type in ('part','labor','service')),
 product_id uuid references public.products(id) on delete set null,
 service_id uuid references public.service_catalog(id) on delete set null,
 description text not null,
 qty numeric(14,3) not null default 1 check(qty>0),
 unit_cost numeric(18,2) not null default 0,
 unit_price numeric(18,2) not null default 0,
 line_total numeric(18,2) not null default 0,
 stock_issued boolean not null default false,
 created_at timestamptz not null default now()
);
create table public.repair_order_payments (
 id uuid primary key default gen_random_uuid(),
 repair_order_id uuid not null references public.repair_orders(id) on delete cascade,
 amount numeric(18,2) not null check(amount>0),
 currency text not null check(currency in ('LAK','THB','USD')),
 payment_method text not null check(payment_method in ('cash','transfer','mixed','other')),
 note text,
 paid_at timestamptz not null default now(),
 received_by uuid references public.profiles(id)
);

create table public.sales (
 id uuid primary key default gen_random_uuid(),
 sale_no text not null unique default ('S-'||to_char(current_date,'YYMM')||'-'||lpad(nextval('public.sale_no_seq')::text,5,'0')),
 customer_id uuid references public.customers(id) on delete set null,
 vehicle_id uuid references public.vehicles(id) on delete set null,
 channel text not null default 'counter' check(channel in ('counter','online','repair')),
 status text not null default 'completed' check(status in ('pending','completed','cancelled','returned','partial_return')),
 currency text not null default 'LAK' check(currency in ('LAK','THB','USD')),
 exchange_rate numeric(18,6) not null default 1,
 subtotal numeric(18,2) not null default 0,
 discount numeric(18,2) not null default 0,
 total numeric(18,2) not null default 0,
 paid_amount numeric(18,2) not null default 0,
 balance_due numeric(18,2) not null default 0,
 payment_method text not null default 'cash' check(payment_method in ('cash','transfer','mixed','cod','pay_origin','other')),
 note text,
 sold_by uuid references public.profiles(id),
 sale_date date not null default current_date,
 created_at timestamptz not null default now()
);
create table public.sale_items (
 id uuid primary key default gen_random_uuid(),
 sale_id uuid not null references public.sales(id) on delete cascade,
 product_id uuid references public.products(id) on delete set null,
 service_id uuid references public.service_catalog(id) on delete set null,
 description text not null,
 line_type text not null default 'product' check(line_type in ('product','service','labor')),
 qty numeric(14,3) not null default 1 check(qty>0),
 unit_cost numeric(18,2) not null default 0,
 unit_price numeric(18,2) not null default 0,
 line_total numeric(18,2) not null default 0
);
create table public.sale_payments (
 id uuid primary key default gen_random_uuid(),
 sale_id uuid not null references public.sales(id) on delete cascade,
 amount numeric(18,2) not null check(amount>0),
 currency text not null check(currency in ('LAK','THB','USD')),
 payment_method text not null check(payment_method in ('cash','transfer','mixed','cod','pay_origin','other')),
 note text,
 paid_at timestamptz not null default now(),
 received_by uuid references public.profiles(id)
);

create table public.online_orders (
 id uuid primary key default gen_random_uuid(),
 order_no text not null unique default ('ON-'||to_char(current_date,'YYMM')||'-'||lpad(nextval('public.online_order_no_seq')::text,5,'0')),
 customer_id uuid references public.customers(id) on delete set null,
 customer_name text not null,
 customer_phone text not null,
 delivery_address text,
 channel text not null default 'facebook',
 status text not null default 'new' check(status in ('new','confirmed','packed','shipped','delivered','rejected','returned','cancelled')),
 payment_method text not null default 'cod' check(payment_method in ('cod','pay_origin','transfer','cash')),
 currency text not null default 'LAK' check(currency in ('LAK','THB','USD')),
 exchange_rate numeric(18,6) not null default 1,
 subtotal numeric(18,2) not null default 0,
 shipping_fee numeric(18,2) not null default 0,
 discount numeric(18,2) not null default 0,
 total numeric(18,2) not null default 0,
 paid_amount numeric(18,2) not null default 0,
 note text,
 created_by uuid references public.profiles(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table public.online_order_items (
 id uuid primary key default gen_random_uuid(),
 online_order_id uuid not null references public.online_orders(id) on delete cascade,
 product_id uuid references public.products(id) on delete set null,
 description text not null,
 qty numeric(14,3) not null default 1 check(qty>0),
 unit_cost numeric(18,2) not null default 0,
 unit_price numeric(18,2) not null default 0,
 line_total numeric(18,2) not null default 0
);
create table public.online_order_events (
 id uuid primary key default gen_random_uuid(),
 online_order_id uuid not null references public.online_orders(id) on delete cascade,
 status text not null,
 note text,
 created_by uuid references public.profiles(id),
 created_at timestamptz not null default now()
);

create table public.returns (
 id uuid primary key default gen_random_uuid(),
 return_no text not null unique default ('RT-'||to_char(current_date,'YYMM')||'-'||lpad(nextval('public.return_no_seq')::text,5,'0')),
 sale_id uuid references public.sales(id) on delete set null,
 online_order_id uuid references public.online_orders(id) on delete set null,
 reason text not null,
 disposition text not null default 'restock' check(disposition in ('restock','damaged','reject')),
 refund_method text not null default 'cash' check(refund_method in ('cash','transfer','credit','other')),
 currency text not null default 'LAK' check(currency in ('LAK','THB','USD')),
 total_refund numeric(18,2) not null default 0,
 status text not null default 'completed' check(status in ('pending','completed','rejected')),
 processed_by uuid references public.profiles(id),
 created_at timestamptz not null default now()
);
create table public.return_items (
 id uuid primary key default gen_random_uuid(),
 return_id uuid not null references public.returns(id) on delete cascade,
 sale_item_id uuid references public.sale_items(id) on delete set null,
 product_id uuid references public.products(id) on delete set null,
 description text not null,
 qty numeric(14,3) not null default 1 check(qty>0),
 unit_price numeric(18,2) not null default 0,
 line_total numeric(18,2) not null default 0
);

create table public.purchase_orders (
 id uuid primary key default gen_random_uuid(),
 purchase_no text not null unique default ('PO-'||to_char(current_date,'YYMM')||'-'||lpad(nextval('public.purchase_no_seq')::text,5,'0')),
 supplier_id uuid references public.suppliers(id) on delete set null,
 status text not null default 'received' check(status in ('draft','ordered','received','cancelled')),
 currency text not null default 'LAK' check(currency in ('LAK','THB','USD')),
 exchange_rate numeric(18,6) not null default 1,
 subtotal numeric(18,2) not null default 0,
 total numeric(18,2) not null default 0,
 paid_amount numeric(18,2) not null default 0,
 balance_due numeric(18,2) not null default 0,
 note text,
 created_by uuid references public.profiles(id),
 received_at timestamptz not null default now(),
 created_at timestamptz not null default now()
);
create table public.purchase_items (
 id uuid primary key default gen_random_uuid(),
 purchase_order_id uuid not null references public.purchase_orders(id) on delete cascade,
 product_id uuid references public.products(id) on delete set null,
 description text not null,
 qty numeric(14,3) not null default 1 check(qty>0),
 unit_cost numeric(18,2) not null default 0,
 line_total numeric(18,2) not null default 0
);
create table public.stock_movements (
 id uuid primary key default gen_random_uuid(),
 product_id uuid not null references public.products(id) on delete cascade,
 movement_type text not null check(movement_type in ('opening','purchase_in','sale_out','repair_issue','return_in','return_out','adjustment_in','adjustment_out','online_reserve','online_release')),
 qty numeric(14,3) not null,
 stock_before numeric(14,3) not null,
 stock_after numeric(14,3) not null,
 ref_table text,
 ref_id uuid,
 note text,
 created_by uuid references public.profiles(id),
 created_at timestamptz not null default now()
);
create table public.invoices (
 id uuid primary key default gen_random_uuid(),
 invoice_no text not null unique default ('INV-'||to_char(current_date,'YYMM')||'-'||lpad(nextval('public.invoice_no_seq')::text,5,'0')),
 sale_id uuid references public.sales(id) on delete set null,
 repair_order_id uuid references public.repair_orders(id) on delete set null,
 customer_id uuid references public.customers(id) on delete set null,
 currency text not null default 'LAK' check(currency in ('LAK','THB','USD')),
 subtotal numeric(18,2) not null default 0,
 discount numeric(18,2) not null default 0,
 total numeric(18,2) not null default 0,
 note text,
 issued_by uuid references public.profiles(id),
 issued_at timestamptz not null default now()
);
create table public.activity_logs (
 id bigint generated always as identity primary key,
 user_id uuid references public.profiles(id) on delete set null,
 action text not null,
 entity_type text not null,
 entity_id text,
 details jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now()
);

create index products_name_idx on public.products(name);
create index products_stock_idx on public.products(stock_on_hand,min_stock);
create index customers_phone_idx on public.customers(phone);
create index vehicles_plate_idx on public.vehicles(plate);
create index repair_orders_status_idx on public.repair_orders(status,opened_at desc);
create index repair_orders_customer_idx on public.repair_orders(customer_id,opened_at desc);
create index sales_date_idx on public.sales(sale_date desc);
create index online_orders_status_idx on public.online_orders(status,created_at desc);
create index stock_movements_product_idx on public.stock_movements(product_id,created_at desc);
create index activity_logs_created_idx on public.activity_logs(created_at desc);

create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path=public as $$
begin new.updated_at=now(); return new; end $$;
create trigger products_updated_at before update on public.products for each row execute function public.set_updated_at();
create trigger profiles_updated_at before update on public.profiles for each row execute function public.set_updated_at();
create trigger repair_orders_updated_at before update on public.repair_orders for each row execute function public.set_updated_at();
create trigger online_orders_updated_at before update on public.online_orders for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public,auth as $$
begin
 insert into public.profiles(id,full_name,role,active)
 values(new.id,coalesce(new.raw_user_meta_data->>'full_name',''),case when not exists(select 1 from public.profiles) then 'owner' else 'staff' end,true)
 on conflict(id) do nothing;
 return new;
end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.app_settings enable row level security;
alter table public.exchange_rates enable row level security;
alter table public.categories enable row level security;
alter table public.suppliers enable row level security;
alter table public.products enable row level security;
alter table public.customers enable row level security;
alter table public.vehicles enable row level security;
alter table public.service_catalog enable row level security;
alter table public.repair_orders enable row level security;
alter table public.repair_order_items enable row level security;
alter table public.repair_order_payments enable row level security;
alter table public.sales enable row level security;
alter table public.sale_items enable row level security;
alter table public.sale_payments enable row level security;
alter table public.online_orders enable row level security;
alter table public.online_order_items enable row level security;
alter table public.online_order_events enable row level security;
alter table public.returns enable row level security;
alter table public.return_items enable row level security;
alter table public.purchase_orders enable row level security;
alter table public.purchase_items enable row level security;
alter table public.stock_movements enable row level security;
alter table public.invoices enable row level security;
alter table public.activity_logs enable row level security;

-- Helper predicates avoid recursive profile RLS policy evaluation.
create or replace function public.is_active_staff()
returns boolean language sql stable security definer set search_path=public as $
 select exists(select 1 from public.profiles where id=auth.uid() and active=true)
$;
create or replace function public.is_owner()
returns boolean language sql stable security definer set search_path=public as $
 select exists(select 1 from public.profiles where id=auth.uid() and active=true and role='owner')
$;

-- Authenticated staff use the shop workspace. Role-sensitive RPC checks are applied server-side.
do $
declare t text;
begin
 foreach t in array array['app_settings','exchange_rates','categories','suppliers','products','customers','vehicles','service_catalog','repair_orders','repair_order_items','repair_order_payments','sales','sale_items','sale_payments','online_orders','online_order_items','online_order_events','returns','return_items','purchase_orders','purchase_items','stock_movements','invoices','activity_logs'] loop
  execute format('create policy "staff_access_%s" on public.%I for all to authenticated using (public.is_active_staff()) with check (public.is_active_staff())',t,t);
 end loop;
end $$;
create policy "profile_self_or_owner_read" on public.profiles for select to authenticated using (id=auth.uid() or public.is_owner());
create policy "profile_owner_manage" on public.profiles for all to authenticated using (public.is_owner()) with check (public.is_owner());

grant usage on schema public to anon, authenticated;
grant select,insert,update,delete on all tables in schema public to authenticated;
grant usage,select on all sequences in schema public to authenticated;
grant execute on function public.set_updated_at() to authenticated;
grant execute on function public.handle_new_user() to authenticated;
grant execute on function public.is_active_staff() to authenticated;
grant execute on function public.is_owner() to authenticated;
