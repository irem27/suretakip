-- =============================================================
-- SüreTakip - Migration 2/3: GRANT + RLS
-- Katman 1 (GRANT): role hangi tablolara/kolonlara hangi komutla girebilir?
-- Katman 2 (RLS):   girdiği tabloda hangi satırları görebilir/yazabilir?
-- anon'a hiçbir yetki verilmez; finansal tablolarda DELETE hiç verilmez.
-- =============================================================

-- ---------- Güvenli yardımcı fonksiyonlar ----------
-- security definer: business_members'a RLS'e takılmadan bakar (policy
-- recursion önlenir). set search_path = '': arama yolu zehirlenmesine karşı.
-- Sadece evet/hayır dönerler; veri sızdırmazlar. Pasif üyelik sayılmaz.

create function public.is_business_member(p_business_id uuid)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select exists (
    select 1
    from public.business_members
    where business_id = p_business_id
      and user_id = (select auth.uid())
      and is_active
  );
$$;

create function public.has_business_role(p_business_id uuid, p_roles public.member_role[])
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select exists (
    select 1
    from public.business_members
    where business_id = p_business_id
      and user_id = (select auth.uid())
      and is_active
      and role = any (p_roles)
  );
$$;

-- Çağıranın bu işletmedeki aktif üyelik id'si (RPC'lerde opened_by/created_by için).
create function public.active_member_id(p_business_id uuid)
returns uuid
language sql
security definer
set search_path = ''
stable
as $$
  select id
  from public.business_members
  where business_id = p_business_id
    and user_id = (select auth.uid())
    and is_active
  limit 1;
$$;

revoke execute on function public.is_business_member(uuid) from public, anon;
revoke execute on function public.has_business_role(uuid, public.member_role[]) from public, anon;
revoke execute on function public.active_member_id(uuid) from public, anon;
grant execute on function public.is_business_member(uuid) to authenticated;
grant execute on function public.has_business_role(uuid, public.member_role[]) to authenticated;
grant execute on function public.active_member_id(uuid) to authenticated;

-- ---------- Onboarding RPC ----------
-- businesses + owner üyeliği tek transaction'da; "sahipsiz işletme" imkansız.
-- businesses tablosuna doğrudan INSERT yetkisi bilinçli olarak yok.
create function public.create_business_with_owner(
  p_name text,
  p_currency_code text default 'TRY',
  p_timezone text default 'Europe/Istanbul'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_business_id uuid;
begin
  if v_user_id is null then
    raise exception 'authentication_required';
  end if;
  if p_name is null or char_length(trim(p_name)) = 0 then
    raise exception 'business_name_required';
  end if;

  insert into public.businesses (name, currency_code, timezone)
  values (trim(p_name), coalesce(p_currency_code, 'TRY'), coalesce(p_timezone, 'Europe/Istanbul'))
  returning id into v_business_id;

  insert into public.business_members (business_id, user_id, role)
  values (v_business_id, v_user_id, 'owner');

  return v_business_id;
end;
$$;

revoke execute on function public.create_business_with_owner(text, text, text) from public, anon;
grant execute on function public.create_business_with_owner(text, text, text) to authenticated;

-- ---------- GRANT katmanı ----------
grant usage on schema public to authenticated, service_role;

-- Okuma: üyeler her tenant tablosunu okuyabilir (satır filtresi RLS'te).
grant select on
  public.businesses,
  public.business_members,
  public.customers,
  public.services,
  public.products,
  public.sessions,
  public.session_time_entries,
  public.session_items,
  public.inventory_movements
to authenticated;

-- Yazma: sadece dogrudan yönetilen tablolar. Seans yaşam döngüsü,
-- zaman ledger'ı ve satışlar YALNIZCA RPC üzerinden yürür — bu tablolara
-- insert/update grant'i bilinçli olarak verilmez.
grant insert, update on
  public.customers,
  public.services,
  public.products
to authenticated;

grant update on public.businesses to authenticated;
grant insert, update, delete on public.business_members to authenticated;

-- sessions: kolon seviyesinde grant — sadece not ve müşteri düzeltilebilir.
-- status/toplam/snapshot kolonlarına dogrudan UPDATE imkansız (RPC işi).
grant update (notes, customer_id) on public.sessions to authenticated;

-- Manuel stok hareketi (sayım düzeltmesi, yeni mal girişi) insert edilebilir;
-- hangi tiplerin serbest olduğu RLS policy'de daraltılır.
grant insert on public.inventory_movements to authenticated;

-- service_role sunucu tarafı içindir; RLS'i zaten bypass eder.
grant all on all tables in schema public to service_role;

-- ---------- RLS aktivasyonu ----------
alter table public.businesses           enable row level security;
alter table public.business_members     enable row level security;
alter table public.customers            enable row level security;
alter table public.services             enable row level security;
alter table public.products             enable row level security;
alter table public.sessions             enable row level security;
alter table public.session_time_entries enable row level security;
alter table public.session_items        enable row level security;
alter table public.inventory_movements  enable row level security;

-- ---------- businesses ----------
create policy "members can view business"
  on public.businesses for select
  using (public.is_business_member(id));

create policy "owner/admin can update business"
  on public.businesses for update
  using (public.has_business_role(id, array['owner','admin']::public.member_role[]))
  with check (public.has_business_role(id, array['owner','admin']::public.member_role[]));

-- ---------- business_members ----------
-- Guard: admin, owner satırı oluşturamaz/değiştiremez/silemez (yetki
-- yükseltme koruması). Owner her üyeliği yönetir.
create policy "members can view memberships"
  on public.business_members for select
  using (public.is_business_member(business_id));

create policy "owner/admin can add members"
  on public.business_members for insert
  with check (
    public.has_business_role(business_id, array['owner','admin']::public.member_role[])
    and (role <> 'owner' or public.has_business_role(business_id, array['owner']::public.member_role[]))
  );

create policy "owner/admin can update members"
  on public.business_members for update
  using (
    public.has_business_role(business_id, array['owner','admin']::public.member_role[])
    and (role <> 'owner' or public.has_business_role(business_id, array['owner']::public.member_role[]))
  )
  with check (
    public.has_business_role(business_id, array['owner','admin']::public.member_role[])
    and (role <> 'owner' or public.has_business_role(business_id, array['owner']::public.member_role[]))
  );

create policy "owner/admin can remove members"
  on public.business_members for delete
  using (
    public.has_business_role(business_id, array['owner','admin']::public.member_role[])
    and (role <> 'owner' or public.has_business_role(business_id, array['owner']::public.member_role[]))
  );

-- ---------- customers ----------
-- Staff dahil her aktif üye müşteri kaydı açıp güncelleyebilir (operasyonel iş).
create policy "members can view customers"
  on public.customers for select
  using (public.is_business_member(business_id));

create policy "members can insert customers"
  on public.customers for insert
  with check (public.is_business_member(business_id));

create policy "members can update customers"
  on public.customers for update
  using (public.is_business_member(business_id))
  with check (public.is_business_member(business_id));

-- ---------- services ----------
create policy "members can view services"
  on public.services for select
  using (public.is_business_member(business_id));

create policy "owner/admin can insert services"
  on public.services for insert
  with check (public.has_business_role(business_id, array['owner','admin']::public.member_role[]));

create policy "owner/admin can update services"
  on public.services for update
  using (public.has_business_role(business_id, array['owner','admin']::public.member_role[]))
  with check (public.has_business_role(business_id, array['owner','admin']::public.member_role[]));

-- ---------- products ----------
create policy "members can view products"
  on public.products for select
  using (public.is_business_member(business_id));

create policy "owner/admin can insert products"
  on public.products for insert
  with check (public.has_business_role(business_id, array['owner','admin']::public.member_role[]));

create policy "owner/admin can update products"
  on public.products for update
  using (public.has_business_role(business_id, array['owner','admin']::public.member_role[]))
  with check (public.has_business_role(business_id, array['owner','admin']::public.member_role[]));

-- ---------- sessions ----------
-- INSERT policy yok: seans yalnızca start_session RPC'siyle açılır.
-- UPDATE: grant zaten sadece (notes, customer_id) kolonlarına izin veriyor.
create policy "members can view sessions"
  on public.sessions for select
  using (public.is_business_member(business_id));

create policy "members can update session notes"
  on public.sessions for update
  using (public.is_business_member(business_id))
  with check (public.is_business_member(business_id));

-- ---------- session_time_entries ----------
-- Salt okunur ledger: yazma yalnızca RPC'lerde (grant da verilmedi).
create policy "members can view time entries"
  on public.session_time_entries for select
  using (public.is_business_member(business_id));

-- ---------- session_items ----------
-- Salt okunur: satış satırı yalnızca add_product_to_session RPC'siyle oluşur.
create policy "members can view session items"
  on public.session_items for select
  using (public.is_business_member(business_id));

-- ---------- inventory_movements ----------
-- sale / sale_reversal yalnızca RPC'lerden gelir; elle yalnızca owner/admin,
-- yalnızca stok yönetim tipleri ve satışa bağlanmamış kayıt yazabilir.
create policy "members can view inventory movements"
  on public.inventory_movements for select
  using (public.is_business_member(business_id));

create policy "owner/admin can insert manual movements"
  on public.inventory_movements for insert
  with check (
    public.has_business_role(business_id, array['owner','admin']::public.member_role[])
    and movement_type in ('initial', 'manual_adjustment', 'restock')
    and session_item_id is null
  );
