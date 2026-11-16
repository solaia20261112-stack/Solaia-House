BEGIN;

-- Requires the existing restaurant POS schema and its per-item kitchen RPC.
DO $$
BEGIN
  IF to_regclass('public.restaurant_bookings') IS NULL
    OR to_regclass('public.restaurant_menu') IS NULL
    OR to_regprocedure('public.restaurant_send_kitchen_lines(uuid,text,text,jsonb,text)') IS NULL
    OR to_regprocedure('public.restaurant_is_cashier()') IS NULL THEN
    RAISE EXCEPTION '請先在小樂義的 Supabase 專案安裝現有餐廳 POS 資料庫，再執行此更新';
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.restaurant_online_requests (
  id uuid PRIMARY KEY,
  kind text NOT NULL CHECK (kind IN ('booking','pickup')),
  scheduled_at timestamp without time zone NOT NULL,
  guest_name text NOT NULL,
  phone text NOT NULL,
  guests integer,
  note text NOT NULL,
  request_lines jsonb NOT NULL,
  priced_lines jsonb NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted','rejected')),
  created_at timestamptz NOT NULL DEFAULT now(),
  reviewed_at timestamptz,
  reviewed_by uuid
);
ALTER TABLE public.restaurant_online_requests
  ADD COLUMN IF NOT EXISTS booking_number bigint GENERATED ALWAYS AS IDENTITY (START WITH 1001),
  ADD COLUMN IF NOT EXISTS preorder_note text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS preorder_handled_manually boolean NOT NULL DEFAULT false;
CREATE UNIQUE INDEX IF NOT EXISTS restaurant_online_booking_number_idx
  ON public.restaurant_online_requests (booking_number);
ALTER TABLE public.restaurant_online_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.restaurant_online_requests FROM PUBLIC, anon, authenticated;
CREATE INDEX IF NOT EXISTS restaurant_online_requests_queue_idx
  ON public.restaurant_online_requests (status, scheduled_at);
CREATE INDEX IF NOT EXISTS restaurant_online_requests_rate_idx
  ON public.restaurant_online_requests (created_at);
CREATE INDEX IF NOT EXISTS restaurant_online_requests_phone_idx
  ON public.restaurant_online_requests (phone, created_at);

CREATE TABLE IF NOT EXISTS public.restaurant_booking_slots (
  service_day date NOT NULL,
  starts_at time NOT NULL,
  ends_at time NOT NULL,
  tables_2 integer NOT NULL CHECK (tables_2 BETWEEN 0 AND 40),
  tables_4 integer NOT NULL CHECK (tables_4 BETWEEN 0 AND 40),
  tables_6 integer NOT NULL CHECK (tables_6 BETWEEN 0 AND 40),
  tables_8 integer NOT NULL CHECK (tables_8 BETWEEN 0 AND 40),
  is_open boolean NOT NULL,
  PRIMARY KEY (service_day, starts_at),
  CHECK (ends_at > starts_at)
);
ALTER TABLE public.restaurant_booking_slots ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.restaurant_booking_slots FROM PUBLIC,anon,authenticated;

ALTER TABLE public.restaurant_online_requests
  ADD COLUMN IF NOT EXISTS table_seats integer CHECK (table_seats IN (2,4,6,8)),
  ADD COLUMN IF NOT EXISTS preorder_status text CHECK (preorder_status IN ('pending','accepted','rejected')),
  ADD COLUMN IF NOT EXISTS preorder_reviewed_at timestamptz;
CREATE INDEX IF NOT EXISTS restaurant_online_capacity_idx
  ON public.restaurant_online_requests (scheduled_at, table_seats)
  WHERE kind='booking' AND status IN ('pending','accepted') AND table_seats IS NOT NULL;
UPDATE public.restaurant_online_requests r
 SET preorder_status=CASE
   WHEN r.status='rejected' THEN 'rejected'
   WHEN EXISTS (SELECT 1 FROM public.restaurant_bookings b WHERE b.id=r.id AND b.status='arrived') THEN 'accepted'
   ELSE 'pending' END
 WHERE r.kind='booking' AND r.request_lines<>'[]'::jsonb AND r.preorder_status IS NULL;

-- Only online allocations with an active request/booking consume configured online tables.
CREATE OR REPLACE FUNCTION public.restaurant_booking_slot_stock(slot_day date, slot_start time)
RETURNS TABLE(seats integer, total integer, used integer)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
  SELECT capacity.seats, capacity.total, (SELECT count(*)::integer
    FROM public.restaurant_online_requests r
    WHERE r.kind='booking' AND r.table_seats=capacity.seats AND r.scheduled_at=s.service_day+s.starts_at
      AND (r.status='pending' OR (r.status='accepted' AND EXISTS
        (SELECT 1 FROM public.restaurant_bookings b WHERE b.id=r.id AND b.deleted_at IS NULL
         AND b.status IN ('confirmed','arrived'))))
  )
  FROM public.restaurant_booking_slots s
  CROSS JOIN LATERAL (VALUES (2,s.tables_2),(4,s.tables_4),(6,s.tables_6),(8,s.tables_8)) capacity(seats,total)
  WHERE s.service_day=slot_day AND s.starts_at=slot_start;
$$;

CREATE OR REPLACE FUNCTION public.restaurant_booking_availability(requested_day date, party_size integer)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'time',to_char(s.starts_at,'HH24:MI'),
    'available', s.is_open AND EXISTS
      (SELECT 1 FROM public.restaurant_booking_slot_stock(s.service_day,s.starts_at) c
       WHERE c.seats>=party_size AND c.total>c.used)) ORDER BY s.starts_at),'[]'::jsonb)
  FROM public.restaurant_booking_slots s
  WHERE s.service_day=requested_day AND s.service_day+s.starts_at>(now() AT TIME ZONE 'Asia/Taipei')
    AND requested_day<=(now() AT TIME ZONE 'Asia/Taipei')::date+30 AND party_size BETWEEN 1 AND 8;
$$;

CREATE OR REPLACE FUNCTION public.restaurant_booking_slots_staff(requested_day date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF public.restaurant_is_cashier() IS DISTINCT FROM true THEN
    RAISE EXCEPTION '需要櫃台權限' USING ERRCODE='42501';
  END IF;
  RETURN coalesce((SELECT jsonb_agg(to_jsonb(s)||jsonb_build_object('stock',
    (SELECT jsonb_agg(to_jsonb(c) ORDER BY c.seats)
     FROM public.restaurant_booking_slot_stock(s.service_day,s.starts_at) c)) ORDER BY s.starts_at)
    FROM public.restaurant_booking_slots s WHERE s.service_day=requested_day),'[]'::jsonb);
END $$;

CREATE OR REPLACE FUNCTION public.restaurant_booking_slot_save(
  slot_day date, slot_start time, slot_end time, seats_2 integer, seats_4 integer,
  seats_6 integer, seats_8 integer, open_slot boolean
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE local_now timestamp := now() AT TIME ZONE 'Asia/Taipei';
BEGIN
  IF public.restaurant_is_cashier() IS DISTINCT FROM true THEN
    RAISE EXCEPTION '需要櫃台權限' USING ERRCODE='42501';
  END IF;
  IF slot_day IS NULL OR slot_day NOT BETWEEN local_now::date AND local_now::date+30
    OR slot_start IS NULL OR slot_end IS NULL OR slot_end<=slot_start
    OR extract(second FROM slot_start)<>0 OR extract(second FROM slot_end)<>0
    OR open_slot IS NULL OR seats_2 IS NULL OR seats_4 IS NULL OR seats_6 IS NULL OR seats_8 IS NULL
    OR seats_2 NOT BETWEEN 0 AND 40 OR seats_4 NOT BETWEEN 0 AND 40
    OR seats_6 NOT BETWEEN 0 AND 40 OR seats_8 NOT BETWEEN 0 AND 40
    OR (open_slot AND seats_2+seats_4+seats_6+seats_8=0) THEN
    RAISE EXCEPTION '請檢查日期、開始及結束時間、桌數。開放梯次至少需一桌。' USING ERRCODE='22023';
  END IF;
  -- Share the booking lock so capacity edits and concurrent guest submits are serialized.
  PERFORM pg_advisory_xact_lock(hashtextextended('restaurant_online_submit',0));
  IF EXISTS (SELECT 1 FROM public.restaurant_booking_slots s WHERE s.service_day=slot_day
    AND s.starts_at<>slot_start AND s.starts_at<slot_end AND s.ends_at>slot_start
    AND (s.is_open OR EXISTS (SELECT 1 FROM public.restaurant_booking_slot_stock(s.service_day,s.starts_at) c WHERE c.used>0))) THEN
    RAISE EXCEPTION '同一天的用餐梯次不可重疊。' USING ERRCODE='22023';
  END IF;
  IF EXISTS (SELECT 1 FROM public.restaurant_booking_slot_stock(slot_day,slot_start) c
    WHERE c.used > CASE c.seats WHEN 2 THEN seats_2 WHEN 4 THEN seats_4 WHEN 6 THEN seats_6 ELSE seats_8 END) THEN
    RAISE EXCEPTION '桌數不可低於已保留的桌數。若要停止收單，可關閉梯次。' USING ERRCODE='22023';
  END IF;
  INSERT INTO public.restaurant_booking_slots VALUES (slot_day,slot_start,slot_end,seats_2,seats_4,seats_6,seats_8,open_slot)
  ON CONFLICT (service_day,starts_at) DO UPDATE SET ends_at=excluded.ends_at,
    tables_2=excluded.tables_2,tables_4=excluded.tables_4,tables_6=excluded.tables_6,tables_8=excluded.tables_8,is_open=excluded.is_open;
END $$;

REVOKE ALL ON FUNCTION public.restaurant_booking_slot_stock(date,time), public.restaurant_booking_availability(date,integer),
  public.restaurant_booking_slots_staff(date), public.restaurant_booking_slot_save(date,time,time,integer,integer,integer,integer,boolean)
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.restaurant_booking_availability(date,integer) TO anon,authenticated;
GRANT EXECUTE ON FUNCTION public.restaurant_booking_slots_staff(date),
  public.restaurant_booking_slot_save(date,time,time,integer,integer,integer,integer,boolean) TO authenticated;

CREATE OR REPLACE FUNCTION public.restaurant_online_price(request_lines jsonb, pickup_only boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE priced jsonb;
BEGIN
  IF EXISTS (
    SELECT 1 FROM jsonb_array_elements(request_lines) AS item
    LEFT JOIN public.restaurant_menu m ON m.id::text=item->>'menu_id'
    WHERE m.id IS NULL OR m.active IS DISTINCT FROM true
      OR (pickup_only AND (m.name LIKE '%限內用%' OR m.category='內用加點'))
      OR m.sold_out_date=(now() AT TIME ZONE 'Asia/Taipei')::date
  ) THEN
    RAISE EXCEPTION '有餐點無法外帶、已售完或下架，請重新載入菜單後再送出' USING ERRCODE='22023';
  END IF;

  SELECT jsonb_agg(jsonb_build_object('id', m.id, 'name', m.name, 'price', m.price)
    ORDER BY m.id) INTO priced
  FROM public.restaurant_menu m
  WHERE m.id::text IN (SELECT item->>'menu_id' FROM jsonb_array_elements(request_lines) AS item);
  RETURN public.restaurant_snapshot_variants(request_lines, priced);
END $$;

CREATE OR REPLACE FUNCTION public.restaurant_online_submit(
  request_id uuid, request_kind text, requested_day date, requested_time time without time zone,
  contact_name text, contact_phone text, party_size integer, request_note text,
  request_items jsonb, expected_prices jsonb
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
  local_now timestamp := now() AT TIME ZONE 'Asia/Taipei';
  requested_at timestamp := requested_day + requested_time;
  normalized_phone text := regexp_replace(btrim(coalesce(contact_phone,'')), '[[:space:]()-]', '', 'g');
  normalized_name text := btrim(coalesce(contact_name,''));
  normalized_note text := btrim(coalesce(request_note,''));
  raw jsonb := '[]';
  assigned_seats integer;
  previous public.restaurant_online_requests%ROWTYPE;
BEGIN
  IF request_id IS NULL OR request_kind IS NULL OR request_kind NOT IN ('booking','pickup')
    OR requested_at IS NULL OR length(normalized_name) NOT BETWEEN 1 AND 50
    OR normalized_phone !~ '^\+?[0-9]{8,15}$' OR length(normalized_note)>200 THEN
    RAISE EXCEPTION '請確認日期、姓名、電話及備註' USING ERRCODE='22023';
  END IF;
  IF request_kind='booking' AND (party_size IS NULL OR party_size NOT BETWEEN 1 AND 8
    OR request_items IS DISTINCT FROM '[]'::jsonb) THEN
    RAISE EXCEPTION '線上訂位限 1 至 8 位，請先訂位再點餐' USING ERRCODE='22023';
  END IF;
  IF request_kind='pickup' THEN
    party_size := NULL;
    raw := public.restaurant_normalize_variants(request_items)->'raw';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended('restaurant_online_submit',0));
  SELECT * INTO previous FROM public.restaurant_online_requests WHERE id=request_id;
  IF FOUND THEN
    IF (previous.kind,previous.scheduled_at,previous.guest_name,previous.phone,
        previous.guests,previous.note,CASE WHEN previous.kind='booking' THEN '[]'::jsonb ELSE previous.request_lines END)
       IS NOT DISTINCT FROM
       (request_kind,requested_at,normalized_name,normalized_phone,party_size,normalized_note,raw) THEN
      RETURN request_id;
    END IF;
    RAISE EXCEPTION '送單編號已使用，請查詢原申請' USING ERRCODE='22023';
  END IF;

  IF request_kind<>'booking' THEN
    RAISE EXCEPTION '小樂義請先線上訂位，再從訂位進度點餐' USING ERRCODE='22023';
  END IF;
  IF requested_at<=local_now OR requested_day>local_now::date+30 THEN
    RAISE EXCEPTION '請選擇未來 30 天內開放的訂位梯次' USING ERRCODE='22023';
  END IF;
  SELECT c.seats INTO assigned_seats
    FROM public.restaurant_booking_slot_stock(requested_day,requested_time) c
    JOIN public.restaurant_booking_slots s ON s.service_day=requested_day AND s.starts_at=requested_time
    WHERE s.is_open AND c.seats>=party_size AND c.total>c.used
    ORDER BY c.seats LIMIT 1;
  IF assigned_seats IS NULL THEN
    RAISE EXCEPTION '這個時段已滿或未開放，請改選其他時段' USING ERRCODE='22023';
  END IF;
  IF (SELECT count(*) FROM public.restaurant_online_requests
        WHERE phone=normalized_phone AND created_at>now()-interval '15 minutes')>=3
    OR (SELECT count(*) FROM public.restaurant_online_requests
        WHERE created_at>now()-interval '1 minute')>=30
    OR (SELECT count(*) FROM public.restaurant_online_requests
        WHERE status='pending' AND scheduled_at>local_now)>=100 THEN
    RAISE EXCEPTION '目前申請較多，請稍後再試或聯絡店家' USING ERRCODE='P0001';
  END IF;

  INSERT INTO public.restaurant_online_requests
    (id,kind,scheduled_at,guest_name,phone,guests,note,request_lines,priced_lines,table_seats)
  VALUES (request_id,request_kind,requested_at,normalized_name,normalized_phone,party_size,normalized_note,
    '[]','[]',assigned_seats);
  RETURN request_id;
END $$;

CREATE OR REPLACE FUNCTION public.restaurant_online_status(request_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
  SELECT jsonb_build_object('id',r.id,'kind',r.kind,'scheduled_at',CASE WHEN r.status='accepted' AND r.kind='booking' AND b.id IS NOT NULL
      THEN b.booking_date + b.booking_time ELSE r.scheduled_at END,
    'status',CASE
      WHEN r.status='pending' AND r.scheduled_at<=(now() AT TIME ZONE 'Asia/Taipei') THEN 'expired'
      WHEN r.status='accepted' AND r.kind='booking' AND (b.id IS NULL OR b.deleted_at IS NOT NULL) THEN 'cancelled'
      WHEN r.status='accepted' AND r.kind='booking' AND b.status IN ('cancelled','arrived') THEN b.status
      WHEN r.status='accepted' AND r.kind='pickup' AND k.cancelled_at IS NOT NULL THEN 'cancelled'
      WHEN r.status='accepted' AND r.kind='pickup'
        AND EXISTS (SELECT 1 FROM public.restaurant_sales s WHERE s.id=r.id AND s.deleted_at IS NULL) THEN 'paid'
      WHEN r.status='accepted' AND r.kind='pickup' AND k.status IN ('preparing','served') THEN k.status
      ELSE r.status END,
    'guests',coalesce(b.guests,r.guests),'lines',r.priced_lines,
    'booking_number',CASE WHEN r.kind='booking' THEN r.booking_number END,
    'preorder_status',CASE WHEN r.status='rejected' OR (r.status='accepted' AND r.kind='booking'
      AND (b.id IS NULL OR b.deleted_at IS NOT NULL OR b.status='cancelled')) THEN 'rejected'
      ELSE r.preorder_status END,
    'can_preorder',r.kind='booking' AND r.request_lines='[]'::jsonb
      AND ((r.status='pending' AND r.scheduled_at>(now() AT TIME ZONE 'Asia/Taipei'))
        OR (r.status='accepted' AND b.status='confirmed' AND b.deleted_at IS NULL
          AND b.booking_date+b.booking_time>(now() AT TIME ZONE 'Asia/Taipei'))))
  FROM public.restaurant_online_requests r
  LEFT JOIN public.restaurant_bookings b ON b.id=r.id AND r.kind='booking'
  LEFT JOIN public.restaurant_kitchen k ON k.id=r.id AND r.kind='pickup'
  WHERE r.id=request_id;
$$;

CREATE OR REPLACE FUNCTION public.restaurant_online_pending()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF public.restaurant_is_cashier() IS DISTINCT FROM true THEN
    RAISE EXCEPTION '需要櫃台權限' USING ERRCODE='42501';
  END IF;
  RETURN coalesce((SELECT jsonb_agg(to_jsonb(r)-'request_lines'-'reviewed_by' ORDER BY r.scheduled_at)
    FROM (SELECT q.* FROM public.restaurant_online_requests q
          WHERE (q.status='pending' AND q.scheduled_at>now() AT TIME ZONE 'Asia/Taipei')
             OR (q.kind='booking' AND q.status='accepted' AND q.preorder_status='pending'
                 AND EXISTS (SELECT 1 FROM public.restaurant_bookings b WHERE b.id=q.id AND b.status='confirmed'
                    AND b.deleted_at IS NULL AND b.booking_date>=(now() AT TIME ZONE 'Asia/Taipei')::date))
          ORDER BY q.scheduled_at LIMIT 100) r),'[]');
END $$;

CREATE OR REPLACE FUNCTION public.restaurant_online_review(request_id uuid, accept_request boolean, table_name text DEFAULT NULL)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
  request public.restaurant_online_requests%ROWTYPE;
  chosen_status text;
  pickup_note text;
BEGIN
  IF public.restaurant_is_cashier() IS DISTINCT FROM true THEN
    RAISE EXCEPTION '需要櫃台權限' USING ERRCODE='42501';
  END IF;
  IF accept_request IS NULL THEN
    RAISE EXCEPTION '請選擇確認或拒絕' USING ERRCODE='22023';
  END IF;
  SELECT * INTO request FROM public.restaurant_online_requests WHERE id=request_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '查無這筆申請' USING ERRCODE='22023'; END IF;
  chosen_status := CASE WHEN accept_request THEN 'accepted' ELSE 'rejected' END;
  IF request.status=chosen_status THEN RETURN chosen_status; END IF;
  IF request.status<>'pending' THEN RAISE EXCEPTION '其他店員已處理此申請，請重新整理'; END IF;

  IF accept_request THEN
    IF request.scheduled_at<=now() AT TIME ZONE 'Asia/Taipei' THEN
      RAISE EXCEPTION '此申請時段已過，無法確認';
    END IF;
    IF request.kind='booking' THEN
      IF length(coalesce(table_name,''))>20 THEN
        RAISE EXCEPTION '桌號最多 20 字';
      END IF;
      INSERT INTO public.restaurant_bookings
        (id,booking_date,booking_time,guests,guest_name,phone,note,table_label,status)
      VALUES (request.id,request.scheduled_at::date,request.scheduled_at::time,
        request.guests,request.guest_name,request.phone,request.note,nullif(btrim(table_name),''),'confirmed');
    ELSE
      PERFORM 1 FROM public.restaurant_menu m
        WHERE m.id::text IN (SELECT item->>'menu_id' FROM jsonb_array_elements(request.request_lines) AS item)
        ORDER BY m.id FOR SHARE;
      IF public.restaurant_online_price(request.request_lines,true) IS DISTINCT FROM request.priced_lines THEN
        RAISE EXCEPTION '餐點或價格已變更，請聯絡客人並請他重新送單';
      END IF;
      pickup_note := '預約取餐 '||to_char(request.scheduled_at,'MM/DD HH24:MI')
        ||' · '||request.guest_name||' · 外帶單 '||upper(left(request.id::text,8));
      IF request.note<>'' THEN pickup_note := pickup_note||' · '||request.note; END IF;
      PERFORM public.restaurant_send_kitchen_lines(request.id,'外帶','',request.request_lines,pickup_note);
    END IF;
  END IF;

  UPDATE public.restaurant_online_requests SET status=chosen_status,reviewed_at=now(),reviewed_by=auth.uid()
    WHERE id=request.id;
  RETURN chosen_status;
END $$;

-- The UUID authorizes guest access. The short numeric booking number is for display only.
CREATE OR REPLACE FUNCTION public.restaurant_booking_preorder(
  request_id uuid, request_items jsonb, expected_prices jsonb, order_note text
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
  request public.restaurant_online_requests%ROWTYPE;
  booking public.restaurant_bookings%ROWTYPE;
  raw jsonb;
  priced jsonb;
  note_text text := btrim(coalesce(order_note,''));
  local_now timestamp := now() AT TIME ZONE 'Asia/Taipei';
BEGIN
  SELECT * INTO request FROM public.restaurant_online_requests
    WHERE id=request_id AND kind='booking' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '查無這筆線上訂位' USING ERRCODE='22023'; END IF;

  raw := public.restaurant_normalize_variants(request_items)->'raw';
  IF length(note_text)>200 OR jsonb_array_length(raw)>30
    OR (SELECT sum((item->>'qty')::int) FROM jsonb_array_elements(raw) AS item)>50 THEN
    RAISE EXCEPTION '預點餐最多 30 筆品項、50 份餐點及 200 字備註' USING ERRCODE='22023';
  END IF;
  IF request.request_lines<>'[]'::jsonb THEN
    IF request.request_lines=raw AND request.preorder_note=note_text
      AND (SELECT jsonb_object_agg(item->>'menu_id',item->'price')
           FROM jsonb_array_elements(request.priced_lines) AS item)=expected_prices THEN
      RETURN request_id;
    END IF;
    RAISE EXCEPTION '這筆訂位已送出預點餐，如需更改請聯絡店家' USING ERRCODE='22023';
  END IF;

  IF request.status='accepted' THEN
    SELECT * INTO booking FROM public.restaurant_bookings WHERE id=request_id FOR UPDATE;
    IF NOT FOUND OR booking.status<>'confirmed' OR booking.deleted_at IS NOT NULL
      OR booking.booking_date+booking.booking_time<=local_now THEN
      RAISE EXCEPTION '這筆訂位目前無法預點餐' USING ERRCODE='22023';
    END IF;
  ELSIF request.status<>'pending' OR request.scheduled_at<=local_now THEN
    RAISE EXCEPTION '這筆訂位目前無法預點餐' USING ERRCODE='22023';
  END IF;

  PERFORM 1 FROM public.restaurant_menu m
    WHERE m.id::text IN (SELECT item->>'menu_id' FROM jsonb_array_elements(raw) AS item)
    ORDER BY m.id FOR SHARE;
  priced := public.restaurant_online_price(raw,false);
  IF (SELECT jsonb_object_agg(item->>'menu_id',item->'price') FROM jsonb_array_elements(priced) AS item)
     IS DISTINCT FROM expected_prices THEN
    RAISE EXCEPTION '菜單價格已更新，請重新整理確認價格後再送出' USING ERRCODE='22023';
  END IF;
  UPDATE public.restaurant_online_requests SET request_lines=raw,priced_lines=priced,preorder_note=note_text,preorder_status='pending'
    WHERE id=request_id;
  RETURN request_id;
END $$;

CREATE OR REPLACE FUNCTION public.restaurant_booking_preorders(booking_ids uuid[])
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF public.restaurant_is_cashier() IS DISTINCT FROM true THEN
    RAISE EXCEPTION '需要櫃台權限' USING ERRCODE='42501';
  END IF;
  RETURN coalesce((SELECT jsonb_agg(jsonb_build_object(
    'id',r.id,'booking_number',r.booking_number,'lines',r.priced_lines,'note',r.preorder_note,'preorder_status',r.preorder_status,'table_seats',r.table_seats))
    FROM public.restaurant_online_requests r
    WHERE r.kind='booking' AND r.status='accepted' AND r.id=ANY(booking_ids)),'[]');
END $$;

CREATE OR REPLACE FUNCTION public.restaurant_booking_arrive(
  request_id uuid, table_name text DEFAULT NULL, send_preorder boolean DEFAULT true,
  expected_preorder boolean DEFAULT NULL
)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
  request public.restaurant_online_requests%ROWTYPE;
  booking public.restaurant_bookings%ROWTYPE;
  label text;
  kitchen_note text;
BEGIN
  IF public.restaurant_is_cashier() IS DISTINCT FROM true THEN
    RAISE EXCEPTION '需要櫃台權限' USING ERRCODE='42501';
  END IF;
  SELECT * INTO request FROM public.restaurant_online_requests
    WHERE id=request_id AND kind='booking' AND status='accepted' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '請先確認這筆訂位' USING ERRCODE='22023'; END IF;
  SELECT * INTO booking FROM public.restaurant_bookings WHERE id=request_id FOR UPDATE;
  IF NOT FOUND OR booking.deleted_at IS NOT NULL OR booking.status NOT IN ('confirmed','arrived') THEN
    RAISE EXCEPTION '這筆訂位目前無法報到' USING ERRCODE='22023';
  END IF;
  IF booking.status='arrived' THEN RETURN request_id; END IF;
  IF request.preorder_status='pending' THEN
    RAISE EXCEPTION '預點餐尚待確認，請先核對餐點' USING ERRCODE='22023';
  END IF;
  IF expected_preorder IS NOT NULL AND expected_preorder<>(request.preorder_status IS NOT DISTINCT FROM 'accepted') THEN
    RAISE EXCEPTION '客人剛更新預點餐，請關閉視窗並重新整理訂位' USING ERRCODE='22023';
  END IF;
  IF booking.booking_date<>(now() AT TIME ZONE 'Asia/Taipei')::date THEN
    RAISE EXCEPTION '請於訂位當天報到' USING ERRCODE='22023';
  END IF;
  label := upper(btrim(coalesce(table_name,booking.table_label,'')));
  IF send_preorder IS NULL OR length(label)>20
    OR (send_preorder AND request.preorder_status='accepted' AND label='') THEN
    RAISE EXCEPTION '請填寫出餐桌號，最多 20 字' USING ERRCODE='22023';
  END IF;
  IF send_preorder AND request.preorder_status='accepted' THEN
    PERFORM 1 FROM public.restaurant_menu m
      WHERE m.id::text IN (SELECT item->>'menu_id' FROM jsonb_array_elements(request.request_lines) AS item)
      ORDER BY m.id FOR SHARE;
    IF public.restaurant_online_price(request.request_lines,false) IS DISTINCT FROM request.priced_lines THEN
      RAISE EXCEPTION '餐點或價格已變更。請與客人核對後，使用櫃台點餐處理。' USING ERRCODE='22023';
    END IF;
    kitchen_note := '訂位 '||request.booking_number;
    IF request.preorder_note<>'' THEN kitchen_note := kitchen_note||' · '||request.preorder_note; END IF;
    PERFORM public.restaurant_send_kitchen_lines(request.id,'內用',label,request.request_lines,kitchen_note);
  END IF;
  IF NOT send_preorder THEN
    UPDATE public.restaurant_online_requests SET preorder_handled_manually=true WHERE id=request_id;
  END IF;
  UPDATE public.restaurant_bookings SET status='arrived',table_label=nullif(label,'') WHERE id=request_id;
  RETURN request_id;
END $$;

-- Older staff screens may still try to change status directly.
CREATE OR REPLACE FUNCTION public.restaurant_guard_preorder_arrival()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF NEW.status='arrived' AND OLD.status IS DISTINCT FROM 'arrived'
    AND EXISTS (SELECT 1 FROM public.restaurant_online_requests r
                WHERE r.id=NEW.id AND r.kind='booking' AND r.preorder_status IN ('pending','accepted')
                  AND NOT r.preorder_handled_manually)
    AND NOT EXISTS (SELECT 1 FROM public.restaurant_kitchen k WHERE k.id=NEW.id) THEN
    RAISE EXCEPTION '這筆有預點餐，請使用「報到並送廚房」' USING ERRCODE='22023';
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS restaurant_guard_preorder_arrival ON public.restaurant_bookings;
CREATE TRIGGER restaurant_guard_preorder_arrival BEFORE UPDATE OF status ON public.restaurant_bookings
  FOR EACH ROW EXECUTE FUNCTION public.restaurant_guard_preorder_arrival();

REVOKE ALL ON FUNCTION public.restaurant_booking_preorder(uuid,jsonb,jsonb,text),
  public.restaurant_booking_preorders(uuid[]), public.restaurant_booking_arrive(uuid,text,boolean,boolean),
  public.restaurant_guard_preorder_arrival() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.restaurant_booking_preorder(uuid,jsonb,jsonb,text) TO anon,authenticated;
GRANT EXECUTE ON FUNCTION public.restaurant_booking_preorders(uuid[]),
  public.restaurant_booking_arrive(uuid,text,boolean,boolean) TO authenticated;

REVOKE ALL ON FUNCTION public.restaurant_online_price(jsonb,boolean) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.restaurant_online_submit(uuid,text,date,time without time zone,text,text,integer,text,jsonb,jsonb),
  public.restaurant_online_status(uuid), public.restaurant_online_pending(),
  public.restaurant_online_review(uuid,boolean,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.restaurant_online_submit(uuid,text,date,time without time zone,text,text,integer,text,jsonb,jsonb),
  public.restaurant_online_status(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.restaurant_online_pending(),
  public.restaurant_online_review(uuid,boolean,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.restaurant_preorder_review(request_id uuid, accept_order boolean)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
  request public.restaurant_online_requests%ROWTYPE;
  booking public.restaurant_bookings%ROWTYPE;
  chosen text := CASE WHEN accept_order THEN 'accepted' ELSE 'rejected' END;
BEGIN
  IF public.restaurant_is_cashier() IS DISTINCT FROM true THEN
    RAISE EXCEPTION '需要櫃台權限' USING ERRCODE='42501';
  END IF;
  IF accept_order IS NULL THEN RAISE EXCEPTION '請選擇確認或拒絕餐點' USING ERRCODE='22023'; END IF;

  SELECT * INTO request FROM public.restaurant_online_requests
    WHERE id=request_id AND kind='booking' AND status='accepted' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '請先確認訂位' USING ERRCODE='22023'; END IF;
  IF request.preorder_status=chosen THEN RETURN chosen; END IF;
  IF request.preorder_status IS DISTINCT FROM 'pending' THEN
    RAISE EXCEPTION '這筆餐點已處理，請重新整理' USING ERRCODE='22023';
  END IF;
  SELECT * INTO booking FROM public.restaurant_bookings WHERE id=request_id FOR UPDATE;
  IF NOT FOUND OR booking.status<>'confirmed' OR booking.deleted_at IS NOT NULL
    OR booking.booking_date<(now() AT TIME ZONE 'Asia/Taipei')::date THEN
    RAISE EXCEPTION '此訂位已取消、到店或逾期' USING ERRCODE='22023';
  END IF;

  IF accept_order THEN
    PERFORM 1 FROM public.restaurant_menu m WHERE m.id::text IN
      (SELECT item->>'menu_id' FROM jsonb_array_elements(request.request_lines) AS item) ORDER BY m.id FOR SHARE;
    IF public.restaurant_online_price(request.request_lines,false) IS DISTINCT FROM request.priced_lines THEN
      RAISE EXCEPTION '餐點或價格已變更，請聯絡客人確認後由櫃台處理。' USING ERRCODE='22023';
    END IF;
  END IF;
  UPDATE public.restaurant_online_requests SET preorder_status=chosen,preorder_reviewed_at=now() WHERE id=request_id;
  RETURN chosen;
END $$;

-- A managed booking allocates a table in its original service block.
CREATE OR REPLACE FUNCTION public.restaurant_guard_online_slot()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.restaurant_online_requests r WHERE r.id=OLD.id AND r.table_seats IS NOT NULL)
    AND ((NEW.booking_date,NEW.booking_time,NEW.guests) IS DISTINCT FROM (OLD.booking_date,OLD.booking_time,OLD.guests)
      OR (OLD.status NOT IN ('confirmed','arrived') AND NEW.status IN ('confirmed','arrived'))
      OR (OLD.deleted_at IS NOT NULL AND NEW.deleted_at IS NULL)) THEN
    RAISE EXCEPTION '這筆線上訂位已保留桌次。改期或變更人數前，請與客人確認新時段，再取消原單。' USING ERRCODE='22023';
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS restaurant_guard_online_slot ON public.restaurant_bookings;
CREATE TRIGGER restaurant_guard_online_slot BEFORE UPDATE ON public.restaurant_bookings
  FOR EACH ROW EXECUTE FUNCTION public.restaurant_guard_online_slot();

REVOKE ALL ON FUNCTION public.restaurant_preorder_review(uuid,boolean),
  public.restaurant_guard_online_slot() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.restaurant_preorder_review(uuid,boolean) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
