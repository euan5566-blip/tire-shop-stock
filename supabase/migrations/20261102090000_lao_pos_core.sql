-- Lao tire shop POS: core additions for quotations, suppliers, purchases and sales RPC.
-- Existing product/customer/sale tables are retained to avoid losing any data.
alter table public.sales add column if not exists sale_date date not null default current_date;
alter table public.sales add column if not exists profit numeric not null default 0;
alter table public.sales add column if not exists paid_amount numeric not null default 0;
alter table public.sales add column if not exists balance_due numeric not null default 0;
alter table public.sales add column if not exists status text not null default 'paid';

create table if not exists public.suppliers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text,
  address text,
  note text,
  created_at timestamptz not null default now()
);
create sequence if not exists public.purchase_no_seq;
create table if not exists public.purchases (
  id uuid primary key default gen_random_uuid(),
  purchase_no text not null unique default ('P-' || lpad(nextval('public.purchase_no_seq')::text,6,'0')),
  supplier_id uuid references public.suppliers(id) on delete set null,
  purchase_date date not null default current_date,
  currency text not null default 'LAK',
  exchange_rate numeric not null default 1,
  subtotal numeric not null default 0,
  total numeric not null default 0,
  paid_amount numeric not null default 0,
  balance_due numeric not null default 0,
  note text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);
create table if not exists public.purchase_items (
  id uuid primary key default gen_random_uuid(),
  purchase_id uuid not null references public.purchases(id) on delete cascade,
  product_id uuid not null references public.products(id),
  qty integer not null check(qty > 0),
  unit_cost numeric not null default 0,
  line_total numeric not null default 0
);
create sequence if not exists public.quote_no_seq;
create table if not exists public.quotations (
  id uuid primary key default gen_random_uuid(),
  quote_no text not null unique default ('Q-' || lpad(nextval('public.quote_no_seq')::text,6,'0')),
  customer_id uuid references public.customers(id) on delete set null,
  vehicle_id uuid references public.vehicles(id) on delete set null,
  quote_date date not null default current_date,
  valid_until date,
  currency text not null default 'LAK',
  exchange_rate numeric not null default 1,
  subtotal numeric not null default 0,
  discount numeric not null default 0,
  total numeric not null default 0,
  status text not null default 'draft',
  note text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);
create table if not exists public.quotation_items (
  id uuid primary key default gen_random_uuid(),
  quotation_id uuid not null references public.quotations(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  product_name text not null,
  qty numeric not null default 1,
  unit_price numeric not null default 0,
  line_total numeric not null default 0
);
create table if not exists public.customer_payments (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales(id) on delete cascade,
  amount numeric not null check(amount > 0),
  payment_method text not null default 'ເງິນສົດ',
  note text,
  paid_at timestamptz not null default now(),
  received_by uuid references public.profiles(id)
);

alter table public.suppliers enable row level security;
alter table public.purchases enable row level security;
alter table public.purchase_items enable row level security;
alter table public.quotations enable row level security;
alter table public.quotation_items enable row level security;
alter table public.customer_payments enable row level security;

drop policy if exists suppliers_all_active on public.suppliers;
create policy suppliers_all_active on public.suppliers for all to authenticated using (public.is_active_user()) with check (public.is_active_user());
drop policy if exists purchases_all_active on public.purchases;
create policy purchases_all_active on public.purchases for all to authenticated using (public.is_active_user()) with check (public.is_active_user());
drop policy if exists purchase_items_all_active on public.purchase_items;
create policy purchase_items_all_active on public.purchase_items for all to authenticated using (public.is_active_user()) with check (public.is_active_user());
drop policy if exists quotations_all_active on public.quotations;
create policy quotations_all_active on public.quotations for all to authenticated using (public.is_active_user()) with check (public.is_active_user());
drop policy if exists quotation_items_all_active on public.quotation_items;
create policy quotation_items_all_active on public.quotation_items for all to authenticated using (public.is_active_user()) with check (public.is_active_user());
drop policy if exists customer_payments_all_active on public.customer_payments;
create policy customer_payments_all_active on public.customer_payments for all to authenticated using (public.is_active_user()) with check (public.is_active_user());

create or replace function public.create_shop_sale(
  p_customer_id uuid,
  p_vehicle_id uuid,
  p_payment_method text,
  p_currency text,
  p_exchange_rate numeric,
  p_discount numeric,
  p_paid_amount numeric,
  p_note text,
  p_items jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sale_id uuid;
  v_receipt_no text;
  v_subtotal numeric := 0;
  v_total numeric := 0;
  v_profit numeric := 0;
  v_paid numeric := greatest(coalesce(p_paid_amount,0),0);
  v_balance numeric := 0;
  v_item jsonb;
  v_product public.products%rowtype;
  v_qty integer;
  v_price numeric;
  v_cost numeric;
  v_line numeric;
begin
  if auth.uid() is null or not public.is_active_user() then
    raise exception 'ກະລຸນາເຂົ້າລະບົບ';
  end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'ກະລຸນາເລືອກສິນຄ້າ';
  end if;

  insert into public.sales(customer_id,vehicle_id,subtotal,discount,total,payment_method,sold_by,currency,exchange_rate,note,sale_date,paid_amount,balance_due,status,profit)
  values(p_customer_id,p_vehicle_id,0,0,0,coalesce(p_payment_method,'ເງິນສົດ'),auth.uid(),coalesce(p_currency,'LAK'),greatest(coalesce(p_exchange_rate,1),0.000001),coalesce(p_note,''),current_date,0,0,'paid',0)
  returning id,receipt_no into v_sale_id,v_receipt_no;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := greatest(coalesce((v_item->>'qty')::integer,0),0);
    if v_qty < 1 then raise exception 'ຈຳນວນສິນຄ້າບໍ່ຖືກຕ້ອງ'; end if;

    select * into v_product from public.products where id=(v_item->>'product_id')::uuid and active=true for update;
    if not found then raise exception 'ບໍ່ພົບສິນຄ້າ'; end if;
    if v_product.stock < v_qty then raise exception 'ສິນຄ້າ % ມີບໍ່ພໍ (ຄົງເຫຼືອ %)',v_product.name,v_product.stock; end if;

    if coalesce(p_currency,'LAK')='THB' then
      v_price := coalesce((v_item->>'unit_price')::numeric,v_product.price_thb,v_product.price);
      v_cost := coalesce(v_product.cost_thb,v_product.cost);
    else
      v_price := coalesce((v_item->>'unit_price')::numeric,v_product.price_lak,v_product.price);
      v_cost := coalesce(v_product.cost_lak,v_product.cost);
    end if;
    v_line := v_qty * v_price;
    v_subtotal := v_subtotal + v_line;
    v_profit := v_profit + v_qty * (v_price-v_cost);

    insert into public.sale_items(sale_id,product_id,qty,price,cost,line_total,quantity,total,unit_cost,unit_price)
    values(v_sale_id,v_product.id,v_qty,v_price,v_cost,v_line,v_qty,v_line,v_cost,v_price);

    update public.products set stock=stock-v_qty,updated_at=now() where id=v_product.id;
    insert into public.stock_movements(product_id,movement_type,qty,note,ref_id,created_by)
    values(v_product.id,'ຂາຍອອກ',v_qty,'ຂາຍເລກທີ '||v_receipt_no,v_sale_id,auth.uid());
  end loop;

  v_total := greatest(v_subtotal-greatest(coalesce(p_discount,0),0),0);
  v_balance := greatest(v_total-v_paid,0);
  update public.sales set subtotal=v_subtotal,discount=greatest(coalesce(p_discount,0),0),total=v_total,
    paid_amount=least(v_paid,v_total),balance_due=v_balance,
    status=case when v_balance=0 then 'paid' else 'credit' end,profit=v_profit
  where id=v_sale_id;

  return jsonb_build_object('id',v_sale_id,'receipt_no',v_receipt_no,'subtotal',v_subtotal,'total',v_total,'profit',v_profit,'balance_due',v_balance);
end;
$$;

grant execute on function public.create_shop_sale(uuid,uuid,text,text,numeric,numeric,numeric,text,jsonb) to authenticated;


create or replace function public.create_shop_purchase(
  p_supplier_id uuid,
  p_currency text,
  p_exchange_rate numeric,
  p_paid_amount numeric,
  p_note text,
  p_items jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_purchase_id uuid;
  v_purchase_no text;
  v_subtotal numeric := 0;
  v_total numeric := 0;
  v_paid numeric := greatest(coalesce(p_paid_amount,0),0);
  v_item jsonb;
  v_product public.products%rowtype;
  v_qty integer;
  v_unit_cost numeric;
  v_line numeric;
begin
  if auth.uid() is null or not public.is_active_user() then
    raise exception 'ກະລຸນາເຂົ້າລະບົບ';
  end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items)=0 then
    raise exception 'ກະລຸນາເພີ່ມລາຍການສິນຄ້າ';
  end if;
  insert into public.purchases(supplier_id,currency,exchange_rate,subtotal,total,paid_amount,balance_due,note,created_by)
  values(p_supplier_id,coalesce(p_currency,'LAK'),greatest(coalesce(p_exchange_rate,1),0.000001),0,0,0,0,coalesce(p_note,''),auth.uid())
  returning id,purchase_no into v_purchase_id,v_purchase_no;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := greatest(coalesce((v_item->>'qty')::integer,0),0);
    if v_qty<1 then raise exception 'ຈຳນວນຮັບເຂົ້າບໍ່ຖືກຕ້ອງ'; end if;
    select * into v_product from public.products where id=(v_item->>'product_id')::uuid and active=true for update;
    if not found then raise exception 'ບໍ່ພົບສິນຄ້າ'; end if;
    v_unit_cost:=greatest(coalesce((v_item->>'unit_cost')::numeric,0),0);
    v_line:=v_qty*v_unit_cost;
    v_subtotal:=v_subtotal+v_line;
    insert into public.purchase_items(purchase_id,product_id,qty,unit_cost,line_total)
    values(v_purchase_id,v_product.id,v_qty,v_unit_cost,v_line);
    update public.products set stock=stock+v_qty,
      cost=case when coalesce(p_currency,'LAK')='THB' then cost else v_unit_cost end,
      cost_lak=case when coalesce(p_currency,'LAK')='LAK' then v_unit_cost else cost_lak end,
      cost_thb=case when coalesce(p_currency,'LAK')='THB' then v_unit_cost else cost_thb end,
      updated_at=now()
    where id=v_product.id;
    insert into public.stock_movements(product_id,movement_type,qty,note,ref_id,created_by)
    values(v_product.id,'ຮັບເຂົ້າ',v_qty,'ຮັບສິນຄ້າເລກທີ '||v_purchase_no,v_purchase_id,auth.uid());
  end loop;

  v_total:=v_subtotal;
  update public.purchases set subtotal=v_subtotal,total=v_total,paid_amount=least(v_paid,v_total),balance_due=greatest(v_total-v_paid,0)
  where id=v_purchase_id;
  return jsonb_build_object('id',v_purchase_id,'purchase_no',v_purchase_no,'total',v_total,'balance_due',greatest(v_total-v_paid,0));
end;
$$;
grant execute on function public.create_shop_purchase(uuid,text,numeric,numeric,text,jsonb) to authenticated;
