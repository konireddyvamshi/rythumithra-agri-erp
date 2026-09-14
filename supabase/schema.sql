-- Saraswathi Agri Mall inventory/billing schema
-- Run this in the Supabase SQL editor after creating a project.
-- The frontend can use only the publishable key; NEVER put service_role in Vite env.

create extension if not exists pgcrypto;

do $$ begin
  create type public.invoice_status as enum ('POSTED','CANCELLED');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.movement_type as enum ('PURCHASE','SALE','SALES_RETURN','CANCELLATION','DAMAGE','ADJUSTMENT');
exception when duplicate_object then null; end $$;

create table if not exists public.business_settings (
  id uuid primary key default gen_random_uuid(),
  business_name text not null default 'RYTHUMITHRA FERTILIZERS, PESTICIDES & SEEDS',
  gstin text,
  state text default 'Telangana',
  state_code text default '36',
  address text,
  phone text,
  updated_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  hsn_code text not null,
  unit text not null default 'Bottle',
  pack_size text not null default '',
  reorder_level numeric not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create index if not exists products_name_idx on public.products(lower(name));
create index if not exists products_hsn_idx on public.products(hsn_code);

create table if not exists public.product_batches (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id),
  batch_number text not null,
  manufacturing_date date,
  expiry_date date,
  cost_price numeric(14,2) not null default 0,
  mrp numeric(14,2) not null default 0,
  selling_price numeric(14,2) not null default 0,
  cgst_rate numeric(6,2) not null default 0,
  sgst_rate numeric(6,2) not null default 0,
  igst_rate numeric(6,2) not null default 0,
  gst_rate numeric(6,2) not null default 0,
  current_quantity numeric(14,3) not null default 0,
  purchased_quantity numeric(14,3) not null default 0,
  created_at timestamptz not null default now(),
  unique(product_id,batch_number)
);
create index if not exists batches_expiry_idx on public.product_batches(expiry_date);
create index if not exists batches_product_idx on public.product_batches(product_id);

create table if not exists public.suppliers (
  id uuid primary key default gen_random_uuid(), name text not null, gstin text, phone text, address text, state text, state_code text
);
create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(), name text not null, mobile text, address text, gstin text, state text, state_code text
);

create table if not exists public.purchase_invoices (
  id uuid primary key default gen_random_uuid(), invoice_number text not null unique, invoice_date date not null, supplier_id uuid references public.suppliers(id), supplier_name text not null, supplier_gstin text, delivery_note_number text, buyer_order_number text, remarks text, taxable_amount numeric(14,2) not null default 0, cgst_amount numeric(14,2) not null default 0, sgst_amount numeric(14,2) not null default 0, igst_amount numeric(14,2) not null default 0, total_amount numeric(14,2) not null default 0, created_at timestamptz not null default now()
);
create table if not exists public.purchase_items (
  id uuid primary key default gen_random_uuid(), purchase_id uuid not null references public.purchase_invoices(id) on delete cascade, product_id uuid not null references public.products(id), batch_id uuid not null references public.product_batches(id), quantity numeric(14,3) not null, cost_price numeric(14,2) not null, mrp numeric(14,2) not null, selling_price numeric(14,2) not null, gst_rate numeric(6,2) not null default 0, taxable_amount numeric(14,2) not null default 0
);

create table if not exists public.sales_invoices (
  id uuid primary key default gen_random_uuid(), invoice_number text not null unique, invoice_date date not null, customer_id uuid references public.customers(id), customer_name text not null, customer_mobile text, customer_gstin text, customer_state text, customer_state_code text, payment_mode text not null default 'Cash', status public.invoice_status not null default 'POSTED', taxable_amount numeric(14,2) not null default 0, cgst_amount numeric(14,2) not null default 0, sgst_amount numeric(14,2) not null default 0, igst_amount numeric(14,2) not null default 0, discount_amount numeric(14,2) not null default 0, total_amount numeric(14,2) not null default 0, created_at timestamptz not null default now()
);
create table if not exists public.sales_items (
  id uuid primary key default gen_random_uuid(), sales_invoice_id uuid not null references public.sales_invoices(id) on delete cascade, product_id uuid not null references public.products(id), batch_id uuid not null references public.product_batches(id), quantity numeric(14,3) not null, mrp numeric(14,2) not null, selling_price numeric(14,2) not null, gst_rate numeric(6,2) not null default 0, taxable_amount numeric(14,2) not null default 0
);

create table if not exists public.inventory_movements (
  id uuid primary key default gen_random_uuid(), product_id uuid not null references public.products(id), batch_id uuid not null references public.product_batches(id), type public.movement_type not null, quantity numeric(14,3) not null, reference_id uuid, reference_number text, reason text, notes text, created_at timestamptz not null default now()
);
create index if not exists movement_batch_idx on public.inventory_movements(batch_id, created_at);

-- Atomic sale posting: prevents two devices from selling the same stock.
create or replace function public.post_sale_item(p_batch_id uuid, p_quantity numeric)
returns boolean language plpgsql security definer set search_path = public as $$
declare updated_count integer;
begin
  update public.product_batches
     set current_quantity = current_quantity - p_quantity
   where id = p_batch_id and current_quantity >= p_quantity;
  get diagnostics updated_count = row_count;
  return updated_count = 1;
end;
$$;
revoke all on function public.post_sale_item(uuid,numeric) from public;
grant execute on function public.post_sale_item(uuid,numeric) to authenticated;

alter table public.business_settings enable row level security;
alter table public.products enable row level security;
alter table public.product_batches enable row level security;
alter table public.suppliers enable row level security;
alter table public.customers enable row level security;
alter table public.purchase_invoices enable row level security;
alter table public.purchase_items enable row level security;
alter table public.sales_invoices enable row level security;
alter table public.sales_items enable row level security;
alter table public.inventory_movements enable row level security;

-- V1: authenticated staff share one business workspace. Tighten with a business_id
-- and membership table if you later operate multiple shops from one Supabase project.
do $$
begin
  create policy "authenticated access" on public.business_settings for all to authenticated using (true) with check (true);
  create policy "authenticated access" on public.products for all to authenticated using (true) with check (true);
  create policy "authenticated access" on public.product_batches for all to authenticated using (true) with check (true);
  create policy "authenticated access" on public.suppliers for all to authenticated using (true) with check (true);
  create policy "authenticated access" on public.customers for all to authenticated using (true) with check (true);
  create policy "authenticated access" on public.purchase_invoices for all to authenticated using (true) with check (true);
  create policy "authenticated access" on public.purchase_items for all to authenticated using (true) with check (true);
  create policy "authenticated access" on public.sales_invoices for all to authenticated using (true) with check (true);
  create policy "authenticated access" on public.sales_items for all to authenticated using (true) with check (true);
  create policy "authenticated access" on public.inventory_movements for all to authenticated using (true) with check (true);
exception when duplicate_object then null;
end $$;

-- Enable Realtime for inventory-facing tables.
alter publication supabase_realtime add table public.products;
alter publication supabase_realtime add table public.product_batches;
alter publication supabase_realtime add table public.sales_invoices;
alter publication supabase_realtime add table public.purchase_invoices;
alter publication supabase_realtime add table public.inventory_movements;

create table if not exists public.sales_returns (
  id uuid primary key default gen_random_uuid(), return_number text not null unique, sales_invoice_id uuid not null references public.sales_invoices(id), return_date date not null, reason text not null, total_amount numeric(14,2) not null default 0, created_at timestamptz not null default now()
);
create table if not exists public.sales_return_items (
  id uuid primary key default gen_random_uuid(), return_id uuid not null references public.sales_returns(id) on delete cascade, sales_invoice_id uuid not null references public.sales_invoices(id), product_id uuid not null references public.products(id), batch_id uuid not null references public.product_batches(id), quantity numeric(14,3) not null, amount numeric(14,2) not null default 0
);
alter table public.sales_returns enable row level security;
alter table public.sales_return_items enable row level security;
do $$ begin
 create policy "authenticated access" on public.sales_returns for all to authenticated using (true) with check (true);
 create policy "authenticated access" on public.sales_return_items for all to authenticated using (true) with check (true);
exception when duplicate_object then null; end $$;
