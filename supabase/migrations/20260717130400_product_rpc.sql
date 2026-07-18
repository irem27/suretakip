-- =============================================================
-- SüreTakip - Migration 5: Ürün oluşturma RPC'si (stok ledger uyumlu)
-- Ürünü ve varsa İLK STOĞU tek transaction'da oluşturur. İlk stok,
-- products.stock_quantity kolonuna DOĞRUDAN yazılmaz; bir 'initial'
-- inventory_movements kaydı olarak eklenir ve cache'i trigger günceller.
-- Böylece ledger (kaynak) ile cache asla ayrışmaz.
-- =============================================================

create function public.create_product_with_stock(
  p_business_id uuid,
  p_name text,
  p_sku text,
  p_unit_price_minor bigint,
  p_currency_code text,
  p_track_stock boolean,
  p_initial_stock bigint default 0
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_member_id uuid;
  v_product_id uuid;
begin
  -- Yetki: ürün kataloğunu yalnızca owner/admin yönetir (products RLS ile aynı).
  if not public.has_business_role(
       p_business_id, array['owner','admin']::public.member_role[]
     ) then
    raise exception 'not_authorized';
  end if;
  if p_name is null or char_length(trim(p_name)) = 0 then
    raise exception 'product_name_required';
  end if;

  insert into public.products (
    business_id, name, sku, unit_price_minor, currency_code, track_stock
  )
  values (
    p_business_id, trim(p_name), p_sku, p_unit_price_minor,
    coalesce(p_currency_code, 'TRY'), coalesce(p_track_stock, false)
  )
  returning id into v_product_id;

  -- İlk stok yalnızca stok takipli ürünlerde ve pozitifse ledger'a yazılır.
  if coalesce(p_track_stock, false) and coalesce(p_initial_stock, 0) > 0 then
    v_member_id := public.active_member_id(p_business_id);
    insert into public.inventory_movements (
      business_id, product_id, movement_type, quantity_delta,
      note, created_by_member_id
    )
    values (
      p_business_id, v_product_id, 'initial', p_initial_stock,
      'İlk stok', v_member_id
    );
  end if;

  return v_product_id;
end;
$$;

revoke execute on function public.create_product_with_stock(
  uuid, text, text, bigint, text, boolean, bigint
) from public, anon;
grant execute on function public.create_product_with_stock(
  uuid, text, text, bigint, text, boolean, bigint
) to authenticated;
