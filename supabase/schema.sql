-- Tire Shop POS MVP schema for Supabase
-- Run this once in Supabase SQL Editor for your project.
-- Safe to re-run for the initial setup; this migration does not delete business data.

create extension if not exists pgcrypto;
create sequence if not exists public.sale_no_seq;

create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text,
  name text,
  role text not null default 'owner' check (role in ('owner','manager','staff')),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  category text,
  barcode text,
  stock_qty integer not null default 0 check (stock_qty >= 0),
  min_stock integer not null default 0 check (min_stock >= 0),
  cost_price numeric(14,2) not null default 0 check (cost_price >= 0),
  sale_price numeric(14,2) not null default 0 check (sale_price >= 0),
  currency_code text not null default 'LAK' check (currency_code in ('LAK','THB')),
  tire_size text,
  brand text,
  model text,
  created_at timestamptz not null default now()
);

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  phone text,
  address text,
  created_at timestamptz not null default now()
);

create table if not exists public.vehicles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  customer_id uuid references public.customers(id) on delete set null,
  plate_no text not null,
  brand text,
  model text,
  created_at timestamptz not null default now(),
  unique(user_id, plate_no)
);

create table if not exists public.sales (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  sale_no text not null unique,
  sale_date date not null default current_date,
  customer_id uuid references public.customers(id) on delete set null,
  vehicle_id uuid references public.vehicles(id) on delete set null,
  payment_method text not null default 'เงินสด',
  currency_code text not null default 'LAK' check (currency_code in ('LAK','THB')),
  note text,
  total numeric(14,2) not null default 0,
  profit numeric(14,2) not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.sale_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  sale_id uuid not null references public.sales(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  product_name text not null,
  qty integer not null check (qty > 0),
  unit_price numeric(14,2) not null check (unit_price >= 0),
  unit_cost numeric(14,2) not null check (unit_cost >= 0),
  line_total numeric(14,2) not null,
  line_profit numeric(14,2) not null,
  created_at timestamptz not null default now()
);

create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  expense_date date not null default current_date,
  title text not null,
  category text,
  amount numeric(14,2) not null check (amount >= 0),
  currency_code text not null default 'LAK' check (currency_code in ('LAK','THB')),
  created_at timestamptz not null default now()
);

-- Additive columns for earlier installations.
alter table public.products add column if not exists currency_code text not null default 'LAK';
alter table public.products add column if not exists tire_size text;
alter table public.products add column if not exists brand text;
alter table public.products add column if not exists model text;
alter table public.sales add column if not exists currency_code text not null default 'LAK';
alter table public.expenses add column if not exists currency_code text not null default 'LAK';

create index if not exists products_user_idx on public.products(user_id);
create index if not exists customers_user_idx on public.customers(user_id);
create index if not exists vehicles_user_idx on public.vehicles(user_id);
create index if not exists sales_user_date_idx on public.sales(user_id,sale_date desc);
create index if not exists sale_items_sale_idx on public.sale_items(sale_id);
create index if not exists expenses_user_date_idx on public.expenses(user_id,expense_date desc);

alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.customers enable row level security;
alter table public.vehicles enable row level security;
alter table public.sales enable row level security;
alter table public.sale_items enable row level security;
alter table public.expenses enable row level security;

drop policy if exists "profile select own" on public.profiles;
create policy "profile select own" on public.profiles
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "products own rows" on public.products;
create policy "products own rows" on public.products
  for all to authenticated using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "customers own rows" on public.customers;
create policy "customers own rows" on public.customers
  for all to authenticated using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "vehicles own rows" on public.vehicles;
create policy "vehicles own rows" on public.vehicles
  for all to authenticated using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "sales select own" on public.sales;
create policy "sales select own" on public.sales
  for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "sales insert own" on public.sales;
create policy "sales insert own" on public.sales
  for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "sales update own" on public.sales;
create policy "sales update own" on public.sales
  for update to authenticated using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "sale items select own" on public.sale_items;
create policy "sale items select own" on public.sale_items
  for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "sale items insert own" on public.sale_items;
create policy "sale items insert own" on public.sale_items
  for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists "expenses own rows" on public.expenses;
create policy "expenses own rows" on public.expenses
  for all to authenticated using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

grant select on public.profiles to authenticated;
grant select, insert, update, delete on public.products, public.customers, public.vehicles, public.expenses to authenticated;
grant select, insert, update on public.sales to authenticated;
grant select, insert on public.sale_items to authenticated;
grant usage, select on sequence public.sale_no_seq to authenticated;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles(user_id,email,name)
  values (new.id,new.email,coalesce(new.raw_user_meta_data ->> 'name',''))
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.create_sale(
  p_customer_id uuid default null,
  p_vehicle_id uuid default null,
  p_payment_method text default 'เงินสด',
  p_note text default null,
  p_items jsonb default '[]'::jsonb,
  p_currency_code text default 'LAK'
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_sale_id uuid;
  v_sale_no text;
  v_total numeric(14,2) := 0;
  v_profit numeric(14,2) := 0;
  v_item jsonb;
  v_product public.products%rowtype;
  v_qty integer;
  v_price numeric(14,2);
  v_line_total numeric(14,2);
  v_line_profit numeric(14,2);
begin
  if v_uid is null then raise exception 'ต้องเข้าสู่ระบบก่อนขายสินค้า'; end if;
  if p_currency_code not in ('LAK','THB') then raise exception 'สกุลเงินไม่รองรับ'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'กรุณาเพิ่มสินค้าอย่างน้อย 1 รายการ';
  end if;

  v_sale_no := 'TS-' || to_char(current_date,'YYYYMMDD') || '-' ||
               lpad(nextval('public.sale_no_seq')::text,6,'0');

  insert into public.sales(user_id,sale_no,sale_date,customer_id,vehicle_id,payment_method,currency_code,note,total,profit)
  values(v_uid,v_sale_no,current_date,p_customer_id,p_vehicle_id,p_payment_method,p_currency_code,p_note,0,0)
  returning id into v_sale_id;

  for v_item in select value from jsonb_array_elements(p_items)
  loop
    v_qty := (v_item ->> 'qty')::integer;
    v_price := (v_item ->> 'unit_price')::numeric;
    if v_qty is null or v_qty <= 0 or v_price is null or v_price < 0 then
      raise exception 'จำนวนหรือราคาสินค้าไม่ถูกต้อง';
    end if;

    select * into v_product
      from public.products
      where id = (v_item ->> 'product_id')::uuid and user_id = v_uid
      for update;

    if not found then raise exception 'ไม่พบสินค้าในสต็อกของร้าน'; end if;
    if v_product.currency_code <> p_currency_code then
      raise exception 'สินค้า % ใช้สกุลเงิน %, กรุณาขายด้วยสกุลเงินเดียวกัน',
        v_product.name,v_product.currency_code;
    end if;
    if v_product.stock_qty < v_qty then
      raise exception 'สินค้า % มีไม่พอ (คงเหลือ %)',v_product.name,v_product.stock_qty;
    end if;

    v_line_total := v_qty * v_price;
    v_line_profit := v_qty * (v_price - v_product.cost_price);
    v_total := v_total + v_line_total;
    v_profit := v_profit + v_line_profit;

    insert into public.sale_items(user_id,sale_id,product_id,product_name,qty,unit_price,unit_cost,line_total,line_profit)
    values(v_uid,v_sale_id,v_product.id,v_product.name,v_qty,v_price,v_product.cost_price,v_line_total,v_line_profit);

    update public.products
      set stock_qty = stock_qty - v_qty
      where id = v_product.id and user_id = v_uid;
  end loop;

  update public.sales set total = v_total, profit = v_profit
    where id = v_sale_id and user_id = v_uid;

  return jsonb_build_object('sale_no',v_sale_no,'sale_id',v_sale_id,'total',v_total,'profit',v_profit);
end;
$$;

revoke all on function public.create_sale(uuid,uuid,text,text,jsonb,text) from public, anon;
grant execute on function public.create_sale(uuid,uuid,text,text,jsonb,text) to authenticated;
