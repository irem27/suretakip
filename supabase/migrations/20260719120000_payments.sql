-- =============================================================
-- SüreTakip - Ödeme ve Tahsilat modülü
-- Kontrat: docs/contracts/payment-contract.md
--
-- Temel ayrım: sessions.grand_total_minor "müşteri ne kadar borçlandı",
-- payments + payment_allocations "ne kadarı fiilen tahsil edildi".
-- Tamamlanmış seans ÖDENMİŞ demek değildir.
--
-- Para: bigint kuruş + ISO 4217. Float yok.
-- Silme: yok. İptal = status'e geçiş, iade = yeni kayıt.
-- Yazma: yalnızca RPC. Hiçbir role tabloya insert/update/delete verilmez.
-- =============================================================

-- ---------- Enum'lar ----------
create type public.payment_method as enum ('cash', 'card', 'bank_transfer', 'other');
create type public.payment_kind   as enum ('collection', 'refund');
create type public.payment_status as enum ('completed', 'voided');

-- ---------- payments ----------
-- amount_minor iade kayıtlarında da POZİTİFTİR; yönü payment_kind taşır.
-- Böylece "> 0" invariantı istisnasız kalır.
create table public.payments (
  id                    uuid primary key default gen_random_uuid(),
  business_id           uuid not null references public.businesses(id) on delete restrict,
  customer_id           uuid,
  payment_kind          public.payment_kind not null,
  payment_method        public.payment_method not null,
  status                public.payment_status not null default 'completed',
  amount_minor          bigint not null,
  currency_code         text not null check (currency_code ~ '^[A-Z]{3}$'),
  original_payment_id   uuid,
  idempotency_key       text not null check (char_length(trim(idempotency_key)) between 1 and 200),
  external_reference    text,
  note                  text,
  received_by_member_id uuid not null,
  received_at           timestamptz not null default now(),
  voided_by_member_id   uuid,
  voided_at             timestamptz,
  void_reason           text,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),

  unique (id, business_id),
  -- Aynı işletmede aynı key ikinci bir ödeme üretemez (idempotency garantisi).
  unique (business_id, idempotency_key),

  -- Composite FK'ler: başka işletmenin müşterisine/personeline/ödemesine
  -- bağlanmak DB seviyesinde imkansız.
  foreign key (customer_id, business_id)
    references public.customers (id, business_id) on delete restrict,
  foreign key (received_by_member_id, business_id)
    references public.business_members (id, business_id) on delete restrict,
  foreign key (voided_by_member_id, business_id)
    references public.business_members (id, business_id) on delete restrict,
  foreign key (original_payment_id, business_id)
    references public.payments (id, business_id) on delete restrict,

  constraint chk_payment_amount_positive check (amount_minor > 0),

  -- İade orijinaline bağlı olmak ZORUNDA; tahsilat ise bağlı OLAMAZ.
  constraint chk_refund_has_original check (
    (payment_kind = 'refund'     and original_payment_id is not null)
    or (payment_kind = 'collection' and original_payment_id is null)
  ),

  -- Yarım iptal kaydı imkansız: iptalliyse üç alan da dolu, değilse üçü de boş.
  constraint chk_void_fields check (
    (status = 'voided'
       and voided_by_member_id is not null
       and voided_at is not null
       and void_reason is not null
       and char_length(trim(void_reason)) > 0)
    or (status = 'completed'
       and voided_by_member_id is null
       and voided_at is null
       and void_reason is null)
  )
);

create index idx_payments_business_received on public.payments (business_id, received_at desc);
create index idx_payments_business_status   on public.payments (business_id, status);
create index idx_payments_original          on public.payments (original_payment_id)
  where original_payment_id is not null;

create trigger trg_payments_updated_at
  before update on public.payments
  for each row execute function public.set_updated_at();

-- ---------- payment_allocations ----------
-- Bir ödemenin hangi seansa mahsup edildiği. v1'de ödeme başına tek satır;
-- tablo yapısı ileride tek ödemenin çok seansa bölünmesine şema değişikliği
-- olmadan izin verir.
create table public.payment_allocations (
  id           uuid primary key default gen_random_uuid(),
  business_id  uuid not null,
  payment_id   uuid not null,
  session_id   uuid not null,
  amount_minor bigint not null check (amount_minor > 0),
  created_at   timestamptz not null default now(),

  unique (id, business_id),
  foreign key (payment_id, business_id)
    references public.payments (id, business_id) on delete restrict,
  foreign key (session_id, business_id)
    references public.sessions (id, business_id) on delete restrict
);

create index idx_payment_allocations_session on public.payment_allocations (session_id);
create index idx_payment_allocations_payment on public.payment_allocations (payment_id);

-- ---------- payment_events (append-only denetim) ----------
-- inventory_movements ile aynı desen: UPDATE/DELETE yetkisi HİÇBİR role verilmez.
create table public.payment_events (
  id              uuid primary key default gen_random_uuid(),
  business_id     uuid not null,
  payment_id      uuid not null,
  event_type      text not null check (
    event_type in ('payment_recorded', 'payment_voided', 'payment_refunded')
  ),
  actor_member_id uuid not null,
  reason          text,
  details         jsonb,
  created_at      timestamptz not null default now(),

  foreign key (payment_id, business_id)
    references public.payments (id, business_id) on delete restrict,
  foreign key (actor_member_id, business_id)
    references public.business_members (id, business_id) on delete restrict
);

create index idx_payment_events_payment on public.payment_events (payment_id, created_at);
create index idx_payment_events_business on public.payment_events (business_id, created_at desc);

-- =============================================================
-- Dahili yardımcılar
-- authenticated'a execute VERİLMEZ; yalnızca aşağıdaki RPC'ler çağırır.
-- Üyelik kontrolü içermezler — kontrolü çağıran RPC yapar.
-- =============================================================

-- Seansın net ödeme tablosu. İptal edilmiş (voided) ödemeler HİÇBİR
-- toplama girmez; iadeler tahsilattan düşülür.
create function public.calc_session_payment_totals(
  p_session_id uuid,
  out collected_minor bigint,
  out refunded_minor bigint,
  out net_paid_minor bigint
)
language sql
security definer
set search_path = ''
stable
as $$
  select
    coalesce(sum(a.amount_minor) filter (
      where p.payment_kind = 'collection' and p.status = 'completed'), 0),
    coalesce(sum(a.amount_minor) filter (
      where p.payment_kind = 'refund' and p.status = 'completed'), 0),
    coalesce(sum(a.amount_minor) filter (
      where p.payment_kind = 'collection' and p.status = 'completed'), 0)
    - coalesce(sum(a.amount_minor) filter (
      where p.payment_kind = 'refund' and p.status = 'completed'), 0)
  from public.payment_allocations a
  join public.payments p
    on p.id = a.payment_id and p.business_id = a.business_id
  where a.session_id = p_session_id;
$$;

-- Kontrat §8'deki JSON zarfını üretir. Üyelik kontrolü ÇAĞIRANIN işidir.
create function public.build_session_payment_summary(p_session_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
stable
as $$
declare
  v_session public.sessions%rowtype;
  v_collected bigint;
  v_refunded bigint;
  v_net bigint;
  v_total bigint;
  v_remaining bigint;
  v_status text;
  v_caller_member_id uuid;
  v_payments jsonb;
begin
  select * into v_session from public.sessions where id = p_session_id;
  if not found then
    raise exception 'session_not_found';
  end if;

  select collected_minor, refunded_minor, net_paid_minor
    into v_collected, v_refunded, v_net
  from public.calc_session_payment_totals(p_session_id);

  -- Tamamlanmamış seansta grand_total henüz null'dur.
  v_total := coalesce(v_session.grand_total_minor, 0);

  -- Kalan asla negatif olmaz.
  v_remaining := greatest(0, v_total - v_net);

  -- Sıra önemli: net = 0 önce bakılır, böylece toplamı 0 olan seans
  -- yanlışlıkla "paid" görünmez.
  v_status := case
    when v_net <= 0 then 'unpaid'
    when v_net < v_total then 'partially_paid'
    else 'paid'
  end;

  v_caller_member_id := public.active_member_id(v_session.business_id);

  -- E-posta/user_id sızdırılmaz; yalnızca opak member id ve "ben mi?" bilgisi.
  select coalesce(jsonb_agg(entry order by entry_received_at), '[]'::jsonb)
    into v_payments
  from (
    select
      p.received_at as entry_received_at,
      jsonb_build_object(
        'id',                    p.id,
        'payment_kind',          p.payment_kind,
        'payment_method',        p.payment_method,
        'status',                p.status,
        'amount_minor',          p.amount_minor,
        'currency_code',         p.currency_code,
        'original_payment_id',   p.original_payment_id,
        'external_reference',    p.external_reference,
        'note',                  p.note,
        'received_by_member_id', p.received_by_member_id,
        'received_by_me',        (v_caller_member_id is not null
                                   and p.received_by_member_id = v_caller_member_id),
        'received_at',           p.received_at,
        'voided_by_member_id',   p.voided_by_member_id,
        'voided_at',             p.voided_at,
        'void_reason',           p.void_reason
      ) as entry
    from public.payments p
    join public.payment_allocations a
      on a.payment_id = p.id and a.business_id = p.business_id
    where a.session_id = p_session_id
  ) rows;

  return jsonb_build_object(
    'session_id',          p_session_id,
    'currency_code',       v_session.currency_code_snapshot,
    'session_total_minor', v_total,
    'collected_minor',     v_collected,
    'refunded_minor',      v_refunded,
    'net_paid_minor',      v_net,
    'remaining_minor',     v_remaining,
    'payment_status',      v_status,
    'payments',            v_payments
  );
end;
$$;

revoke execute on function public.calc_session_payment_totals(uuid) from public, anon, authenticated;
revoke execute on function public.build_session_payment_summary(uuid) from public, anon, authenticated;

-- =============================================================
-- RPC 1: record_session_payment
-- =============================================================
create function public.record_session_payment(
  p_session_id         uuid,
  p_payment_method     public.payment_method,
  p_amount_minor       bigint,
  p_idempotency_key    text,
  p_external_reference text default null,
  p_note               text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session public.sessions%rowtype;
  v_member_id uuid;
  v_existing public.payments%rowtype;
  v_net bigint;
  v_remaining bigint;
  v_payment_id uuid;
begin
  if p_idempotency_key is null or char_length(trim(p_idempotency_key)) = 0 then
    raise exception 'payment_idempotency_key_required';
  end if;
  if coalesce(p_amount_minor, 0) <= 0 then
    raise exception 'payment_amount_invalid';
  end if;

  -- for update: aynı seansa eşzamanlı ödemeler SIRAYA girer. Bakiye
  -- kontrolü bu kilidin altında yapıldığı için iki cihaz birlikte
  -- bakiyeyi aşamaz.
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

  -- Idempotency: aynı key ile gelen tekrar isteği YENİ ödeme açmaz.
  -- Kilit alındıktan sonra bakılır ki eşzamanlı ilk istek commit olmuşsa
  -- burada görünsün.
  select * into v_existing
  from public.payments
  where business_id = v_session.business_id
    and idempotency_key = trim(p_idempotency_key);
  if found then
    -- Anahtar BASKA bir seans icin kullanilmissa "basarili" donmek, odemenin
    -- sessizce kaybolmasi demektir: arayuz tahsil edildi sanir, kayit yoktur.
    -- Istemciye guvenilmez; bu durum acikca reddedilir.
    if not exists (
      select 1 from public.payment_allocations
      where payment_id = v_existing.id
        and session_id = p_session_id
    ) then
      raise exception 'payment_idempotency_key_reused';
    end if;
    return public.build_session_payment_summary(p_session_id)
           || jsonb_build_object('payment_id', v_existing.id, 'replayed', true);
  end if;

  -- Bu fazda yalnızca tamamlanmış seans ödenebilir.
  if v_session.status <> 'completed' then
    raise exception 'session_not_payable';
  end if;

  select net_paid_minor into v_net
  from public.calc_session_payment_totals(p_session_id);

  v_remaining := greatest(0, coalesce(v_session.grand_total_minor, 0) - v_net);
  if p_amount_minor > v_remaining then
    raise exception 'payment_exceeds_balance';
  end if;

  insert into public.payments (
    business_id, customer_id, payment_kind, payment_method, status,
    amount_minor, currency_code, idempotency_key,
    external_reference, note, received_by_member_id
  ) values (
    v_session.business_id, v_session.customer_id, 'collection', p_payment_method, 'completed',
    p_amount_minor, v_session.currency_code_snapshot, trim(p_idempotency_key),
    p_external_reference, p_note, v_member_id
  )
  returning id into v_payment_id;

  insert into public.payment_allocations (business_id, payment_id, session_id, amount_minor)
  values (v_session.business_id, v_payment_id, p_session_id, p_amount_minor);

  insert into public.payment_events (
    business_id, payment_id, event_type, actor_member_id, details
  ) values (
    v_session.business_id, v_payment_id, 'payment_recorded', v_member_id,
    jsonb_build_object(
      'session_id', p_session_id,
      'amount_minor', p_amount_minor,
      'payment_method', p_payment_method,
      'remaining_before_minor', v_remaining
    )
  );

  return public.build_session_payment_summary(p_session_id)
         || jsonb_build_object('payment_id', v_payment_id, 'replayed', false);

exception
  -- Aynı key ile TAM eşzamanlı iki istek: unique constraint tetiklenir,
  -- kaybeden taraf mevcut kaydı döndürür. Sonuç yine tek ödeme.
  when unique_violation then
    select * into v_existing
    from public.payments
    where business_id = v_session.business_id
      and idempotency_key = trim(p_idempotency_key);
    if not found then
      raise;
    end if;
    if not exists (
      select 1 from public.payment_allocations
      where payment_id = v_existing.id
        and session_id = p_session_id
    ) then
      raise exception 'payment_idempotency_key_reused';
    end if;
    return public.build_session_payment_summary(p_session_id)
           || jsonb_build_object('payment_id', v_existing.id, 'replayed', true);
end;
$$;

-- =============================================================
-- RPC 2: get_session_payment_summary
-- =============================================================
create function public.get_session_payment_summary(p_session_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
stable
as $$
declare
  v_business_id uuid;
begin
  select business_id into v_business_id
  from public.sessions
  where id = p_session_id;
  if not found then
    raise exception 'session_not_found';
  end if;

  -- Tenant izolasyonu: başka işletmenin seansı "bulunamadı" gibi davranır,
  -- varlığı sızdırılmaz.
  if public.active_member_id(v_business_id) is null then
    raise exception 'session_not_found';
  end if;

  return public.build_session_payment_summary(p_session_id);
end;
$$;

-- =============================================================
-- RPC 3: void_payment  (owner/admin)
-- =============================================================
create function public.void_payment(p_payment_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_payment public.payments%rowtype;
  v_member_id uuid;
  v_session_id uuid;
begin
  if p_reason is null or char_length(trim(p_reason)) = 0 then
    raise exception 'payment_reason_required';
  end if;

  select * into v_payment
  from public.payments
  where id = p_payment_id
  for update;
  if not found then
    raise exception 'payment_not_found';
  end if;

  v_member_id := public.active_member_id(v_payment.business_id);
  if v_member_id is null then
    -- Başka tenant'ın ödemesi: varlığını sızdırma.
    raise exception 'payment_not_found';
  end if;

  if not public.has_business_role(
       v_payment.business_id, array['owner','admin']::public.member_role[]) then
    raise exception 'not_authorized';
  end if;

  if v_payment.payment_kind <> 'collection' then
    raise exception 'payment_kind_not_voidable';
  end if;

  if v_payment.status = 'voided' then
    raise exception 'payment_already_voided';
  end if;

  -- Kayıt SİLİNMEZ; durumu değişir ve denetim izi yazılır.
  update public.payments
     set status = 'voided',
         voided_by_member_id = v_member_id,
         voided_at = now(),
         void_reason = trim(p_reason)
   where id = p_payment_id;

  insert into public.payment_events (
    business_id, payment_id, event_type, actor_member_id, reason, details
  ) values (
    v_payment.business_id, p_payment_id, 'payment_voided', v_member_id, trim(p_reason),
    jsonb_build_object(
      'previous_status', 'completed',
      'new_status', 'voided',
      'amount_minor', v_payment.amount_minor
    )
  );

  select session_id into v_session_id
  from public.payment_allocations
  where payment_id = p_payment_id
  limit 1;

  return public.build_session_payment_summary(v_session_id)
         || jsonb_build_object('payment_id', p_payment_id);
end;
$$;

-- =============================================================
-- RPC 4: refund_payment  (owner/admin)
-- =============================================================
create function public.refund_payment(
  p_payment_id      uuid,
  p_amount_minor    bigint,
  p_idempotency_key text,
  p_reason          text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_original public.payments%rowtype;
  v_member_id uuid;
  v_existing public.payments%rowtype;
  v_already_refunded bigint;
  v_refundable bigint;
  v_session_id uuid;
  v_refund_id uuid;
begin
  if p_idempotency_key is null or char_length(trim(p_idempotency_key)) = 0 then
    raise exception 'payment_idempotency_key_required';
  end if;
  if p_reason is null or char_length(trim(p_reason)) = 0 then
    raise exception 'payment_reason_required';
  end if;
  if coalesce(p_amount_minor, 0) <= 0 then
    raise exception 'payment_amount_invalid';
  end if;

  -- for update: aynı ödemeye eşzamanlı iki iade sıraya girer; iade
  -- edilebilir tutar kilidin altında hesaplanır.
  select * into v_original
  from public.payments
  where id = p_payment_id
  for update;
  if not found then
    raise exception 'payment_not_found';
  end if;

  v_member_id := public.active_member_id(v_original.business_id);
  if v_member_id is null then
    raise exception 'payment_not_found';
  end if;

  if not public.has_business_role(
       v_original.business_id, array['owner','admin']::public.member_role[]) then
    raise exception 'not_authorized';
  end if;

  -- Idempotency: aynı key ikinci bir iade üretmez.
  select * into v_existing
  from public.payments
  where business_id = v_original.business_id
    and idempotency_key = trim(p_idempotency_key);
  if found then
    -- Anahtar BASKA bir orijinal odeme icin kullanilmissa, iade sessizce
    -- gerceklesmemis olur ama istek basarili doner. Reddet.
    if v_existing.original_payment_id is distinct from p_payment_id then
      raise exception 'payment_idempotency_key_reused';
    end if;
    select session_id into v_session_id
    from public.payment_allocations where payment_id = v_existing.id limit 1;
    return public.build_session_payment_summary(v_session_id)
           || jsonb_build_object('payment_id', v_existing.id, 'replayed', true);
  end if;

  if v_original.payment_kind <> 'collection' or v_original.status <> 'completed' then
    raise exception 'payment_not_found';
  end if;

  -- İade edilebilir = orijinal tutar - o ödemeye bağlı geçerli iadeler
  select coalesce(sum(amount_minor), 0) into v_already_refunded
  from public.payments
  where original_payment_id = p_payment_id
    and status = 'completed';

  v_refundable := v_original.amount_minor - v_already_refunded;
  if p_amount_minor > v_refundable then
    raise exception 'refund_exceeds_refundable';
  end if;

  select session_id into v_session_id
  from public.payment_allocations
  where payment_id = p_payment_id
  limit 1;

  -- Orijinal kayıt DEĞİŞTİRİLMEZ / SİLİNMEZ; iade YENİ kayıttır.
  insert into public.payments (
    business_id, customer_id, payment_kind, payment_method, status,
    amount_minor, currency_code, original_payment_id, idempotency_key,
    note, received_by_member_id
  ) values (
    v_original.business_id, v_original.customer_id, 'refund', v_original.payment_method, 'completed',
    p_amount_minor, v_original.currency_code, p_payment_id, trim(p_idempotency_key),
    trim(p_reason), v_member_id
  )
  returning id into v_refund_id;

  insert into public.payment_allocations (business_id, payment_id, session_id, amount_minor)
  values (v_original.business_id, v_refund_id, v_session_id, p_amount_minor);

  insert into public.payment_events (
    business_id, payment_id, event_type, actor_member_id, reason, details
  ) values (
    v_original.business_id, v_refund_id, 'payment_refunded', v_member_id, trim(p_reason),
    jsonb_build_object(
      'original_payment_id', p_payment_id,
      'amount_minor', p_amount_minor,
      'refundable_before_minor', v_refundable
    )
  );

  return public.build_session_payment_summary(v_session_id)
         || jsonb_build_object('payment_id', v_refund_id, 'replayed', false);
end;
$$;

-- =============================================================
-- GRANT + RLS
-- =============================================================

-- Okuma serbest (satır filtresi RLS'te). YAZMA GRANT'İ YOK — kasıtlı.
grant select on public.payments, public.payment_allocations, public.payment_events
  to authenticated;

grant all on public.payments, public.payment_allocations, public.payment_events
  to service_role;

revoke execute on function
  public.record_session_payment(uuid, public.payment_method, bigint, text, text, text),
  public.get_session_payment_summary(uuid),
  public.void_payment(uuid, text),
  public.refund_payment(uuid, bigint, text, text)
from public, anon;

grant execute on function
  public.record_session_payment(uuid, public.payment_method, bigint, text, text, text),
  public.get_session_payment_summary(uuid),
  public.void_payment(uuid, text),
  public.refund_payment(uuid, bigint, text, text)
to authenticated;

alter table public.payments            enable row level security;
alter table public.payment_allocations enable row level security;
alter table public.payment_events      enable row level security;

-- Yalnızca SELECT politikası tanımlanır. insert/update/delete politikası
-- YOK => RLS varsayılanı deny. Fail-closed: politika unutulursa erişim
-- açılmaz, kapanır.
create policy "members can view payments"
  on public.payments for select
  using (public.is_business_member(business_id));

create policy "members can view payment allocations"
  on public.payment_allocations for select
  using (public.is_business_member(business_id));

create policy "members can view payment events"
  on public.payment_events for select
  using (public.is_business_member(business_id));
