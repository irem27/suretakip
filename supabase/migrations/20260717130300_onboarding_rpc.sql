-- =============================================================
-- SüreTakip - Migration 4/4: Atomik onboarding RPC
-- İşletme + owner üyeliği + ZORUNLU ilk hizmet + opsiyonel ilk ürün
-- TEK transaction'da oluşturulur. Herhangi bir adım başarısız olursa
-- (ör. negatif fiyat) hepsi rollback olur — "hizmetsiz işletme" imkansız.
-- =============================================================

create function public.complete_onboarding(
  p_business_name text,
  p_currency_code text,
  p_timezone text,
  p_service_name text,
  p_service_price_per_minute_minor bigint,
  p_service_rounding_interval_minutes integer,
  p_service_minimum_charge_minutes integer,
  p_include_product boolean default false,
  p_product_name text default null,
  p_product_price_minor bigint default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_currency text := coalesce(p_currency_code, 'TRY');
  v_business_id uuid;
begin
  if v_user_id is null then
    raise exception 'authentication_required';
  end if;
  if p_business_name is null or char_length(trim(p_business_name)) = 0 then
    raise exception 'business_name_required';
  end if;
  if p_service_name is null or char_length(trim(p_service_name)) = 0 then
    raise exception 'service_name_required';
  end if;

  insert into public.businesses (name, currency_code, timezone)
  values (
    trim(p_business_name),
    v_currency,
    coalesce(p_timezone, 'Europe/Istanbul')
  )
  returning id into v_business_id;

  insert into public.business_members (business_id, user_id, role)
  values (v_business_id, v_user_id, 'owner');

  -- Zorunlu ilk hizmet. Fiyat check'i (>= 0) burada patlarsa tüm transaction
  -- rollback olur; işletme kaydı da geri alınır.
  insert into public.services (
    business_id, name, price_per_minute_minor,
    rounding_interval_minutes, minimum_charge_minutes, currency_code
  )
  values (
    v_business_id, trim(p_service_name), p_service_price_per_minute_minor,
    coalesce(p_service_rounding_interval_minutes, 1),
    coalesce(p_service_minimum_charge_minutes, 0),
    v_currency
  );

  if p_include_product then
    if p_product_name is null or char_length(trim(p_product_name)) = 0 then
      raise exception 'product_name_required';
    end if;
    insert into public.products (
      business_id, name, unit_price_minor, currency_code
    )
    values (
      v_business_id, trim(p_product_name),
      coalesce(p_product_price_minor, 0), v_currency
    );
  end if;

  return v_business_id;
end;
$$;

revoke execute on function public.complete_onboarding(
  text, text, text, text, bigint, integer, integer, boolean, text, bigint
) from public, anon;
grant execute on function public.complete_onboarding(
  text, text, text, text, bigint, integer, integer, boolean, text, bigint
) to authenticated;
