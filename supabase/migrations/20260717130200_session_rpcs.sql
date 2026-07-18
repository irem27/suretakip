-- =============================================================
-- SüreTakip - Migration 3/3: Transaction-safe seans RPC'leri
-- Her fonksiyon tek transaction'dır: içindeki adımların ya hepsi olur
-- ya hiçbiri. security definer + explicit üyelik/yetki kontrolü.
-- Hata mesajları makine-okur kod formatındadır (uygulama Türkçeleştirir).
-- =============================================================

-- ---------- start_session ----------
create function public.start_session(
  p_business_id uuid,
  p_service_id uuid,
  p_customer_id uuid default null,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_member_id uuid;
  v_service public.services%rowtype;
  v_session_id uuid;
begin
  v_member_id := public.active_member_id(p_business_id);
  if v_member_id is null then
    raise exception 'not_a_member';
  end if;

  if not exists (
    select 1 from public.businesses
    where id = p_business_id and is_active and archived_at is null
  ) then
    raise exception 'business_not_active';
  end if;

  select * into v_service
  from public.services
  where id = p_service_id
    and business_id = p_business_id
    and is_active
    and archived_at is null;
  if not found then
    raise exception 'service_not_available';
  end if;

  if p_customer_id is not null and not exists (
    select 1 from public.customers
    where id = p_customer_id and business_id = p_business_id and is_active
  ) then
    raise exception 'customer_not_found';
  end if;

  insert into public.sessions (
    business_id, customer_id, service_id, opened_by_member_id,
    status, started_at, notes,
    service_name_snapshot, price_per_minute_minor_snapshot,
    rounding_interval_minutes_snapshot, minimum_charge_minutes_snapshot,
    currency_code_snapshot
  )
  values (
    p_business_id, p_customer_id, p_service_id, v_member_id,
    'active', now(), p_notes,
    v_service.name, v_service.price_per_minute_minor,
    v_service.rounding_interval_minutes, v_service.minimum_charge_minutes,
    v_service.currency_code
  )
  returning id into v_session_id;

  insert into public.session_time_entries (business_id, session_id, entry_type, started_at)
  values (p_business_id, v_session_id, 'active', now());

  return v_session_id;
end;
$$;

-- ---------- pause_session ----------
create function public.pause_session(p_session_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session public.sessions%rowtype;
begin
  -- for update: aynı seansta eşzamanlı iki durum değişikliği sıraya girer.
  select * into v_session
  from public.sessions
  where id = p_session_id
  for update;
  if not found then
    raise exception 'session_not_found';
  end if;

  if public.active_member_id(v_session.business_id) is null then
    raise exception 'not_a_member';
  end if;

  -- Sadece aktif seans duraklatılabilir: ikinci pause burada patlar.
  if v_session.status <> 'active' then
    raise exception 'session_not_active';
  end if;

  update public.session_time_entries
     set ended_at = now()
   where session_id = p_session_id and ended_at is null;

  insert into public.session_time_entries (business_id, session_id, entry_type, started_at)
  values (v_session.business_id, p_session_id, 'paused', now());

  update public.sessions set status = 'paused' where id = p_session_id;

  return p_session_id;
end;
$$;

-- ---------- resume_session ----------
create function public.resume_session(p_session_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session public.sessions%rowtype;
begin
  select * into v_session
  from public.sessions
  where id = p_session_id
  for update;
  if not found then
    raise exception 'session_not_found';
  end if;

  if public.active_member_id(v_session.business_id) is null then
    raise exception 'not_a_member';
  end if;

  if v_session.status <> 'paused' then
    raise exception 'session_not_paused';
  end if;

  update public.session_time_entries
     set ended_at = now()
   where session_id = p_session_id and ended_at is null;

  insert into public.session_time_entries (business_id, session_id, entry_type, started_at)
  values (v_session.business_id, p_session_id, 'active', now());

  update public.sessions set status = 'active' where id = p_session_id;

  return p_session_id;
end;
$$;

-- ---------- add_product_to_session ----------
create function public.add_product_to_session(
  p_session_id uuid,
  p_product_id uuid,
  p_quantity bigint,
  p_discount_minor bigint default 0,
  p_tax_minor bigint default 0
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session public.sessions%rowtype;
  v_product public.products%rowtype;
  v_member_id uuid;
  v_line_total bigint;
  v_item_id uuid;
begin
  if p_quantity is null or p_quantity <= 0 then
    raise exception 'invalid_quantity';
  end if;
  if coalesce(p_discount_minor, -1) < 0 or coalesce(p_tax_minor, -1) < 0 then
    raise exception 'invalid_amount';
  end if;

  select * into v_session
  from public.sessions
  where id = p_session_id
  for update;
  if not found then
    raise exception 'session_not_found';
  end if;

  v_member_id := public.active_member_id(v_session.business_id);
  if v_member_id is null then
    raise exception 'not_a_member';
  end if;

  if v_session.status not in ('active', 'paused') then
    raise exception 'session_not_open';
  end if;

  -- for update: eşzamanlı satışlarda stok kontrolü + düşümü yarışamaz.
  select * into v_product
  from public.products
  where id = p_product_id and business_id = v_session.business_id
  for update;
  if not found or not v_product.is_active or v_product.archived_at is not null then
    raise exception 'product_not_available';
  end if;

  if v_product.currency_code <> v_session.currency_code_snapshot then
    raise exception 'currency_mismatch';
  end if;

  if v_product.track_stock and v_product.stock_quantity < p_quantity then
    raise exception 'insufficient_stock';
  end if;

  v_line_total := v_product.unit_price_minor * p_quantity - p_discount_minor + p_tax_minor;
  if v_line_total < 0 then
    raise exception 'invalid_discount';
  end if;

  insert into public.session_items (
    business_id, session_id, product_id,
    product_name_snapshot, sku_snapshot,
    unit_price_minor_snapshot, currency_code_snapshot,
    quantity, discount_minor, tax_minor, line_total_minor
  )
  values (
    v_session.business_id, p_session_id, p_product_id,
    v_product.name, v_product.sku,
    v_product.unit_price_minor, v_product.currency_code,
    p_quantity, p_discount_minor, p_tax_minor, v_line_total
  )
  returning id into v_item_id;

  -- Ledger kaydı yalnızca stok takipli ürünlerde; cache'i trigger günceller.
  if v_product.track_stock then
    insert into public.inventory_movements (
      business_id, product_id, session_item_id,
      movement_type, quantity_delta, created_by_member_id
    )
    values (
      v_session.business_id, p_product_id, v_item_id,
      'sale', -p_quantity, v_member_id
    );
  end if;

  return v_item_id;
end;
$$;

-- ---------- complete_session ----------
create function public.complete_session(
  p_session_id uuid,
  p_discount_minor bigint default 0,
  p_tax_minor bigint default 0
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session public.sessions%rowtype;
  v_member_id uuid;
  v_active_seconds numeric;
  v_charged_minutes integer;
  v_service_subtotal bigint;
  v_products_subtotal bigint;
  v_grand_total bigint;
begin
  if coalesce(p_discount_minor, -1) < 0 or coalesce(p_tax_minor, -1) < 0 then
    raise exception 'invalid_amount';
  end if;

  -- for update kilidi + status kontrolü = aynı seans iki kez tamamlanamaz.
  select * into v_session
  from public.sessions
  where id = p_session_id
  for update;
  if not found then
    raise exception 'session_not_found';
  end if;

  v_member_id := public.active_member_id(v_session.business_id);
  if v_member_id is null then
    raise exception 'not_a_member';
  end if;

  if v_session.status not in ('active', 'paused') then
    raise exception 'session_not_open';
  end if;

  update public.session_time_entries
     set ended_at = now()
   where session_id = p_session_id and ended_at is null;

  -- Gerçek aktif süre ledger'dan hesaplanır (client saatine güvenilmez).
  select coalesce(sum(extract(epoch from (ended_at - started_at))), 0)
    into v_active_seconds
  from public.session_time_entries
  where session_id = p_session_id and entry_type = 'active';

  -- Ücretlendirme: aralığa YUKARI yuvarla, sonra minimumu uygula.
  v_charged_minutes := greatest(
    (ceil((v_active_seconds / 60.0) / v_session.rounding_interval_minutes_snapshot)
       * v_session.rounding_interval_minutes_snapshot)::integer,
    v_session.minimum_charge_minutes_snapshot
  );

  v_service_subtotal := v_charged_minutes::bigint * v_session.price_per_minute_minor_snapshot;

  select coalesce(sum(line_total_minor), 0)
    into v_products_subtotal
  from public.session_items
  where session_id = p_session_id;

  v_grand_total := v_service_subtotal + v_products_subtotal - p_discount_minor + p_tax_minor;
  if v_grand_total < 0 then
    raise exception 'invalid_discount';
  end if;

  update public.sessions
     set status = 'completed',
         ended_at = now(),
         closed_by_member_id = v_member_id,
         charged_minutes = v_charged_minutes,
         service_subtotal_minor = v_service_subtotal,
         products_subtotal_minor = v_products_subtotal,
         discount_minor = p_discount_minor,
         tax_minor = p_tax_minor,
         grand_total_minor = v_grand_total
   where id = p_session_id;

  return p_session_id;
end;
$$;

-- ---------- cancel_session ----------
create function public.cancel_session(p_session_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session public.sessions%rowtype;
  v_member_id uuid;
begin
  select * into v_session
  from public.sessions
  where id = p_session_id
  for update;
  if not found then
    raise exception 'session_not_found';
  end if;

  v_member_id := public.active_member_id(v_session.business_id);
  if v_member_id is null then
    raise exception 'not_a_member';
  end if;

  if v_session.status = 'cancelled' then
    raise exception 'session_already_cancelled';
  end if;

  -- Tamamlanmış seansı yalnızca owner/admin iptal edebilir (finansal kayıt).
  if v_session.status = 'completed'
     and not public.has_business_role(
       v_session.business_id, array['owner','admin']::public.member_role[]
     ) then
    raise exception 'not_authorized';
  end if;

  update public.session_time_entries
     set ended_at = now()
   where session_id = p_session_id and ended_at is null;

  -- Stok iadesi: satır başına en fazla BİR sale_reversal.
  -- uq_inventory_item_movement + on conflict = çifte iade imkansız.
  insert into public.inventory_movements (
    business_id, product_id, session_item_id,
    movement_type, quantity_delta, created_by_member_id
  )
  select si.business_id, si.product_id, si.id,
         'sale_reversal', si.quantity, v_member_id
  from public.session_items si
  join public.products p on p.id = si.product_id
  where si.session_id = p_session_id
    and p.track_stock
    and exists (
      select 1 from public.inventory_movements im
      where im.session_item_id = si.id and im.movement_type = 'sale'
    )
  on conflict (session_item_id, movement_type) where session_item_id is not null
  do nothing;

  update public.sessions
     set status = 'cancelled',
         ended_at = coalesce(v_session.ended_at, now()),
         closed_by_member_id = v_member_id
   where id = p_session_id;

  return p_session_id;
end;
$$;

-- ---------- Yetkiler ----------
revoke execute on function public.start_session(uuid, uuid, uuid, text) from public, anon;
revoke execute on function public.pause_session(uuid) from public, anon;
revoke execute on function public.resume_session(uuid) from public, anon;
revoke execute on function public.add_product_to_session(uuid, uuid, bigint, bigint, bigint) from public, anon;
revoke execute on function public.complete_session(uuid, bigint, bigint) from public, anon;
revoke execute on function public.cancel_session(uuid) from public, anon;

grant execute on function public.start_session(uuid, uuid, uuid, text) to authenticated;
grant execute on function public.pause_session(uuid) to authenticated;
grant execute on function public.resume_session(uuid) to authenticated;
grant execute on function public.add_product_to_session(uuid, uuid, bigint, bigint, bigint) to authenticated;
grant execute on function public.complete_session(uuid, bigint, bigint) to authenticated;
grant execute on function public.cancel_session(uuid) to authenticated;
