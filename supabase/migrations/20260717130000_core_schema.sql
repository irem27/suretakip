-- =============================================================
-- SüreTakip - Migration 1/3: Çekirdek Şema
-- Para modeli: en küçük birim (kuruş) bigint + ISO 4217 currency_code.
-- Silme modeli: fiziksel silme yok; is_active + archived_at.
-- Zaman modeli: session_time_entries ledger'ı (denetlenebilir).
-- Stok modeli: inventory_movements ledger'ı + products.stock_quantity cache.
-- =============================================================

-- ---------- Enum'lar ----------
create type public.member_role as enum ('owner', 'admin', 'staff');
create type public.session_status as enum ('draft', 'active', 'paused', 'completed', 'cancelled');
create type public.time_entry_type as enum ('active', 'paused');
create type public.inventory_movement_type as enum
  ('initial', 'sale', 'sale_reversal', 'manual_adjustment', 'restock');

-- ---------- Ortak updated_at trigger fonksiyonu ----------
create function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------- businesses ----------
create table public.businesses (
  id            uuid primary key default gen_random_uuid(),
  name          text not null check (char_length(trim(name)) between 1 and 120),
  currency_code text not null default 'TRY' check (currency_code ~ '^[A-Z]{3}$'),
  timezone      text not null default 'Europe/Istanbul',
  is_active     boolean not null default true,
  archived_at   timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create trigger trg_businesses_updated_at
  before update on public.businesses
  for each row execute function public.set_updated_at();

-- ---------- business_members ----------
create table public.business_members (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  user_id     uuid not null references auth.users(id) on delete restrict,
  role        public.member_role not null default 'staff',
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (business_id, user_id),
  -- Composite FK hedefi: çocuk tablolar (member_id, business_id) çiftiyle
  -- bağlanır; böylece "başka işletmenin personeli" DB seviyesinde imkansız olur.
  unique (id, business_id)
);

create index idx_business_members_user_id on public.business_members (user_id);

create trigger trg_business_members_updated_at
  before update on public.business_members
  for each row execute function public.set_updated_at();

-- ---------- customers ----------
create table public.customers (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  name        text not null check (char_length(trim(name)) between 1 and 120),
  phone       text,
  email       text,
  notes       text,
  is_active   boolean not null default true,
  archived_at timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (id, business_id)
);

create index idx_customers_business_active on public.customers (business_id, is_active);

create trigger trg_customers_updated_at
  before update on public.customers
  for each row execute function public.set_updated_at();

-- ---------- services ----------
create table public.services (
  id                        uuid primary key default gen_random_uuid(),
  business_id               uuid not null references public.businesses(id) on delete restrict,
  name                      text not null check (char_length(trim(name)) between 1 and 120),
  price_per_minute_minor    bigint not null check (price_per_minute_minor >= 0),
  rounding_interval_minutes integer not null default 1 check (rounding_interval_minutes > 0),
  minimum_charge_minutes    integer not null default 0 check (minimum_charge_minutes >= 0),
  currency_code             text not null check (currency_code ~ '^[A-Z]{3}$'),
  is_active                 boolean not null default true,
  archived_at               timestamptz,
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now(),
  unique (id, business_id)
);

create index idx_services_business_active on public.services (business_id, is_active);

create trigger trg_services_updated_at
  before update on public.services
  for each row execute function public.set_updated_at();

-- ---------- products ----------
create table public.products (
  id               uuid primary key default gen_random_uuid(),
  business_id      uuid not null references public.businesses(id) on delete restrict,
  name             text not null check (char_length(trim(name)) between 1 and 120),
  sku              text,
  unit_price_minor bigint not null check (unit_price_minor >= 0),
  currency_code    text not null check (currency_code ~ '^[A-Z]{3}$'),
  track_stock      boolean not null default false,
  -- Cache alanı; gerçek kaynak inventory_movements ledger'ıdır.
  -- check (>= 0): eşzamanlı satışlarda stok negatife DÜŞEMEZ (DB garantisi).
  stock_quantity   bigint not null default 0 check (stock_quantity >= 0),
  is_active        boolean not null default true,
  archived_at      timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (id, business_id)
);

create index idx_products_business_active on public.products (business_id, is_active);
-- SKU işletme içinde benzersiz; sku boş bırakılabildiği için partial index.
create unique index uq_products_business_sku
  on public.products (business_id, sku) where sku is not null;

create trigger trg_products_updated_at
  before update on public.products
  for each row execute function public.set_updated_at();

-- ---------- sessions ----------
-- Tüm fiyatlandırma kuralları snapshot: hizmet/işletme/para birimi sonradan
-- değişse bile geçmiş seanslar asla etkilenmez.
-- Composite FK'ler (x_id, business_id): müşteri/hizmet/personelin seansla
-- AYNI işletmeye ait olduğunu DB seviyesinde garanti eder.
create table public.sessions (
  id                        uuid primary key default gen_random_uuid(),
  business_id               uuid not null references public.businesses(id) on delete restrict,
  customer_id               uuid,
  service_id                uuid not null,
  opened_by_member_id       uuid not null,
  closed_by_member_id       uuid,
  status                    public.session_status not null default 'active',
  started_at                timestamptz not null default now(),
  ended_at                  timestamptz,
  charged_minutes           integer check (charged_minutes >= 0),

  service_name_snapshot              text not null,
  price_per_minute_minor_snapshot    bigint not null check (price_per_minute_minor_snapshot >= 0),
  rounding_interval_minutes_snapshot integer not null check (rounding_interval_minutes_snapshot > 0),
  minimum_charge_minutes_snapshot    integer not null check (minimum_charge_minutes_snapshot >= 0),
  currency_code_snapshot             text not null check (currency_code_snapshot ~ '^[A-Z]{3}$'),

  service_subtotal_minor    bigint check (service_subtotal_minor >= 0),
  products_subtotal_minor   bigint check (products_subtotal_minor >= 0),
  discount_minor            bigint not null default 0 check (discount_minor >= 0),
  tax_minor                 bigint not null default 0 check (tax_minor >= 0),
  grand_total_minor         bigint check (grand_total_minor >= 0),

  notes                     text,
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now(),

  unique (id, business_id),
  foreign key (customer_id, business_id)
    references public.customers (id, business_id) on delete restrict,
  foreign key (service_id, business_id)
    references public.services (id, business_id) on delete restrict,
  foreign key (opened_by_member_id, business_id)
    references public.business_members (id, business_id) on delete restrict,
  foreign key (closed_by_member_id, business_id)
    references public.business_members (id, business_id) on delete restrict,

  constraint chk_ended_after_start check (ended_at is null or ended_at >= started_at),
  -- Yarım "completed" kaydı imkansız: tamamlanan seansın tüm finansal
  -- alanları ve kapatan personeli dolu olmak zorunda.
  constraint chk_completed_fields check (
    status <> 'completed'
    or (ended_at is not null
        and charged_minutes is not null
        and service_subtotal_minor is not null
        and products_subtotal_minor is not null
        and grand_total_minor is not null
        and closed_by_member_id is not null)
  )
);

create index idx_sessions_business_status  on public.sessions (business_id, status);
create index idx_sessions_business_started on public.sessions (business_id, started_at desc);
create index idx_sessions_business_customer on public.sessions (business_id, customer_id);
create index idx_sessions_service on public.sessions (service_id);

create trigger trg_sessions_updated_at
  before update on public.sessions
  for each row execute function public.set_updated_at();

-- ---------- session_time_entries ----------
-- Seansın zaman çizelgesi (denetlenebilir): her aktif/duraklatılmış aralık
-- ayrı satır. Açık aralık = ended_at IS NULL.
create table public.session_time_entries (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null,
  session_id  uuid not null,
  entry_type  public.time_entry_type not null,
  started_at  timestamptz not null default now(),
  ended_at    timestamptz,
  created_at  timestamptz not null default now(),
  foreign key (session_id, business_id)
    references public.sessions (id, business_id) on delete restrict,
  constraint chk_entry_ended_after_start check (ended_at is null or ended_at >= started_at)
);

-- Aynı seansta aynı anda birden fazla açık aralık OLAMAZ.
create unique index uq_time_entries_one_open
  on public.session_time_entries (session_id) where ended_at is null;

create index idx_time_entries_session on public.session_time_entries (session_id, started_at);

-- ---------- session_items ----------
-- Bilinçli karar: UNIQUE(session_id, product_id) YOK. Aynı ürün farklı
-- fiyat/indirimle ayrı satırlarda tekrar satılabilir (spec varsayılanı).
create table public.session_items (
  id                       uuid primary key default gen_random_uuid(),
  business_id              uuid not null,
  session_id               uuid not null,
  product_id               uuid,
  product_name_snapshot    text not null,
  sku_snapshot             text,
  unit_price_minor_snapshot bigint not null check (unit_price_minor_snapshot >= 0),
  currency_code_snapshot   text not null check (currency_code_snapshot ~ '^[A-Z]{3}$'),
  quantity                 bigint not null check (quantity > 0),
  discount_minor           bigint not null default 0 check (discount_minor >= 0),
  tax_minor                bigint not null default 0 check (tax_minor >= 0),
  line_total_minor         bigint not null check (line_total_minor >= 0),
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now(),
  unique (id, business_id),
  foreign key (session_id, business_id)
    references public.sessions (id, business_id) on delete restrict,
  foreign key (product_id, business_id)
    references public.products (id, business_id) on delete restrict
);

create index idx_session_items_session on public.session_items (session_id);
create index idx_session_items_product on public.session_items (product_id);

create trigger trg_session_items_updated_at
  before update on public.session_items
  for each row execute function public.set_updated_at();

-- ---------- inventory_movements ----------
-- Append-only stok ledger'ı. UPDATE/DELETE yetkisi hiçbir role verilmez.
create table public.inventory_movements (
  id                   uuid primary key default gen_random_uuid(),
  business_id          uuid not null,
  product_id           uuid not null,
  session_item_id      uuid,
  movement_type        public.inventory_movement_type not null,
  quantity_delta       bigint not null check (quantity_delta <> 0),
  note                 text,
  created_by_member_id uuid,
  created_at           timestamptz not null default now(),
  foreign key (product_id, business_id)
    references public.products (id, business_id) on delete restrict,
  foreign key (session_item_id, business_id)
    references public.session_items (id, business_id) on delete restrict,
  foreign key (created_by_member_id, business_id)
    references public.business_members (id, business_id) on delete restrict,
  -- İşaret kuralları: satış eksi, giriş artı yazar.
  constraint chk_movement_sign check (
    (movement_type = 'sale' and quantity_delta < 0)
    or (movement_type in ('initial', 'sale_reversal', 'restock') and quantity_delta > 0)
    or (movement_type = 'manual_adjustment')
  )
);

-- Aynı satış satırı stoktan İKİ KEZ düşülemez / iade edilemez:
-- satır başına her hareket tipinden en fazla bir kayıt.
create unique index uq_inventory_item_movement
  on public.inventory_movements (session_item_id, movement_type)
  where session_item_id is not null;

create index idx_inventory_product_created  on public.inventory_movements (product_id, created_at);
create index idx_inventory_business_created on public.inventory_movements (business_id, created_at);

-- ---------- Stok cache trigger'ı ----------
-- Karar: stock_quantity "transaction içinde güncellenen cache" (seçenek 2).
-- Neden: liste/stok kontrolü sorguları her seferinde ledger SUM'ı yerine
-- tek kolon okur (production performansı). Tutarlılık garantisi: cache'e
-- YALNIZCA bu trigger yazar; her ledger insert'i aynı transaction'da
-- cache'i günceller. check (stock_quantity >= 0) da negatif stoğu
-- eşzamanlılık altında dahi imkansız kılar.
create function public.apply_inventory_movement()
returns trigger
language plpgsql
as $$
begin
  update public.products
     set stock_quantity = stock_quantity + new.quantity_delta
   where id = new.product_id
     and track_stock = true;
  return new;
end;
$$;

create trigger trg_apply_inventory_movement
  after insert on public.inventory_movements
  for each row execute function public.apply_inventory_movement();
