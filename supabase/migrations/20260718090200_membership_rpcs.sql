-- =============================================================
-- SüreTakip - Migration 10: Güvenli üyelik yönetimi + son owner invariantı (P0-3)
--
-- SORUN: 20260717130100_rls.sql, authenticated role'e business_members
-- üzerinde GENEL insert/update/delete yetkisi veriyordu. Policy'ler yalnız
-- "admin owner satırına dokunamaz" kuralını uyguluyordu. Owner'ın KENDİ
-- satırı için hiçbir kısıt yoktu:
--
--   delete from business_members where id = <kendi owner satirim>;
--   update business_members set is_active = false where id = <kendi satirim>;
--   update business_members set role = 'staff' where id = <kendi satirim>;
--
-- Üçü de işletmeyi SIFIR AKTİF OWNER ile bırakır. Sonuç kalıcı kilitlenmedir:
-- owner-only işlemler (işletme ayarları, tamamlanmış seans iptali, owner
-- atama) artık hiç kimse tarafından yapılamaz ve kendi kendine düzeltilemez —
-- yalnız service_role müdahalesiyle çözülür.
--
-- ÇÖZÜM: mutasyonları SECURITY DEFINER RPC'lere taşı, tablo grant'lerini
-- kaldır, invariantı tek yerde ve kilit altında uygula.
--
-- INVARIANT: "Her işletmenin her an EN AZ BİR aktif owner'ı vardır."
-- Bu invariantı üç yol birden ihlal edebilir (silme, pasifleştirme, rol
-- düşürme); üçü de aynı assert_not_last_owner() kontrolünden geçer.
--
-- EŞZAMANLILIK: iki owner aynı anda "ben ayrılıyorum" derse, ikisi de
-- "diğeri var" görüp sıfır owner bırakabilirdi. Her mutasyon businesses
-- satırını FOR UPDATE ile kilitler; aynı işletmedeki üyelik mutasyonları
-- serileşir.
-- =============================================================

-- ---------- GRANT katmanı: doğrudan yazma tamamen kapatılır ----------
revoke insert, update, delete on public.business_members from authenticated;

-- SELECT korunur: üyeler kendi işletmelerinin üye listesini görebilmeli
-- (mevcut "members can view memberships" policy'si).

-- ---------- RLS katmanı: yazma policy'leri düşürülür ----------
-- Grant kalktığı için ulaşılamazlar. Düşürüyoruz ki ileride biri yanlışlıkla
-- "grant update on business_members to authenticated" yazarsa, UPDATE
-- policy'si olmayan RLS tablosu yazmayı yine de REDDETSİN.
drop policy if exists "owner/admin can add members"    on public.business_members;
drop policy if exists "owner/admin can update members" on public.business_members;
drop policy if exists "owner/admin can remove members" on public.business_members;

-- ---------- Yardımcı: çağıranın bu işletmedeki rolü ----------
create function public.caller_business_role(p_business_id uuid)
returns public.member_role
language sql
security definer
set search_path = ''
stable
as $$
  select role
  from public.business_members
  where business_id = p_business_id
    and user_id = (select auth.uid())
    and is_active
  limit 1;
$$;

revoke execute on function public.caller_business_role(uuid) from public, anon;
grant execute on function public.caller_business_role(uuid) to authenticated;

-- ---------- Yardımcı: son owner invariantı ----------
-- p_member_id "owner olmaktan çıkacak" satırdır. O satır hesaptan
-- düşüldüğünde geriye aktif owner kalmıyorsa işlem reddedilir.
create function public.assert_not_last_owner(p_member_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_business_id uuid;
  v_role public.member_role;
  v_is_active boolean;
  v_other_owners integer;
begin
  select business_id, role, is_active
    into v_business_id, v_role, v_is_active
  from public.business_members
  where id = p_member_id;

  -- Zaten owner değilse veya zaten pasifse invariant riski yok.
  if v_role is distinct from 'owner' or not v_is_active then
    return;
  end if;

  select count(*)
    into v_other_owners
  from public.business_members
  where business_id = v_business_id
    and role = 'owner'
    and is_active
    and id <> p_member_id;

  if v_other_owners = 0 then
    raise exception 'last_owner_protected'
      using hint = 'Isletmede en az bir aktif owner kalmalidir. Once '
                   'transfer_business_ownership ile sahipligi devredin.';
  end if;
end;
$$;

revoke execute on function public.assert_not_last_owner(uuid) from public, anon, authenticated;
-- Bu fonksiyon yalnız aşağıdaki RPC'lerin içinden çağrılır; dışarıya açılmaz.

-- ---------- Yardımcı: çağıranın hedef satıra yetkisi var mı ----------
-- Ortak kural seti (tek yerde tanımlı, dört RPC de buradan geçer):
--   * staff hiçbir üyeliği yönetemez,
--   * admin owner satırına DOKUNAMAZ ve kimseyi owner YAPAMAZ
--     (yetki yükseltme koruması),
--   * owner her satırı yönetir (son owner invariantı ayrıca uygulanır),
--   * başka işletmenin üyeliği yönetilemez (çağıran orada üye değildir).
create function public.assert_can_manage_member(
  p_business_id uuid,
  p_target_role public.member_role,
  p_new_role public.member_role default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller_role public.member_role := public.caller_business_role(p_business_id);
begin
  if v_caller_role is null then
    -- Üye değil (veya pasif üye). Başka işletmenin verisi de buraya düşer.
    raise exception 'not_a_member';
  end if;

  if v_caller_role = 'staff' then
    raise exception 'not_authorized'
      using hint = 'Uyelik yonetimi owner/admin yetkisidir.';
  end if;

  if v_caller_role = 'admin' then
    if p_target_role = 'owner' then
      raise exception 'not_authorized'
        using hint = 'Admin, owner satirini degistiremez.';
    end if;
    if p_new_role = 'owner' then
      raise exception 'not_authorized'
        using hint = 'Admin, kimseyi owner yapamaz.';
    end if;
  end if;
end;
$$;

revoke execute on function public.assert_can_manage_member(uuid, public.member_role, public.member_role)
  from public, anon, authenticated;

-- =============================================================
-- RPC 1: Üye ekleme
-- =============================================================
create function public.add_business_member(
  p_business_id uuid,
  p_user_id uuid,
  p_role public.member_role default 'staff'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_member_id uuid;
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;
  if p_user_id is null then
    raise exception 'user_id_required';
  end if;

  -- Aynı işletmedeki üyelik mutasyonlarını serileştir.
  perform 1 from public.businesses where id = p_business_id for update;

  -- Eklenecek satırın rolü hedef roldür; admin owner ekleyemez.
  perform public.assert_can_manage_member(p_business_id, p_role, p_role);

  insert into public.business_members (business_id, user_id, role)
  values (p_business_id, p_user_id, p_role)
  returning id into v_member_id;

  return v_member_id;
exception
  when unique_violation then
    raise exception 'member_already_exists'
      using hint = 'Bu kullanici zaten bu isletmenin uyesi. Pasif uyeyi '
                   'set_business_member_active ile yeniden aktive edin.';
  when foreign_key_violation then
    raise exception 'user_not_found';
end;
$$;

revoke execute on function public.add_business_member(uuid, uuid, public.member_role)
  from public, anon;
grant execute on function public.add_business_member(uuid, uuid, public.member_role)
  to authenticated;

-- =============================================================
-- RPC 2: Rol değiştirme
-- =============================================================
create function public.update_business_member_role(
  p_member_id uuid,
  p_role public.member_role
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_business_id uuid;
  v_target_role public.member_role;
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;

  select business_id, role into v_business_id, v_target_role
  from public.business_members
  where id = p_member_id;

  if v_business_id is null then
    raise exception 'member_not_found';
  end if;

  perform 1 from public.businesses where id = v_business_id for update;
  perform public.assert_can_manage_member(v_business_id, v_target_role, p_role);

  -- Owner'ı owner olmayan bir role düşürmek invariantı bozabilir.
  if v_target_role = 'owner' and p_role <> 'owner' then
    perform public.assert_not_last_owner(p_member_id);
  end if;

  update public.business_members
     set role = p_role
   where id = p_member_id;
end;
$$;

revoke execute on function public.update_business_member_role(uuid, public.member_role)
  from public, anon;
grant execute on function public.update_business_member_role(uuid, public.member_role)
  to authenticated;

-- =============================================================
-- RPC 3: Aktif/pasif etme
-- =============================================================
create function public.set_business_member_active(
  p_member_id uuid,
  p_is_active boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_business_id uuid;
  v_target_role public.member_role;
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;

  select business_id, role into v_business_id, v_target_role
  from public.business_members
  where id = p_member_id;

  if v_business_id is null then
    raise exception 'member_not_found';
  end if;

  perform 1 from public.businesses where id = v_business_id for update;
  perform public.assert_can_manage_member(v_business_id, v_target_role);

  -- Pasifleştirme, owner'ı "aktif owner" sayısından düşürür.
  if not p_is_active then
    perform public.assert_not_last_owner(p_member_id);
  end if;

  update public.business_members
     set is_active = p_is_active
   where id = p_member_id;
end;
$$;

revoke execute on function public.set_business_member_active(uuid, boolean)
  from public, anon;
grant execute on function public.set_business_member_active(uuid, boolean)
  to authenticated;

-- =============================================================
-- RPC 4: Üye silme (kalıcı)
-- =============================================================
-- Not: business_members, sessions ve inventory_movements tarafından
-- `on delete restrict` ile referanslanır. Geçmişi olan üye SİLİNEMEZ;
-- doğru operasyon set_business_member_active(false) ile pasifleştirmedir.
-- Bu RPC yalnız "yanlış eklenmiş, hiç işlem yapmamış üye" senaryosu içindir.
create function public.remove_business_member(p_member_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_business_id uuid;
  v_target_role public.member_role;
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;

  select business_id, role into v_business_id, v_target_role
  from public.business_members
  where id = p_member_id;

  if v_business_id is null then
    raise exception 'member_not_found';
  end if;

  perform 1 from public.businesses where id = v_business_id for update;
  perform public.assert_can_manage_member(v_business_id, v_target_role);
  perform public.assert_not_last_owner(p_member_id);

  delete from public.business_members where id = p_member_id;
exception
  when foreign_key_violation then
    raise exception 'member_has_history'
      using hint = 'Bu uyenin seans/stok gecmisi var. Silmek yerine '
                   'set_business_member_active(false) ile pasiflestirin.';
end;
$$;

revoke execute on function public.remove_business_member(uuid) from public, anon;
grant execute on function public.remove_business_member(uuid) to authenticated;

-- =============================================================
-- RPC 5: Sahiplik devri (atomik)
-- =============================================================
-- Tek owner'ın işletmeden ayrılabilmesinin MEŞRU yolu. İki adım tek
-- transaction'da yapılır; arada hiçbir an sıfır owner oluşmaz ve devir
-- yarıda kalamaz.
create function public.transfer_business_ownership(
  p_business_id uuid,
  p_to_member_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller_member_id uuid;
  v_target_business_id uuid;
  v_target_is_active boolean;
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;

  perform 1 from public.businesses where id = p_business_id for update;

  -- Sahipliği yalnız mevcut owner devredebilir; admin devir başlatamaz.
  if public.caller_business_role(p_business_id) is distinct from 'owner' then
    raise exception 'not_authorized'
      using hint = 'Sahiplik devrini yalnizca mevcut owner baslatabilir.';
  end if;

  v_caller_member_id := public.active_member_id(p_business_id);

  select business_id, is_active
    into v_target_business_id, v_target_is_active
  from public.business_members
  where id = p_to_member_id;

  if v_target_business_id is null then
    raise exception 'member_not_found';
  end if;
  -- Hedef başka işletmenin üyesi olamaz (tenant sınırı).
  if v_target_business_id <> p_business_id then
    raise exception 'member_not_found';
  end if;
  if not v_target_is_active then
    raise exception 'target_member_inactive'
      using hint = 'Sahiplik yalnizca aktif bir uyeye devredilebilir.';
  end if;
  if p_to_member_id = v_caller_member_id then
    raise exception 'cannot_transfer_to_self';
  end if;

  -- Önce yükselt, sonra düşür: sıra önemli değil (tek transaction) ama
  -- bu sırayla ara durumda bile iki owner vardır, sıfır owner asla.
  update public.business_members
     set role = 'owner'
   where id = p_to_member_id;

  update public.business_members
     set role = 'admin'
   where id = v_caller_member_id;
end;
$$;

revoke execute on function public.transfer_business_ownership(uuid, uuid) from public, anon;
grant execute on function public.transfer_business_ownership(uuid, uuid) to authenticated;

comment on function public.transfer_business_ownership(uuid, uuid) is
  'Sahipligi atomik devreder (hedef -> owner, cagiran -> admin). Tek '
  'owner''in isletmeden ayrilabilmesinin tek mesru yolu.';
