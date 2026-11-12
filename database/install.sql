-- Install once on a new Supabase project. No source restaurant data.
BEGIN;

-- First installation. Run only in the new restaurant's Supabase project.

CREATE TABLE public.restaurant_staff (
 user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
 role text NOT NULL CONSTRAINT restaurant_staff_role_check CHECK (role IN ('owner','staff'))
);
CREATE TABLE public.restaurant_menu (
 id text PRIMARY KEY CHECK(length(id) BETWEEN 1 AND 150), name text NOT NULL,
 category text NOT NULL, price integer NOT NULL CHECK(price BETWEEN 0 AND 1000000),
 active boolean NOT NULL DEFAULT true, image_path text
);
CREATE TABLE public.restaurant_bookings (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), booking_date date NOT NULL, booking_time time NOT NULL,
 guests integer NOT NULL CHECK(guests BETWEEN 1 AND 8),
 guest_name text NOT NULL CHECK(length(btrim(guest_name)) BETWEEN 1 AND 50),
 phone text NOT NULL CHECK(phone ~ '^\+?[0-9]{8,15}$'),
 note text NOT NULL DEFAULT '' CHECK(length(note)<=200),
 status text NOT NULL DEFAULT 'confirmed' CHECK(status IN ('confirmed','arrived','cancelled','no_show')),
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.restaurant_sales (
 id uuid PRIMARY KEY, service text NOT NULL CHECK(service IN ('內用','外帶')),
 table_label text NOT NULL CHECK(length(table_label)<=20), payment text NOT NULL,
 total integer NOT NULL CHECK(total>=0), created_at timestamptz NOT NULL DEFAULT now(),
 created_by uuid NOT NULL, request_items jsonb NOT NULL,
 CHECK(service='外帶' OR length(btrim(table_label))>0)
);
CREATE TABLE public.restaurant_sale_items (
 sale_id uuid NOT NULL REFERENCES public.restaurant_sales(id), menu_id text NOT NULL REFERENCES public.restaurant_menu(id),
 name text NOT NULL, unit_price integer NOT NULL CHECK(unit_price>=0),
 quantity integer NOT NULL CHECK(quantity BETWEEN 1 AND 99), PRIMARY KEY(sale_id,menu_id)
);
CREATE INDEX ON public.restaurant_bookings(booking_date,booking_time);
CREATE INDEX ON public.restaurant_sales(created_at);

CREATE FUNCTION public.restaurant_has_role(expected text DEFAULT NULL) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT EXISTS(SELECT 1 FROM public.restaurant_staff s WHERE s.user_id=auth.uid() AND (expected IS NULL OR s.role=expected));
$$;
REVOKE ALL ON FUNCTION public.restaurant_has_role(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.restaurant_has_role(text) TO authenticated;

ALTER TABLE public.restaurant_staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.restaurant_menu ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.restaurant_bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.restaurant_sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.restaurant_sale_items ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.restaurant_staff,public.restaurant_menu,public.restaurant_bookings,public.restaurant_sales,public.restaurant_sale_items FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.restaurant_staff,public.restaurant_menu,public.restaurant_bookings,public.restaurant_sales,public.restaurant_sale_items TO authenticated;
GRANT INSERT(id,name,category,price,active,image_path), UPDATE(name,category,price,active,image_path) ON public.restaurant_menu TO authenticated;
GRANT INSERT(booking_date,booking_time,guests,guest_name,phone,note),UPDATE(status) ON public.restaurant_bookings TO authenticated;
CREATE POLICY restaurant_staff_self ON public.restaurant_staff FOR SELECT TO authenticated USING(user_id=auth.uid());
CREATE POLICY restaurant_menu_member ON public.restaurant_menu FOR SELECT TO authenticated USING(public.restaurant_has_role());
CREATE POLICY restaurant_menu_add ON public.restaurant_menu FOR INSERT TO authenticated WITH CHECK(public.restaurant_has_role('owner'));
CREATE POLICY restaurant_menu_edit ON public.restaurant_menu FOR UPDATE TO authenticated USING(public.restaurant_has_role('owner')) WITH CHECK(public.restaurant_has_role('owner'));
CREATE POLICY restaurant_booking_read ON public.restaurant_bookings FOR SELECT TO authenticated USING(public.restaurant_has_role());
CREATE POLICY restaurant_booking_add ON public.restaurant_bookings FOR INSERT TO authenticated WITH CHECK(public.restaurant_has_role());
CREATE POLICY restaurant_booking_edit ON public.restaurant_bookings FOR UPDATE TO authenticated USING(public.restaurant_has_role()) WITH CHECK(public.restaurant_has_role());
CREATE POLICY restaurant_sales_read ON public.restaurant_sales FOR SELECT TO authenticated USING(public.restaurant_has_role());
CREATE POLICY restaurant_sale_items_read ON public.restaurant_sale_items FOR SELECT TO authenticated USING(public.restaurant_has_role());

INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
VALUES('restaurant-menu-images','restaurant-menu-images',true,5242880,ARRAY['image/jpeg','image/png','image/webp']);
CREATE POLICY restaurant_menu_image_add ON storage.objects FOR INSERT TO authenticated
 WITH CHECK(bucket_id='restaurant-menu-images' AND public.restaurant_has_role('owner'));

CREATE FUNCTION public.restaurant_checkout(sale_id uuid,service_mode text,table_name text,payment_mode text,items jsonb)
RETURNS public.restaurant_sales LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
 label text:=CASE WHEN service_mode='內用' THEN btrim(coalesce(table_name,'')) ELSE '' END;
 sale public.restaurant_sales;
 total_amount integer:=0;
 priced jsonb:='[]';
 line record;
BEGIN
 IF NOT (public.restaurant_has_role('owner') OR public.restaurant_has_role('staff')) THEN
  RAISE EXCEPTION '需要櫃台權限' USING ERRCODE='42501';
 END IF;
 IF sale_id IS NULL OR service_mode IS NULL OR service_mode NOT IN ('內用','外帶') OR length(label)>20 OR
  (service_mode='內用' AND label='') OR payment_mode IS NULL OR length(btrim(payment_mode)) NOT BETWEEN 1 AND 20 OR
  jsonb_typeof(items) IS DISTINCT FROM 'object' OR items='{}'::jsonb THEN
  RAISE EXCEPTION '請確認桌號、付款方式及餐點' USING ERRCODE='22023';
 END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(sale_id::text,0));
 SELECT * INTO sale FROM public.restaurant_sales s WHERE s.id=sale_id;
 IF FOUND THEN
  IF sale.request_items IS DISTINCT FROM items OR sale.service IS DISTINCT FROM service_mode OR
   sale.payment IS DISTINCT FROM payment_mode OR sale.table_label IS DISTINCT FROM label THEN
   RAISE EXCEPTION '結帳單編號已使用，請核對原單' USING ERRCODE='23505';
  END IF;
  RETURN sale;
 END IF;
 FOR line IN SELECT e.key,e.value,m.name,m.price FROM jsonb_each(items)e
  LEFT JOIN public.restaurant_menu m ON m.id=e.key AND m.active
 LOOP
  IF line.name IS NULL OR jsonb_typeof(line.value) IS DISTINCT FROM 'number' OR line.value::text !~ '^[1-9][0-9]?$' THEN
   RAISE EXCEPTION '餐點已下架或數量無效' USING ERRCODE='22023';
  END IF;
  priced:=priced||jsonb_build_array(jsonb_build_object('id',line.key,'name',line.name,'price',line.price,'qty',line.value));
  total_amount:=total_amount+line.price*(line.value::text)::int;
 END LOOP;
 INSERT INTO public.restaurant_sales(id,service,table_label,payment,total,created_by,request_items)
 VALUES(sale_id,service_mode,label,payment_mode,total_amount,auth.uid(),items) RETURNING * INTO sale;
 INSERT INTO public.restaurant_sale_items(sale_id,menu_id,name,unit_price,quantity)
 SELECT sale_id,x.id,x.name,x.price,x.qty FROM jsonb_to_recordset(priced)x(id text,name text,price int,qty int);
 RETURN sale;
END;
$$;
REVOKE ALL ON FUNCTION public.restaurant_checkout(uuid,text,text,text,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.restaurant_checkout(uuid,text,text,text,jsonb) TO authenticated;

-- Original migration 2

ALTER TABLE public.restaurant_bookings ADD COLUMN table_label text CHECK (length(table_label)<=20);
GRANT INSERT (table_label), UPDATE (table_label) ON public.restaurant_bookings TO authenticated;

ALTER TABLE public.restaurant_staff DROP CONSTRAINT restaurant_staff_role_check;
ALTER TABLE public.restaurant_staff ADD CONSTRAINT restaurant_staff_role_check CHECK (role IN ('owner','staff','kitchen'));
CREATE FUNCTION public.restaurant_is_cashier() RETURNS boolean LANGUAGE sql STABLE SET search_path = ''
AS $$ SELECT public.restaurant_has_role('owner') OR public.restaurant_has_role('staff') $$;
REVOKE ALL ON FUNCTION public.restaurant_is_cashier() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.restaurant_is_cashier() TO authenticated;
ALTER POLICY restaurant_booking_read ON public.restaurant_bookings USING ((SELECT public.restaurant_is_cashier()));
ALTER POLICY restaurant_booking_add ON public.restaurant_bookings WITH CHECK ((SELECT public.restaurant_is_cashier()));
ALTER POLICY restaurant_booking_edit ON public.restaurant_bookings USING ((SELECT public.restaurant_is_cashier())) WITH CHECK ((SELECT public.restaurant_is_cashier()));
ALTER POLICY restaurant_sales_read ON public.restaurant_sales USING ((SELECT public.restaurant_is_cashier()));
ALTER POLICY restaurant_sale_items_read ON public.restaurant_sale_items USING ((SELECT public.restaurant_is_cashier()));

GRANT SELECT (id,name,category,price,image_path,active) ON public.restaurant_menu TO anon;
CREATE POLICY restaurant_public_menu ON public.restaurant_menu FOR SELECT TO anon, authenticated USING (active);
-- 只將指定的菜單照片儲存桶開放讀取，既有寫入政策仍限 owner。
UPDATE storage.buckets SET public=true WHERE id='restaurant-menu-images';

CREATE TABLE public.restaurant_kitchen (
  id uuid PRIMARY KEY,
  service text NOT NULL CHECK(service IN ('內用','外帶')),
  table_label text NOT NULL CHECK(length(table_label)<=20),
  items jsonb NOT NULL,
  lines jsonb NOT NULL,
  status text NOT NULL DEFAULT 'queued' CHECK(status IN ('queued','preparing','served')),
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK(service='外帶' OR length(btrim(table_label))>0)
);
ALTER TABLE public.restaurant_kitchen ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.restaurant_kitchen FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.restaurant_kitchen TO authenticated;
GRANT UPDATE (status) ON public.restaurant_kitchen TO authenticated;
CREATE POLICY restaurant_kitchen_read ON public.restaurant_kitchen FOR SELECT TO authenticated
  USING ((SELECT public.restaurant_has_role()));
CREATE POLICY restaurant_kitchen_update ON public.restaurant_kitchen FOR UPDATE TO authenticated
  USING ((SELECT public.restaurant_has_role('owner') OR public.restaurant_has_role('kitchen') OR public.restaurant_has_role('staff')))
  WITH CHECK ((SELECT public.restaurant_has_role()));

CREATE FUNCTION public.restaurant_send_kitchen(ticket_id uuid, mode text, table_name text, requested jsonb)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  label text := CASE WHEN mode='內用' THEN btrim(coalesce(table_name,'')) ELSE '' END;
  ticket public.restaurant_kitchen;
  item record;
  snapshot jsonb := '[]'::jsonb;
BEGIN
  IF NOT public.restaurant_is_cashier() THEN RAISE EXCEPTION '需要櫃台權限' USING ERRCODE='42501'; END IF;
  IF ticket_id IS NULL OR jsonb_typeof(requested) IS DISTINCT FROM 'object' OR requested='{}'::jsonb THEN
    RAISE EXCEPTION '請選擇餐點' USING ERRCODE='22023';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(ticket_id::text,0));
  SELECT * INTO ticket FROM public.restaurant_kitchen WHERE id=ticket_id;
  IF FOUND THEN
    IF ticket.service IS DISTINCT FROM mode OR ticket.table_label <> label OR ticket.items <> requested THEN
      RAISE EXCEPTION '出餐單編號已使用' USING ERRCODE='22023';
    END IF;
    RETURN ticket_id;
  END IF;
  FOR item IN SELECT e.key,e.value,m.name FROM jsonb_each(requested) e
    LEFT JOIN public.restaurant_menu m ON m.id=e.key AND m.active
  LOOP
    IF item.name IS NULL OR jsonb_typeof(item.value)<>'number' OR item.value::text !~ '^[1-9][0-9]?$' THEN
      RAISE EXCEPTION '餐點已下架或數量無效' USING ERRCODE='22023';
    END IF;
    snapshot := snapshot || jsonb_build_array(jsonb_build_object('name',item.name,'qty',(item.value::text)::int));
  END LOOP;
  INSERT INTO public.restaurant_kitchen(id,service,table_label,items,lines)
    VALUES(ticket_id,mode,label,requested,snapshot);
  RETURN ticket_id;
END; $$;
REVOKE ALL ON FUNCTION public.restaurant_send_kitchen(uuid,text,text,jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.restaurant_send_kitchen(uuid,text,text,jsonb) TO authenticated;

-- 保留原結帳函式的交易防重與價格快照，並在入口檢查櫃台身分及出餐單一致性。
ALTER FUNCTION public.restaurant_checkout(uuid,text,text,text,jsonb) RENAME TO restaurant_checkout_v1;
REVOKE EXECUTE ON FUNCTION public.restaurant_checkout_v1(uuid,text,text,text,jsonb) FROM PUBLIC, anon, authenticated;
CREATE FUNCTION public.restaurant_checkout(sale_id uuid,service_mode text,table_name text,payment_mode text,items jsonb)
RETURNS public.restaurant_sales LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE ticket public.restaurant_kitchen;
BEGIN
  IF NOT public.restaurant_is_cashier() THEN RAISE EXCEPTION '需要櫃台權限' USING ERRCODE='42501'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(sale_id::text,0));
  SELECT * INTO ticket FROM public.restaurant_kitchen WHERE id=sale_id;
  IF FOUND AND (ticket.service IS DISTINCT FROM service_mode OR ticket.items IS DISTINCT FROM items OR
    ticket.table_label IS DISTINCT FROM CASE WHEN service_mode='內用' THEN btrim(coalesce(table_name,'')) ELSE '' END) THEN
    RAISE EXCEPTION '餐點或桌號與已送出的出餐單不符' USING ERRCODE='22023';
  END IF;
  RETURN public.restaurant_checkout_v1(sale_id,service_mode,table_name,payment_mode,items);
END; $$;
REVOKE ALL ON FUNCTION public.restaurant_checkout(uuid,text,text,text,jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.restaurant_checkout(uuid,text,text,text,jsonb) TO authenticated;

CREATE FUNCTION public.restaurant_revenue(grain text, reference_date date)
RETURNS TABLE(orders bigint, revenue bigint) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  period_start timestamp;
  period_end timestamp;
BEGIN
  IF NOT public.restaurant_has_role('owner') THEN RAISE EXCEPTION '需要管理者權限' USING ERRCODE='42501'; END IF;
  IF grain IS NULL OR grain NOT IN ('day','month','year') OR reference_date IS NULL THEN
    RAISE EXCEPTION '請選擇統計期間' USING ERRCODE='22023';
  END IF;
  period_start:=date_trunc(grain,reference_date::timestamp);
  period_end:=period_start + CASE grain WHEN 'day' THEN interval '1 day' WHEN 'month' THEN interval '1 month' ELSE interval '1 year' END;
  RETURN QUERY SELECT count(*),coalesce(sum(s.total),0) FROM public.restaurant_sales s
    WHERE s.created_at>=period_start AT TIME ZONE 'Asia/Taipei' AND s.created_at<period_end AT TIME ZONE 'Asia/Taipei';
END; $$;
REVOKE ALL ON FUNCTION public.restaurant_revenue(text,date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.restaurant_revenue(text,date) TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.restaurant_staff TO service_role;
CREATE FUNCTION public.restaurant_find_auth_user(target_email text)
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT id FROM auth.users WHERE lower(email)=lower(target_email) LIMIT 1
$$;
CREATE FUNCTION public.restaurant_set_staff_role(target_id uuid,target_role text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF target_role IS NULL OR target_role NOT IN ('staff','kitchen') THEN RAISE EXCEPTION '員工角色不正確'; END IF;
  INSERT INTO public.restaurant_staff(user_id,role) VALUES(target_id,target_role)
  ON CONFLICT(user_id) DO UPDATE SET role=excluded.role WHERE restaurant_staff.role<>'owner';
  IF NOT FOUND THEN RAISE EXCEPTION '此帳號已是管理者'; END IF;
END; $$;
REVOKE ALL ON FUNCTION public.restaurant_find_auth_user(text),public.restaurant_set_staff_role(uuid,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.restaurant_find_auth_user(text),public.restaurant_set_staff_role(uuid,text) TO service_role;

-- Original migration 2-1
-- 在 linglan-v2.sql 成功執行後使用。


CREATE FUNCTION public.restaurant_lock_table_ticket() RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF NEW.service='內用' THEN
    NEW.table_label:=upper(btrim(NEW.table_label));
    PERFORM pg_advisory_xact_lock(hashtextextended('linglan:table:'||NEW.table_label,0));
    IF EXISTS(SELECT 1 FROM public.restaurant_kitchen k WHERE k.service='內用'
       AND upper(btrim(k.table_label))=NEW.table_label
       AND NOT EXISTS(SELECT 1 FROM public.restaurant_sales s WHERE s.id=k.id)) THEN
      RAISE EXCEPTION '此桌已有待結帳單，請從待結帳清單叫回原單' USING ERRCODE='23505';
    END IF;
  END IF;
  SELECT jsonb_agg(jsonb_build_object('id',m.id,'name',m.name,'price',m.price,'qty',(e.value::text)::int))
  INTO NEW.lines FROM jsonb_each(NEW.items) e JOIN public.restaurant_menu m ON m.id=e.key;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.restaurant_lock_table_ticket() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER restaurant_lock_table_ticket BEFORE INSERT ON public.restaurant_kitchen
FOR EACH ROW EXECUTE FUNCTION public.restaurant_lock_table_ticket();

-- 新單保留送單當時的單價。舊版已送廚房的單尚無單價快照，叫回時使用現有菜單價格。
CREATE FUNCTION public.restaurant_ticket_lines(ticket public.restaurant_kitchen)
RETURNS jsonb LANGUAGE sql STABLE SET search_path = '' AS $$
  SELECT CASE WHEN (ticket.lines->0) ? 'price' THEN ticket.lines
    ELSE (SELECT jsonb_agg(jsonb_build_object('id',m.id,'name',m.name,'price',m.price,'qty',(e.value::text)::int))
      FROM jsonb_each(ticket.items) e JOIN public.restaurant_menu m ON m.id=e.key) END
$$;
REVOKE ALL ON FUNCTION public.restaurant_ticket_lines(public.restaurant_kitchen) FROM PUBLIC, anon, authenticated;

CREATE FUNCTION public.restaurant_open_tables()
RETURNS TABLE(id uuid,service text,table_label text,status text,created_at timestamptz,lines jsonb)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT k.id,k.service,k.table_label,k.status,k.created_at,public.restaurant_ticket_lines(k)
  FROM public.restaurant_kitchen k
  WHERE public.restaurant_is_cashier()
    AND NOT EXISTS (SELECT 1 FROM public.restaurant_sales s WHERE s.id=k.id)
  ORDER BY k.created_at
$$;
REVOKE ALL ON FUNCTION public.restaurant_open_tables() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.restaurant_open_tables() TO authenticated;

CREATE OR REPLACE FUNCTION public.restaurant_checkout(sale_id uuid,service_mode text,table_name text,payment_mode text,items jsonb)
RETURNS public.restaurant_sales LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  ticket public.restaurant_kitchen;
  result public.restaurant_sales;
  snapshot jsonb;
  amount integer;
  label text := CASE WHEN service_mode='內用' THEN btrim(coalesce(table_name,'')) ELSE '' END;
BEGIN
  IF NOT public.restaurant_is_cashier() THEN RAISE EXCEPTION '需要櫃台權限' USING ERRCODE='42501'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(sale_id::text,0));
  SELECT * INTO ticket FROM public.restaurant_kitchen k WHERE k.id=sale_id;
  IF NOT FOUND THEN
    IF service_mode='內用' THEN
      PERFORM pg_advisory_xact_lock(hashtextextended('linglan:table:'||upper(label),0));
      IF EXISTS(SELECT 1 FROM public.restaurant_kitchen k WHERE k.service='內用'
         AND upper(btrim(k.table_label))=upper(label)
         AND NOT EXISTS(SELECT 1 FROM public.restaurant_sales s WHERE s.id=k.id)) THEN
        RAISE EXCEPTION '此桌已有待結帳單，請從待結帳清單叫回原單' USING ERRCODE='23505';
      END IF;
    END IF;
    RETURN public.restaurant_checkout_v1(sale_id,service_mode,table_name,payment_mode,items);
  END IF;
  IF ticket.service IS DISTINCT FROM service_mode OR ticket.items IS DISTINCT FROM items
     OR upper(ticket.table_label) IS DISTINCT FROM upper(label) THEN
    RAISE EXCEPTION '餐點或桌號與已送出的出餐單不符' USING ERRCODE='22023';
  END IF;
  SELECT * INTO result FROM public.restaurant_sales s WHERE s.id=sale_id;
  IF FOUND THEN
    IF result.payment IS DISTINCT FROM payment_mode THEN
      RAISE EXCEPTION '此桌已結帳，付款方式為 %',result.payment USING ERRCODE='23505';
    END IF;
    RETURN result;
  END IF;
  snapshot:=public.restaurant_ticket_lines(ticket);
  SELECT sum(x.price*x.qty) INTO amount FROM jsonb_to_recordset(snapshot) x(price integer,qty integer);
  IF amount IS NULL THEN RAISE EXCEPTION '待結帳單缺少餐點資料' USING ERRCODE='22023'; END IF;
  INSERT INTO public.restaurant_sales(id,service,table_label,payment,total,created_by,request_items)
  VALUES(sale_id,ticket.service,ticket.table_label,payment_mode,amount,auth.uid(),ticket.items)
  RETURNING * INTO result;
  INSERT INTO public.restaurant_sale_items(sale_id,menu_id,name,unit_price,quantity)
  SELECT sale_id,x.id,x.name,x.price,x.qty
  FROM jsonb_to_recordset(snapshot) x(id text,name text,price integer,qty integer);
  RETURN result;
END;
$$;
CREATE OR REPLACE FUNCTION public.restaurant_send_kitchen(ticket_id uuid, mode text, table_name text, requested jsonb)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  label text := CASE WHEN mode='內用' THEN btrim(coalesce(table_name,'')) ELSE '' END;
  ticket public.restaurant_kitchen;
  item record;
  snapshot jsonb := '[]'::jsonb;
BEGIN
  IF NOT public.restaurant_is_cashier() THEN RAISE EXCEPTION '需要櫃台權限' USING ERRCODE='42501'; END IF;
  IF ticket_id IS NULL OR jsonb_typeof(requested) IS DISTINCT FROM 'object' OR requested='{}'::jsonb THEN
    RAISE EXCEPTION '請選擇餐點' USING ERRCODE='22023';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(ticket_id::text,0));
  SELECT * INTO ticket FROM public.restaurant_kitchen WHERE id=ticket_id;
  IF FOUND THEN
    IF ticket.service IS DISTINCT FROM mode OR upper(ticket.table_label) <> upper(label) OR ticket.items <> requested THEN
      RAISE EXCEPTION '出餐單編號已使用' USING ERRCODE='22023';
    END IF;
    RETURN ticket_id;
  END IF;
  FOR item IN SELECT e.key,e.value,m.name FROM jsonb_each(requested) e
    LEFT JOIN public.restaurant_menu m ON m.id=e.key AND m.active
  LOOP
    IF item.name IS NULL OR jsonb_typeof(item.value)<>'number' OR item.value::text !~ '^[1-9][0-9]?$' THEN
      RAISE EXCEPTION '餐點已下架或數量無效' USING ERRCODE='22023';
    END IF;
    snapshot := snapshot || jsonb_build_array(jsonb_build_object('name',item.name,'qty',(item.value::text)::int));
  END LOOP;
  INSERT INTO public.restaurant_kitchen(id,service,table_label,items,lines)
    VALUES(ticket_id,mode,label,requested,snapshot);
  RETURN ticket_id;
END; $$;

-- Original migration 2-4

ALTER TABLE public.restaurant_bookings ADD COLUMN IF NOT EXISTS deleted_at timestamptz;
ALTER TABLE public.restaurant_sales ADD COLUMN IF NOT EXISTS deleted_at timestamptz;
CREATE TABLE IF NOT EXISTS public.restaurant_changes (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 target text NOT NULL, target_id uuid NOT NULL, action text NOT NULL,
 actor uuid NOT NULL, changed_at timestamptz NOT NULL DEFAULT now(),
 before_data jsonb NOT NULL, after_data jsonb NOT NULL
);
ALTER TABLE public.restaurant_changes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.restaurant_changes FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.restaurant_changes TO authenticated;
CREATE POLICY restaurant_changes_owner ON public.restaurant_changes FOR SELECT TO authenticated
 USING ((SELECT public.restaurant_has_role('owner')));

CREATE OR REPLACE FUNCTION public.restaurant_edit_booking(
 booking_id uuid, expected jsonb, changes jsonb, remove_booking boolean DEFAULT false
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE before_row public.restaurant_bookings; after_row public.restaurant_bookings;
BEGIN
 IF NOT public.restaurant_is_cashier() THEN RAISE EXCEPTION '需要櫃台權限' USING ERRCODE='42501'; END IF;
 SELECT * INTO before_row FROM public.restaurant_bookings WHERE id=booking_id FOR UPDATE;
 IF NOT FOUND OR before_row.deleted_at IS NOT NULL THEN RAISE EXCEPTION '訂位已刪除，請重新整理'; END IF;
 IF expected IS DISTINCT FROM jsonb_build_object(
   'booking_date',before_row.booking_date,'booking_time',before_row.booking_time,
   'guests',before_row.guests,'guest_name',before_row.guest_name,'phone',before_row.phone,
   'note',before_row.note,'status',before_row.status,'table_label',before_row.table_label) THEN
   RAISE EXCEPTION '另一位人員已更新訂位，請重新整理後再修改' USING ERRCODE='40001';
 END IF;
 IF remove_booking IS TRUE THEN
   UPDATE public.restaurant_bookings SET deleted_at=now() WHERE id=booking_id RETURNING * INTO after_row;
 ELSE
   IF jsonb_typeof(changes) IS DISTINCT FROM 'object' OR NOT changes ?& ARRAY['booking_date','booking_time','guests','guest_name','phone','note','status','table_label'] THEN
     RAISE EXCEPTION '訂位欄位不完整';
   END IF;
   UPDATE public.restaurant_bookings SET
     booking_date=(changes->>'booking_date')::date,booking_time=(changes->>'booking_time')::time,
     guests=(changes->>'guests')::integer,guest_name=btrim(changes->>'guest_name'),
     phone=btrim(changes->>'phone'),note=coalesce(changes->>'note',''),
     status=changes->>'status',table_label=nullif(btrim(changes->>'table_label'),'')
   WHERE id=booking_id RETURNING * INTO after_row;
 END IF;
 INSERT INTO public.restaurant_changes(target,target_id,action,actor,before_data,after_data)
 VALUES('booking',booking_id,CASE WHEN remove_booking THEN 'delete' ELSE 'edit' END,auth.uid(),to_jsonb(before_row),to_jsonb(after_row));
END;
$$;
REVOKE ALL ON FUNCTION public.restaurant_edit_booking(uuid,jsonb,jsonb,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.restaurant_edit_booking(uuid,jsonb,jsonb,boolean) TO authenticated;

CREATE OR REPLACE FUNCTION public.restaurant_edit_sale(
 sale_id uuid, expected jsonb, changes jsonb, remove_sale boolean DEFAULT false
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
 before_row public.restaurant_sales; after_row public.restaurant_sales;
 old_lines jsonb; new_lines jsonb; item jsonb; amount integer:=0; normalized jsonb:='{}'::jsonb;
BEGIN
 IF NOT public.restaurant_has_role('owner') THEN RAISE EXCEPTION '需要管理者權限' USING ERRCODE='42501'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(sale_id::text,0));
 SELECT * INTO before_row FROM public.restaurant_sales s WHERE s.id=sale_id FOR UPDATE;
 IF NOT FOUND OR before_row.deleted_at IS NOT NULL THEN RAISE EXCEPTION '交易已刪除，請重新查詢'; END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('menu_id',i.menu_id,'name',i.name,'unit_price',i.unit_price,'quantity',i.quantity) ORDER BY i.menu_id COLLATE "C"),'[]'::jsonb)
 INTO old_lines FROM public.restaurant_sale_items i WHERE i.sale_id=restaurant_edit_sale.sale_id;
 IF expected IS DISTINCT FROM jsonb_build_object('service',before_row.service,'table_label',before_row.table_label,
   'payment',before_row.payment,'total',before_row.total,'lines',old_lines) THEN
   RAISE EXCEPTION '交易已被其他人更新，請重新查詢後再修改' USING ERRCODE='40001';
 END IF;
 IF remove_sale IS TRUE THEN
   UPDATE public.restaurant_sales s SET deleted_at=now() WHERE s.id=sale_id RETURNING * INTO after_row;
   new_lines:=old_lines;
 ELSE
   IF jsonb_typeof(changes) IS DISTINCT FROM 'object' OR NOT changes ?& ARRAY['service','table_label','payment','lines']
     OR jsonb_typeof(changes->'lines') IS DISTINCT FROM 'array' OR jsonb_array_length(changes->'lines')<1 THEN
     RAISE EXCEPTION '請保留至少一項餐點';
   END IF;
   new_lines:=changes->'lines';
   FOR item IN SELECT value FROM jsonb_array_elements(new_lines) LOOP
     IF NOT item ?& ARRAY['menu_id','name','unit_price','quantity']
       OR length(btrim(coalesce(item->>'name','')))=0
       OR (item->>'unit_price') !~ '^[0-9]+$' OR (item->>'quantity') !~ '^[1-9][0-9]?$'
       OR jsonb_typeof(item->'unit_price')<>'number' OR jsonb_typeof(item->'quantity')<>'number'
       OR NOT EXISTS(SELECT 1 FROM public.restaurant_menu m WHERE m.id=item->>'menu_id')
       OR normalized ? (item->>'menu_id') THEN RAISE EXCEPTION '餐點、數量或單價無效'; END IF;
     normalized:=normalized||jsonb_build_object(item->>'menu_id',(item->>'quantity')::int);
     amount:=amount+(item->>'unit_price')::integer*(item->>'quantity')::integer;
   END LOOP;
   DELETE FROM public.restaurant_sale_items i WHERE i.sale_id=restaurant_edit_sale.sale_id;
   INSERT INTO public.restaurant_sale_items(sale_id,menu_id,name,unit_price,quantity)
   SELECT restaurant_edit_sale.sale_id,x.menu_id,x.name,x.unit_price,x.quantity
   FROM jsonb_to_recordset(new_lines) x(menu_id text,name text,unit_price integer,quantity integer);
   UPDATE public.restaurant_sales s SET service=changes->>'service',
     table_label=CASE WHEN changes->>'service'='內用' THEN btrim(changes->>'table_label') ELSE '' END,
     payment=changes->>'payment',total=amount,request_items=normalized
   WHERE s.id=sale_id RETURNING * INTO after_row;
 END IF;
 INSERT INTO public.restaurant_changes(target,target_id,action,actor,before_data,after_data)
 VALUES('sale',sale_id,CASE WHEN remove_sale THEN 'delete' ELSE 'edit' END,auth.uid(),
   jsonb_build_object('sale',to_jsonb(before_row),'lines',old_lines),
   jsonb_build_object('sale',to_jsonb(after_row),'lines',new_lines));
END;
$$;
REVOKE ALL ON FUNCTION public.restaurant_edit_sale(uuid,jsonb,jsonb,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.restaurant_edit_sale(uuid,jsonb,jsonb,boolean) TO authenticated;

CREATE OR REPLACE FUNCTION public.restaurant_revenue(grain text, reference_date date)
RETURNS TABLE(orders bigint, revenue bigint) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE period_start timestamp; period_end timestamp;
BEGIN
 IF NOT public.restaurant_has_role('owner') THEN RAISE EXCEPTION '需要管理者權限' USING ERRCODE='42501'; END IF;
 IF grain IS NULL OR grain NOT IN ('day','month','year') OR reference_date IS NULL THEN RAISE EXCEPTION '請選擇統計期間'; END IF;
 period_start:=date_trunc(grain,reference_date::timestamp);
 period_end:=period_start+CASE grain WHEN 'day' THEN interval '1 day' WHEN 'month' THEN interval '1 month' ELSE interval '1 year' END;
 RETURN QUERY SELECT count(*),coalesce(sum(s.total),0) FROM public.restaurant_sales s
 WHERE s.deleted_at IS NULL AND s.created_at>=period_start AT TIME ZONE 'Asia/Taipei'
   AND s.created_at<period_end AT TIME ZONE 'Asia/Taipei';
END;
$$;

ALTER FUNCTION public.restaurant_checkout(uuid,text,text,text,jsonb) RENAME TO restaurant_checkout_v21;
REVOKE ALL ON FUNCTION public.restaurant_checkout_v21(uuid,text,text,text,jsonb) FROM PUBLIC,anon,authenticated;
CREATE FUNCTION public.restaurant_checkout(sale_id uuid,service_mode text,table_name text,payment_mode text,items jsonb)
RETURNS public.restaurant_sales LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT public.restaurant_is_cashier() THEN RAISE EXCEPTION '需要櫃台權限' USING ERRCODE='42501'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(sale_id::text,0));
 IF EXISTS(SELECT 1 FROM public.restaurant_sales s WHERE s.id=sale_id AND s.deleted_at IS NOT NULL) THEN
   RAISE EXCEPTION '此交易已刪除，請由管理者核對' USING ERRCODE='23505';
 END IF;
 RETURN public.restaurant_checkout_v21(sale_id,service_mode,table_name,payment_mode,items);
END;
$$;
REVOKE ALL ON FUNCTION public.restaurant_checkout(uuid,text,text,text,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.restaurant_checkout(uuid,text,text,text,jsonb) TO authenticated;

-- Original migration 2-5
-- 在 v2.4 更新成功後執行一次。

ALTER TABLE public.restaurant_sales ADD COLUMN subtotal integer NOT NULL DEFAULT 0;
ALTER TABLE public.restaurant_sales ADD COLUMN discount_amount integer NOT NULL DEFAULT 0;
UPDATE public.restaurant_sales SET subtotal=total;
ALTER TABLE public.restaurant_sales ADD CONSTRAINT restaurant_sale_discount_valid
 CHECK(subtotal>=0 AND discount_amount>=0 AND discount_amount<=subtotal AND total=subtotal-discount_amount);

CREATE FUNCTION public.restaurant_sale_initial_subtotal() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
 NEW.subtotal:=NEW.total+NEW.discount_amount;
 RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.restaurant_sale_initial_subtotal() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER restaurant_sale_initial_subtotal BEFORE INSERT ON public.restaurant_sales
FOR EACH ROW EXECUTE FUNCTION public.restaurant_sale_initial_subtotal();

ALTER FUNCTION public.restaurant_checkout(uuid,text,text,text,jsonb) RENAME TO restaurant_checkout_before_discount;
REVOKE ALL ON FUNCTION public.restaurant_checkout_before_discount(uuid,text,text,text,jsonb) FROM PUBLIC,anon,authenticated;
CREATE FUNCTION public.restaurant_checkout_discount(
 sale_id uuid,service_mode text,table_name text,payment_mode text,items jsonb,discount integer DEFAULT 0
) RETURNS public.restaurant_sales LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result public.restaurant_sales;
BEGIN
 IF NOT public.restaurant_is_cashier() THEN RAISE EXCEPTION '需要櫃台權限' USING ERRCODE='42501'; END IF;
 IF discount IS NULL OR discount<0 THEN RAISE EXCEPTION '折扣金額必須為零或正整數' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(sale_id::text,0));
 SELECT * INTO result FROM public.restaurant_sales s WHERE s.id=sale_id;
 IF FOUND THEN
   IF result.deleted_at IS NOT NULL THEN RAISE EXCEPTION '此交易已刪除' USING ERRCODE='23505'; END IF;
   IF result.request_items IS DISTINCT FROM items OR result.service IS DISTINCT FROM service_mode
     OR upper(result.table_label) IS DISTINCT FROM upper(CASE WHEN service_mode='內用' THEN btrim(coalesce(table_name,'')) ELSE '' END)
     OR result.payment IS DISTINCT FROM payment_mode OR result.discount_amount<>discount THEN
     RAISE EXCEPTION '此交易已結帳，請重新查詢核對' USING ERRCODE='23505';
   END IF;
   RETURN result;
 END IF;
 result:=public.restaurant_checkout_before_discount(sale_id,service_mode,table_name,payment_mode,items);
 IF discount>result.total THEN RAISE EXCEPTION '折扣不可超過餐點小計' USING ERRCODE='22023'; END IF;
 UPDATE public.restaurant_sales s SET subtotal=result.total,discount_amount=discount,total=result.total-discount
 WHERE s.id=sale_id RETURNING * INTO result;
 RETURN result;
END;
$$;
REVOKE ALL ON FUNCTION public.restaurant_checkout_discount(uuid,text,text,text,jsonb,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.restaurant_checkout_discount(uuid,text,text,text,jsonb,integer) TO authenticated;
CREATE FUNCTION public.restaurant_checkout(sale_id uuid,service_mode text,table_name text,payment_mode text,items jsonb)
RETURNS public.restaurant_sales LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT public.restaurant_checkout_discount(sale_id,service_mode,table_name,payment_mode,items,0)
$$;
REVOKE ALL ON FUNCTION public.restaurant_checkout(uuid,text,text,text,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.restaurant_checkout(uuid,text,text,text,jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION public.restaurant_edit_sale(
 sale_id uuid, expected jsonb, changes jsonb, remove_sale boolean DEFAULT false
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
 before_row public.restaurant_sales; after_row public.restaurant_sales;
 old_lines jsonb; new_lines jsonb; item jsonb; amount integer:=0; rebate integer; normalized jsonb:='{}'::jsonb;
BEGIN
 IF NOT public.restaurant_has_role('owner') THEN RAISE EXCEPTION '需要管理者權限' USING ERRCODE='42501'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(sale_id::text,0));
 SELECT * INTO before_row FROM public.restaurant_sales s WHERE s.id=sale_id FOR UPDATE;
 IF NOT FOUND OR before_row.deleted_at IS NOT NULL THEN RAISE EXCEPTION '交易已刪除，請重新查詢'; END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('menu_id',i.menu_id,'name',i.name,'unit_price',i.unit_price,'quantity',i.quantity) ORDER BY i.menu_id COLLATE "C"),'[]'::jsonb)
 INTO old_lines FROM public.restaurant_sale_items i WHERE i.sale_id=restaurant_edit_sale.sale_id;
 IF expected IS DISTINCT FROM jsonb_build_object('service',before_row.service,'table_label',before_row.table_label,
   'payment',before_row.payment,'total',before_row.total,'subtotal',before_row.subtotal,'discount_amount',before_row.discount_amount,'lines',old_lines) THEN
   RAISE EXCEPTION '交易已被其他人更新，請重新查詢後再修改' USING ERRCODE='40001';
 END IF;
 IF remove_sale IS TRUE THEN
   UPDATE public.restaurant_sales s SET deleted_at=now() WHERE s.id=sale_id RETURNING * INTO after_row;
   new_lines:=old_lines;
 ELSE
   IF jsonb_typeof(changes) IS DISTINCT FROM 'object' OR NOT changes ?& ARRAY['service','table_label','payment','lines']
     OR jsonb_typeof(changes->'lines') IS DISTINCT FROM 'array' OR jsonb_array_length(changes->'lines')<1 THEN
     RAISE EXCEPTION '請保留至少一項餐點';
   END IF;
   new_lines:=changes->'lines';
   FOR item IN SELECT value FROM jsonb_array_elements(new_lines) LOOP
     IF NOT item ?& ARRAY['menu_id','name','unit_price','quantity']
       OR length(btrim(coalesce(item->>'name','')))=0
       OR (item->>'unit_price') !~ '^[0-9]+$' OR (item->>'quantity') !~ '^[1-9][0-9]?$'
       OR jsonb_typeof(item->'unit_price')<>'number' OR jsonb_typeof(item->'quantity')<>'number'
       OR NOT EXISTS(SELECT 1 FROM public.restaurant_menu m WHERE m.id=item->>'menu_id')
       OR normalized ? (item->>'menu_id') THEN RAISE EXCEPTION '餐點、數量或單價無效'; END IF;
     normalized:=normalized||jsonb_build_object(item->>'menu_id',(item->>'quantity')::int);
     amount:=amount+(item->>'unit_price')::integer*(item->>'quantity')::integer;
   END LOOP;
   IF jsonb_typeof(changes->'discount_amount') IS DISTINCT FROM 'number' OR (changes->>'discount_amount') !~ '^[0-9]+$' THEN
     RAISE EXCEPTION '折扣金額必須為零或正整數' USING ERRCODE='22023';
   END IF;
   rebate:=(changes->>'discount_amount')::integer;
   IF rebate>amount THEN RAISE EXCEPTION '折扣不可超過餐點小計' USING ERRCODE='22023'; END IF;
   DELETE FROM public.restaurant_sale_items i WHERE i.sale_id=restaurant_edit_sale.sale_id;
   INSERT INTO public.restaurant_sale_items(sale_id,menu_id,name,unit_price,quantity)
   SELECT restaurant_edit_sale.sale_id,x.menu_id,x.name,x.unit_price,x.quantity
   FROM jsonb_to_recordset(new_lines) x(menu_id text,name text,unit_price integer,quantity integer);
   UPDATE public.restaurant_sales s SET service=changes->>'service',
     table_label=CASE WHEN changes->>'service'='內用' THEN btrim(changes->>'table_label') ELSE '' END,
     payment=changes->>'payment',subtotal=amount,discount_amount=rebate,total=amount-rebate,request_items=normalized
   WHERE s.id=sale_id RETURNING * INTO after_row;
 END IF;
 INSERT INTO public.restaurant_changes(target,target_id,action,actor,before_data,after_data)
 VALUES('sale',sale_id,CASE WHEN remove_sale THEN 'delete' ELSE 'edit' END,auth.uid(),
   jsonb_build_object('sale',to_jsonb(before_row),'lines',old_lines),
   jsonb_build_object('sale',to_jsonb(after_row),'lines',new_lines));
END;
$$;

-- Original migration 2-7

ALTER TABLE public.restaurant_kitchen ADD COLUMN initial_lines jsonb;
UPDATE public.restaurant_kitchen SET initial_lines=lines;
CREATE FUNCTION public.restaurant_keep_initial_lines() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $$
BEGIN NEW.initial_lines:=NEW.lines; RETURN NEW; END;
$$;
REVOKE ALL ON FUNCTION public.restaurant_keep_initial_lines() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER zz_restaurant_keep_initial BEFORE INSERT ON public.restaurant_kitchen
FOR EACH ROW EXECUTE FUNCTION public.restaurant_keep_initial_lines();

CREATE TABLE public.restaurant_addons (
 id uuid PRIMARY KEY, ticket_id uuid NOT NULL REFERENCES public.restaurant_kitchen(id),
 requested jsonb NOT NULL, lines jsonb NOT NULL,
 status text NOT NULL DEFAULT 'queued' CHECK(status IN ('queued','preparing','served')),
 created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.restaurant_addons ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.restaurant_addons FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.restaurant_addons TO authenticated;
CREATE POLICY restaurant_addons_read ON public.restaurant_addons FOR SELECT TO authenticated
 USING ((SELECT public.restaurant_has_role()));

CREATE FUNCTION public.restaurant_add_items(ticket_id uuid,request_id uuid,requested jsonb)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
 ticket public.restaurant_kitchen; prior public.restaurant_addons; entry record;
 current_line jsonb; new_line jsonb; merged jsonb; delta jsonb:='[]'::jsonb;
 all_lines jsonb; all_items jsonb; quantity integer;
BEGIN
 IF NOT public.restaurant_is_cashier() THEN RAISE EXCEPTION '需要櫃台權限' USING ERRCODE='42501'; END IF;
 IF ticket_id IS NULL OR request_id IS NULL OR jsonb_typeof(requested) IS DISTINCT FROM 'object' OR requested='{}'::jsonb THEN
   RAISE EXCEPTION '請選擇加點餐點' USING ERRCODE='22023';
 END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(ticket_id::text,0));
 SELECT * INTO prior FROM public.restaurant_addons a WHERE a.id=request_id;
 IF FOUND THEN
   IF prior.ticket_id IS DISTINCT FROM ticket_id OR prior.requested IS DISTINCT FROM requested THEN
     RAISE EXCEPTION '加點編號已使用' USING ERRCODE='22023';
   END IF;
   RETURN prior.id;
 END IF;
 SELECT * INTO ticket FROM public.restaurant_kitchen k WHERE k.id=ticket_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION '找不到桌單，請重新整理' USING ERRCODE='22023'; END IF;
 IF EXISTS(SELECT 1 FROM public.restaurant_sales s WHERE s.id=ticket_id) THEN
   RAISE EXCEPTION '此桌已結帳，請重新開單' USING ERRCODE='23505';
 END IF;
 all_lines:=public.restaurant_ticket_lines(ticket);
 all_items:=ticket.items;
 FOR entry IN SELECT e.key,e.value,m.name,m.price FROM jsonb_each(requested) e
   LEFT JOIN public.restaurant_menu m ON m.id=e.key AND m.active
 LOOP
   IF entry.name IS NULL OR jsonb_typeof(entry.value)<>'number' OR entry.value::text !~ '^[1-9][0-9]?$' THEN
     RAISE EXCEPTION '加點餐點已下架或份數無效' USING ERRCODE='22023';
   END IF;
   quantity:=(entry.value::text)::int;
   SELECT value INTO current_line FROM jsonb_array_elements(all_lines) WHERE value->>'id'=entry.key;
   IF FOUND THEN
     IF (current_line->>'qty')::int+quantity>99 THEN RAISE EXCEPTION '單一餐點總份數不可超過 99' USING ERRCODE='22023'; END IF;
     new_line:=current_line||jsonb_build_object('qty',quantity);
     SELECT jsonb_agg(CASE WHEN value->>'id'=entry.key THEN
       value||jsonb_build_object('qty',(value->>'qty')::int+quantity) ELSE value END)
     INTO merged FROM jsonb_array_elements(all_lines);
     all_lines:=merged;
   ELSE
     new_line:=jsonb_build_object('id',entry.key,'name',entry.name,'price',entry.price,'qty',quantity);
     all_lines:=all_lines||jsonb_build_array(new_line);
   END IF;
   delta:=delta||jsonb_build_array(new_line);
   all_items:=all_items||jsonb_build_object(entry.key,coalesce((all_items->>entry.key)::int,0)+quantity);
 END LOOP;
 INSERT INTO public.restaurant_addons(id,ticket_id,requested,lines) VALUES(request_id,ticket_id,requested,delta);
 UPDATE public.restaurant_kitchen k SET items=all_items,lines=all_lines WHERE k.id=ticket_id;
 RETURN request_id;
END;
$$;
REVOKE ALL ON FUNCTION public.restaurant_add_items(uuid,uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.restaurant_add_items(uuid,uuid,jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION public.restaurant_open_tables()
RETURNS TABLE(id uuid,service text,table_label text,status text,created_at timestamptz,lines jsonb)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT k.id,k.service,k.table_label,
   CASE WHEN k.status='queued' OR EXISTS(SELECT 1 FROM public.restaurant_addons a WHERE a.ticket_id=k.id AND a.status='queued') THEN 'queued'
        WHEN k.status='preparing' OR EXISTS(SELECT 1 FROM public.restaurant_addons a WHERE a.ticket_id=k.id AND a.status='preparing') THEN 'preparing'
        ELSE 'served' END,
   k.created_at,public.restaurant_ticket_lines(k)
 FROM public.restaurant_kitchen k WHERE public.restaurant_is_cashier()
 AND NOT EXISTS(SELECT 1 FROM public.restaurant_sales s WHERE s.id=k.id) ORDER BY k.created_at
$$;

CREATE FUNCTION public.restaurant_kitchen_batches()
RETURNS TABLE(id uuid,source text,service text,table_label text,lines jsonb,status text,created_at timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT k.id,'original'::text,k.service,k.table_label,coalesce(k.initial_lines,k.lines),k.status,k.created_at
 FROM public.restaurant_kitchen k WHERE public.restaurant_has_role() AND
   (k.status<>'served' OR k.created_at>=(now() AT TIME ZONE 'Asia/Taipei')::date AT TIME ZONE 'Asia/Taipei')
 UNION ALL
 SELECT a.id,'addon'::text,k.service,k.table_label,a.lines,a.status,a.created_at
 FROM public.restaurant_addons a JOIN public.restaurant_kitchen k ON k.id=a.ticket_id
 WHERE public.restaurant_has_role() AND
   (a.status<>'served' OR a.created_at>=(now() AT TIME ZONE 'Asia/Taipei')::date AT TIME ZONE 'Asia/Taipei')
 ORDER BY created_at DESC
$$;
REVOKE ALL ON FUNCTION public.restaurant_kitchen_batches() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.restaurant_kitchen_batches() TO authenticated;

CREATE FUNCTION public.restaurant_batch_status(batch_id uuid,batch_source text,old_status text,new_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE changed integer;
BEGIN
 IF NOT public.restaurant_has_role() THEN RAISE EXCEPTION '需要員工權限' USING ERRCODE='42501'; END IF;
 IF NOT ((old_status='queued' AND new_status='preparing') OR (old_status='preparing' AND new_status='served')) THEN
   RAISE EXCEPTION '出餐狀態無效' USING ERRCODE='22023';
 END IF;
 IF batch_source='original' THEN
   UPDATE public.restaurant_kitchen SET status=new_status WHERE id=batch_id AND status=old_status;
 ELSIF batch_source='addon' THEN
   UPDATE public.restaurant_addons SET status=new_status WHERE id=batch_id AND status=old_status;
 ELSE RAISE EXCEPTION '出餐單類型無效' USING ERRCODE='22023';
 END IF;
 GET DIAGNOSTICS changed=ROW_COUNT;
 IF changed<>1 THEN RAISE EXCEPTION '出餐狀態已更新，請重新整理' USING ERRCODE='40001'; END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.restaurant_batch_status(uuid,text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.restaurant_batch_status(uuid,text,text,text) TO authenticated;

-- Original migration 2-8

-- 僅供後端驗證管理者後移除員工資格，瀏覽器不取得此權限。
GRANT SELECT, INSERT, UPDATE, DELETE ON public.restaurant_staff TO service_role;

-- Original migration 2-9
-- 接續 v2.7/v2.8；本次不需更改 linglan-staff Edge Function。

CREATE OR REPLACE FUNCTION public.restaurant_ticket_lines(ticket public.restaurant_kitchen)
RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT coalesce(CASE WHEN (ticket.lines->0) ? 'price' THEN ticket.lines
 ELSE (SELECT jsonb_agg(jsonb_build_object('id',m.id,'name',m.name,'price',m.price,'qty',(e.value::text)::int))
 FROM jsonb_each(ticket.items) e JOIN public.restaurant_menu m ON m.id=e.key) END,'[]'::jsonb)
$$;
CREATE OR REPLACE FUNCTION public.restaurant_empty_ticket_lines() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $$
BEGIN NEW.lines:=coalesce(NEW.lines,'[]'::jsonb); RETURN NEW; END; $$;
REVOKE ALL ON FUNCTION public.restaurant_empty_ticket_lines() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS z_restaurant_empty_lines ON public.restaurant_kitchen;
CREATE TRIGGER z_restaurant_empty_lines BEFORE INSERT ON public.restaurant_kitchen
 FOR EACH ROW EXECUTE FUNCTION public.restaurant_empty_ticket_lines();
CREATE TABLE IF NOT EXISTS public.restaurant_qr_tables (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), table_label text NOT NULL UNIQUE CHECK(length(table_label) BETWEEN 1 AND 20),
 active boolean NOT NULL DEFAULT true
);
ALTER TABLE public.restaurant_qr_tables ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.restaurant_qr_tables FROM PUBLIC,anon,authenticated;
CREATE TABLE IF NOT EXISTS public.restaurant_dining_sessions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 table_label text NOT NULL CHECK(length(table_label) BETWEEN 1 AND 20),
 ticket_id uuid NOT NULL, qr_table_id uuid NOT NULL REFERENCES public.restaurant_qr_tables(id),
 opened_at timestamptz NOT NULL DEFAULT now(),
 expires_at timestamptz NOT NULL DEFAULT now()+interval '12 hours',
 closed_at timestamptz,
 opened_by uuid NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS restaurant_one_dining_session ON public.restaurant_dining_sessions(table_label) WHERE closed_at IS NULL;
CREATE TABLE IF NOT EXISTS public.restaurant_guest_orders (
 id uuid PRIMARY KEY, session_id uuid NOT NULL REFERENCES public.restaurant_dining_sessions(id),
 requested jsonb NOT NULL, lines jsonb NOT NULL, note text NOT NULL DEFAULT '' CHECK(length(note)<=300),
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','accepted','rejected')),
 created_at timestamptz NOT NULL DEFAULT now(), reviewed_at timestamptz, reviewed_by uuid,
 reason text NOT NULL DEFAULT '', batch_id uuid
);
CREATE INDEX IF NOT EXISTS restaurant_guest_session_orders ON public.restaurant_guest_orders(session_id,created_at);
ALTER TABLE public.restaurant_dining_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.restaurant_guest_orders ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.restaurant_dining_sessions,public.restaurant_guest_orders FROM PUBLIC,anon,authenticated;

-- 桌碼永久固定；客人第一次實際送單時才建立用餐紀錄，不需員工開桌。
CREATE OR REPLACE FUNCTION public.restaurant_dining_open(table_name text)
RETURNS public.restaurant_qr_tables LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE label text:=upper(btrim(coalesce(table_name,''))); result public.restaurant_qr_tables;
BEGIN
 IF NOT public.restaurant_is_cashier() THEN RAISE EXCEPTION '需要櫃台權限' USING ERRCODE='42501'; END IF;
 IF length(label) NOT BETWEEN 1 AND 20 THEN RAISE EXCEPTION '請填寫桌號（最多 20 字）' USING ERRCODE='22023'; END IF;
 INSERT INTO public.restaurant_qr_tables(table_label) VALUES(label) ON CONFLICT(table_label) DO UPDATE SET active=true RETURNING * INTO result;
 RETURN result;
END; $$;
CREATE OR REPLACE FUNCTION public.restaurant_dining_list()
RETURNS SETOF public.restaurant_qr_tables LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT d.* FROM public.restaurant_qr_tables d WHERE public.restaurant_is_cashier() ORDER BY d.table_label
$$;
CREATE OR REPLACE FUNCTION public.restaurant_dining_close(session_key uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE d public.restaurant_dining_sessions; label text;
BEGIN
 IF NOT public.restaurant_is_cashier() THEN RAISE EXCEPTION '需要櫃台權限' USING ERRCODE='42501'; END IF;
 SELECT table_label INTO label FROM public.restaurant_qr_tables WHERE id=session_key;
 IF NOT FOUND THEN RAISE EXCEPTION '找不到桌碼'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('linglan:table:'||label,0));
 SELECT * INTO d FROM public.restaurant_dining_sessions WHERE qr_table_id=session_key AND closed_at IS NULL;
 IF FOUND THEN
  PERFORM pg_advisory_xact_lock(hashtextextended(d.ticket_id::text,0));
  UPDATE public.restaurant_dining_sessions SET closed_at=now() WHERE id=d.id;
  UPDATE public.restaurant_guest_orders SET status='rejected',reason='本桌已停止自助點餐',reviewed_by=auth.uid(),reviewed_at=now()
   WHERE session_id=d.id AND status='pending';
  DELETE FROM public.restaurant_kitchen k WHERE k.id=d.ticket_id AND k.items='{}'::jsonb AND NOT EXISTS(SELECT 1 FROM public.restaurant_sales WHERE id=k.id);
 END IF;
 UPDATE public.restaurant_qr_tables SET active=false WHERE id=session_key;
END; $$;
-- 有效 QR 僅取得本次用餐的桌號及點餐狀態，不取得員工、訂位或營收。
CREATE OR REPLACE FUNCTION public.restaurant_guest_view(table_key uuid,visit_key uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE t public.restaurant_qr_tables; d public.restaurant_dining_sessions; orders jsonb;
BEGIN
 SELECT * INTO t FROM public.restaurant_qr_tables WHERE id=table_key;
 IF NOT FOUND THEN RAISE EXCEPTION '桌碼無效，請掃描桌上的 QR Code' USING ERRCODE='22023'; END IF;
 SELECT * INTO d FROM public.restaurant_dining_sessions WHERE qr_table_id=table_key
 AND ((visit_key IS NULL AND closed_at IS NULL) OR id=visit_key) ORDER BY opened_at DESC LIMIT 1;
 SELECT coalesce(jsonb_agg(to_jsonb(o) ORDER BY o.created_at DESC),'[]'::jsonb) INTO orders FROM
 (SELECT o.id,o.lines,o.note,o.status,o.reason,o.created_at,a.status AS kitchen_status FROM public.restaurant_guest_orders o
 LEFT JOIN public.restaurant_addons a ON a.id=o.batch_id WHERE o.session_id=d.id ORDER BY o.created_at DESC LIMIT 50) o;
 RETURN jsonb_build_object('table',t.table_label,'active',t.active AND (d.id IS NULL OR (d.closed_at IS NULL AND d.expires_at>now())),
 'session_id',d.id,'orders',orders,'prices',(SELECT public.restaurant_ticket_lines(k) FROM public.restaurant_kitchen k WHERE k.id=d.ticket_id));
END; $$;
-- 價格與名稱均從資料庫生成，客人只能提交品項編號、份數和備註。
CREATE OR REPLACE FUNCTION public.restaurant_guest_submit(table_key uuid,request_id uuid,requested jsonb,order_note text DEFAULT '',visit_key uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE t public.restaurant_qr_tables; d public.restaurant_dining_sessions; ticket uuid; prior public.restaurant_guest_orders; e record; line jsonb; snapshot jsonb:='[]'; original jsonb;
BEGIN
 SELECT * INTO t FROM public.restaurant_qr_tables WHERE id=table_key;
 IF NOT FOUND OR NOT t.active THEN RAISE EXCEPTION '此桌未開放點餐，請洽店員' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('linglan:table:'||t.table_label,0));
 SELECT * INTO prior FROM public.restaurant_guest_orders WHERE id=request_id;
 IF FOUND THEN
  IF NOT EXISTS(SELECT 1 FROM public.restaurant_dining_sessions WHERE id=prior.session_id AND qr_table_id=table_key)
   OR prior.requested IS DISTINCT FROM requested OR prior.note<>coalesce(order_note,'') THEN RAISE EXCEPTION '點餐編號已使用' USING ERRCODE='22023'; END IF;
  RETURN jsonb_build_object('id',prior.id,'status',prior.status,'session_id',prior.session_id);
 END IF;
 SELECT * INTO d FROM public.restaurant_dining_sessions WHERE qr_table_id=table_key AND closed_at IS NULL;
 IF d.id IS NOT NULL THEN
  PERFORM pg_advisory_xact_lock(hashtextextended(d.ticket_id::text,0));
  SELECT * INTO d FROM public.restaurant_dining_sessions WHERE qr_table_id=table_key AND closed_at IS NULL FOR UPDATE;
 END IF;
 IF visit_key IS NOT NULL AND visit_key IS DISTINCT FROM d.id THEN
  RAISE EXCEPTION '上一批用餐已結束，若是本次用餐請按「開始新的用餐」' USING ERRCODE='22023'; END IF;
 IF d.id IS NULL THEN
  SELECT k.id INTO ticket FROM public.restaurant_kitchen k WHERE k.service='內用' AND upper(btrim(k.table_label))=t.table_label
    AND NOT EXISTS(SELECT 1 FROM public.restaurant_sales s WHERE s.id=k.id) LIMIT 1;
  IF ticket IS NULL THEN
   ticket:=gen_random_uuid();
   INSERT INTO public.restaurant_kitchen(id,service,table_label,items,lines,status) VALUES(ticket,'內用',t.table_label,'{}','[]','served');
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(ticket::text,0));
  INSERT INTO public.restaurant_dining_sessions(table_label,ticket_id,qr_table_id,opened_by)
   VALUES(t.table_label,ticket,table_key,coalesce(auth.uid(),'00000000-0000-0000-0000-000000000000'::uuid)) RETURNING * INTO d;
 END IF;
 IF d.closed_at IS NOT NULL OR d.expires_at<=now() OR EXISTS(SELECT 1 FROM public.restaurant_sales WHERE id=d.ticket_id) THEN
  RAISE EXCEPTION '本次用餐已結束或連結已到期，請洽店員' USING ERRCODE='22023'; END IF;
 IF request_id IS NULL OR jsonb_typeof(requested) IS DISTINCT FROM 'object' OR requested='{}'::jsonb OR length(coalesce(order_note,''))>300 THEN
  RAISE EXCEPTION '請確認餐點及備註' USING ERRCODE='22023'; END IF;
 IF (SELECT count(*) FROM jsonb_each(requested))>30 THEN RAISE EXCEPTION '每次最多 30 種餐點' USING ERRCODE='22023'; END IF;
 IF (SELECT count(*) FROM public.restaurant_guest_orders WHERE session_id=d.id AND status='pending')>=20
 OR (SELECT count(*) FROM public.restaurant_guest_orders WHERE session_id=d.id)>=200
 OR EXISTS(SELECT 1 FROM public.restaurant_guest_orders WHERE session_id=d.id AND created_at>now()-interval '2 seconds') THEN
  RAISE EXCEPTION '送單較頻繁，請稍後再試或洽店員' USING ERRCODE='22023'; END IF;
 SELECT public.restaurant_ticket_lines(k) INTO original FROM public.restaurant_kitchen k WHERE id=d.ticket_id;
 FOR e IN SELECT j.key,j.value,m.name,m.price FROM jsonb_each(requested) j LEFT JOIN public.restaurant_menu m ON m.id=j.key AND m.active LOOP
  IF e.name IS NULL OR jsonb_typeof(e.value)<>'number' OR e.value::text !~ '^[1-9][0-9]?$' THEN
   RAISE EXCEPTION '餐點已下架或份數無效，請重新整理' USING ERRCODE='22023'; END IF;
  SELECT value INTO line FROM jsonb_array_elements(coalesce(original,'[]')) WHERE value->>'id'=e.key;
  snapshot:=snapshot||jsonb_build_array(jsonb_build_object('id',e.key,'name',coalesce(line->>'name',e.name),'price',coalesce((line->>'price')::int,e.price),'qty',(e.value::text)::int));
 END LOOP;
 INSERT INTO public.restaurant_guest_orders(id,session_id,requested,lines,note) VALUES(request_id,d.id,requested,snapshot,coalesce(order_note,''));
 RETURN jsonb_build_object('id',request_id,'status','pending','session_id',d.id);
END; $$;
CREATE OR REPLACE FUNCTION public.restaurant_guest_pending()
RETURNS TABLE(id uuid,table_label text,lines jsonb,note text,created_at timestamptz,expired boolean)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT o.id,d.table_label,o.lines,o.note,o.created_at,d.closed_at IS NOT NULL OR d.expires_at<=now()
 FROM public.restaurant_guest_orders o JOIN public.restaurant_dining_sessions d ON d.id=o.session_id
 WHERE public.restaurant_is_cashier() AND o.status='pending' ORDER BY o.created_at
$$;
CREATE OR REPLACE FUNCTION public.restaurant_guest_review(order_id uuid,accept_order boolean)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE d public.restaurant_dining_sessions; o public.restaurant_guest_orders; line jsonb; price integer; original jsonb;
BEGIN
 IF NOT public.restaurant_is_cashier() THEN RAISE EXCEPTION '需要櫃台權限' USING ERRCODE='42501'; END IF;
 IF accept_order IS NULL THEN RAISE EXCEPTION '請選擇確認或退回'; END IF;
 SELECT * INTO o FROM public.restaurant_guest_orders WHERE id=order_id;
 IF NOT FOUND THEN RAISE EXCEPTION '找不到客人點餐'; END IF;
 SELECT * INTO d FROM public.restaurant_dining_sessions WHERE id=o.session_id;
 PERFORM pg_advisory_xact_lock(hashtextextended(d.ticket_id::text,0));
 SELECT * INTO d FROM public.restaurant_dining_sessions WHERE id=o.session_id FOR UPDATE;
 SELECT * INTO o FROM public.restaurant_guest_orders WHERE id=order_id FOR UPDATE;
 IF o.status=(CASE WHEN accept_order THEN 'accepted' ELSE 'rejected' END) THEN RETURN o.status; END IF;
 IF o.status<>'pending' THEN RAISE EXCEPTION '此單已由其他人處理，請重新整理' USING ERRCODE='40001'; END IF;
 IF accept_order THEN
  IF d.closed_at IS NOT NULL OR d.expires_at<=now() OR EXISTS(SELECT 1 FROM public.restaurant_sales WHERE id=d.ticket_id) THEN
   RAISE EXCEPTION '本桌已結束或到期，請退回此單' USING ERRCODE='22023'; END IF;
  SELECT public.restaurant_ticket_lines(k) INTO original FROM public.restaurant_kitchen k WHERE id=d.ticket_id;
  FOR line IN SELECT value FROM jsonb_array_elements(o.lines) LOOP
   SELECT coalesce((SELECT (x->>'price')::int FROM jsonb_array_elements(coalesce(original,'[]')) x WHERE x->>'id'=m.id),m.price)
    INTO price FROM public.restaurant_menu m WHERE m.id=line->>'id' AND m.active;
   IF price IS NULL OR price<>(line->>'price')::int THEN RAISE EXCEPTION '餐點或價格已異動，請退回並請客人重新點餐' USING ERRCODE='22023'; END IF;
  END LOOP;
  PERFORM public.restaurant_add_items(d.ticket_id,o.id,o.requested);
 END IF;
 UPDATE public.restaurant_guest_orders SET status=CASE WHEN accept_order THEN 'accepted' ELSE 'rejected' END,
 reviewed_at=now(),reviewed_by=auth.uid(),reason=CASE WHEN accept_order THEN '' ELSE '店員已退回，請洽櫃台確認' END,
 batch_id=CASE WHEN accept_order THEN o.id ELSE NULL END WHERE id=order_id;
 RETURN CASE WHEN accept_order THEN 'accepted' ELSE 'rejected' END;
END; $$;
CREATE OR REPLACE FUNCTION public.restaurant_guest_kitchen_notes()
RETURNS TABLE(batch_id uuid,note text) LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT o.batch_id,o.note FROM public.restaurant_guest_orders o WHERE public.restaurant_has_role() AND o.status='accepted'
 AND o.created_at>=now()-interval '7 days'
$$;
CREATE OR REPLACE FUNCTION public.restaurant_qr_checkout_guard()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE d public.restaurant_dining_sessions;
BEGIN
 SELECT * INTO d FROM public.restaurant_dining_sessions WHERE ticket_id=NEW.id AND closed_at IS NULL FOR UPDATE;
 IF FOUND THEN
  IF EXISTS(SELECT 1 FROM public.restaurant_guest_orders WHERE session_id=d.id AND status='pending') THEN
   RAISE EXCEPTION '本桌還有客人點餐待確認，請先確認送廚房或退回再結帳' USING ERRCODE='22023'; END IF;
  UPDATE public.restaurant_dining_sessions SET closed_at=now() WHERE id=d.id;
 END IF;
 RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS restaurant_qr_checkout_guard ON public.restaurant_sales;
CREATE TRIGGER restaurant_qr_checkout_guard BEFORE INSERT ON public.restaurant_sales FOR EACH ROW EXECUTE FUNCTION public.restaurant_qr_checkout_guard();
-- 空白開桌單不顯示於廚房；實際送出的加點批次照常顯示。
CREATE OR REPLACE FUNCTION public.restaurant_kitchen_batches()
RETURNS TABLE(id uuid,source text,service text,table_label text,lines jsonb,status text,created_at timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT k.id,'original'::text,k.service,k.table_label,coalesce(k.initial_lines,k.lines),k.status,k.created_at
 FROM public.restaurant_kitchen k WHERE public.restaurant_has_role() AND jsonb_array_length(coalesce(k.initial_lines,k.lines,'[]'))>0 AND
 (k.status<>'served' OR k.created_at>=(now() AT TIME ZONE 'Asia/Taipei')::date AT TIME ZONE 'Asia/Taipei')
 UNION ALL
 SELECT a.id,'addon'::text,k.service,k.table_label,a.lines,a.status,a.created_at
 FROM public.restaurant_addons a JOIN public.restaurant_kitchen k ON k.id=a.ticket_id WHERE public.restaurant_has_role() AND
 (a.status<>'served' OR a.created_at>=(now() AT TIME ZONE 'Asia/Taipei')::date AT TIME ZONE 'Asia/Taipei') ORDER BY created_at DESC
$$;
REVOKE ALL ON FUNCTION public.restaurant_dining_open(text),public.restaurant_dining_list(),public.restaurant_dining_close(uuid),
 public.restaurant_guest_pending(),public.restaurant_guest_review(uuid,boolean),public.restaurant_guest_kitchen_notes(),public.restaurant_qr_checkout_guard() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.restaurant_dining_open(text),public.restaurant_dining_list(),public.restaurant_dining_close(uuid),
 public.restaurant_guest_pending(),public.restaurant_guest_review(uuid,boolean),public.restaurant_guest_kitchen_notes() TO authenticated;
REVOKE ALL ON FUNCTION public.restaurant_guest_view(uuid,uuid),public.restaurant_guest_submit(uuid,uuid,jsonb,text,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.restaurant_guest_view(uuid,uuid),public.restaurant_guest_submit(uuid,uuid,jsonb,text,uuid) TO anon,authenticated;

-- Original migration 2-10
-- 接續 v2.9；不需更新 Edge Functions。

ALTER TABLE public.restaurant_menu ADD COLUMN IF NOT EXISTS sold_out_date date;
GRANT SELECT(sold_out_date) ON public.restaurant_menu TO anon,authenticated;
ALTER TABLE public.restaurant_kitchen ADD COLUMN IF NOT EXISTS cancelled_at timestamptz;
REVOKE UPDATE(status) ON public.restaurant_kitchen FROM authenticated;
CREATE TABLE IF NOT EXISTS public.restaurant_delivery (
 source text NOT NULL CHECK(source IN ('original','addon')),batch_id uuid NOT NULL,menu_id text NOT NULL,
 delivered integer NOT NULL CHECK(delivered>=0),PRIMARY KEY(source,batch_id,menu_id)
);
CREATE TABLE IF NOT EXISTS public.restaurant_ticket_changes (
 id uuid PRIMARY KEY,ticket_id uuid NOT NULL,table_label text NOT NULL,service text NOT NULL,
 before_lines jsonb NOT NULL,after_lines jsonb NOT NULL,reason text NOT NULL,
 payload jsonb NOT NULL,actor uuid NOT NULL,created_at timestamptz NOT NULL DEFAULT now(),
 kitchen_seen_at timestamptz,seen_by uuid
);
ALTER TABLE public.restaurant_delivery ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.restaurant_ticket_changes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.restaurant_delivery,public.restaurant_ticket_changes FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.restaurant_set_sold_out(menu_id text,unavailable boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT public.restaurant_is_cashier() THEN RAISE EXCEPTION '需要櫃台權限' USING ERRCODE='42501'; END IF;
 IF unavailable IS NULL THEN RAISE EXCEPTION '請選擇供應狀態'; END IF;
 UPDATE public.restaurant_menu m SET sold_out_date=CASE WHEN unavailable THEN (now() AT TIME ZONE 'Asia/Taipei')::date ELSE NULL END WHERE m.id=menu_id;
 IF NOT FOUND THEN RAISE EXCEPTION '找不到餐點'; END IF;
END; $$;
-- 僅在增加份數時檢查售完；已送出的餐點仍可結帳、減量與退菜。
CREATE OR REPLACE FUNCTION public.restaurant_unavailable_guard()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE e record;prior jsonb:='{}';incoming jsonb;
BEGIN
 IF TG_TABLE_NAME='restaurant_kitchen' THEN
  IF TG_OP='UPDATE' THEN
   prior:=OLD.items;
   IF OLD.cancelled_at IS NOT NULL AND NEW.items IS DISTINCT FROM OLD.items THEN RAISE EXCEPTION '桌單已取消，請重新點餐' USING ERRCODE='22023'; END IF;
  END IF;
  incoming:=NEW.items;
 ELSIF TG_TABLE_NAME='restaurant_guest_orders' THEN incoming:=NEW.requested;
 ELSE
  IF EXISTS(SELECT 1 FROM public.restaurant_kitchen WHERE id=NEW.id AND cancelled_at IS NOT NULL) THEN RAISE EXCEPTION '桌單已取消，不能結帳' USING ERRCODE='22023'; END IF;
  IF EXISTS(SELECT 1 FROM public.restaurant_kitchen WHERE id=NEW.id) THEN RETURN NEW; END IF;
  incoming:=NEW.request_items;
 END IF;
 FOR e IN SELECT key,value FROM jsonb_each(incoming) LOOP
  IF (e.value::text)::int>coalesce((prior->>e.key)::int,0) AND EXISTS(SELECT 1 FROM public.restaurant_menu m WHERE m.id=e.key AND m.sold_out_date=(now() AT TIME ZONE 'Asia/Taipei')::date) THEN
   RAISE EXCEPTION '餐點今日已售完，請移除此餐點或洽店員' USING ERRCODE='22023'; END IF;
 END LOOP;
 RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS restaurant_unavailable_guard ON public.restaurant_kitchen;
CREATE TRIGGER restaurant_unavailable_guard BEFORE INSERT OR UPDATE OF items ON public.restaurant_kitchen FOR EACH ROW EXECUTE FUNCTION public.restaurant_unavailable_guard();
DROP TRIGGER IF EXISTS restaurant_unavailable_guard ON public.restaurant_guest_orders;
CREATE TRIGGER restaurant_unavailable_guard BEFORE INSERT ON public.restaurant_guest_orders FOR EACH ROW EXECUTE FUNCTION public.restaurant_unavailable_guard();
DROP TRIGGER IF EXISTS restaurant_unavailable_guard ON public.restaurant_sales;
CREATE TRIGGER restaurant_unavailable_guard BEFORE INSERT ON public.restaurant_sales FOR EACH ROW EXECUTE FUNCTION public.restaurant_unavailable_guard();

CREATE OR REPLACE FUNCTION public.restaurant_delivery_rows()
RETURNS TABLE(source text,batch_id uuid,menu_id text,quantity integer,delivered integer)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT b.source,b.id,x->>'id',(x->>'qty')::int,coalesce(p.delivered,CASE WHEN b.status='served' THEN (x->>'qty')::int ELSE 0 END)
 FROM public.restaurant_kitchen_batches() b CROSS JOIN LATERAL jsonb_array_elements(b.lines) x
 LEFT JOIN public.restaurant_delivery p ON p.source=b.source AND p.batch_id=b.id AND p.menu_id=x->>'id'
 WHERE public.restaurant_has_role()
$$;
CREATE OR REPLACE FUNCTION public.restaurant_sync_batch(kind text,batch uuid)
RETURNS void LANGUAGE plpgsql SET search_path='' AS $$
DECLARE lines jsonb;current_status text;complete boolean;any_done boolean;
BEGIN
 IF kind='original' THEN SELECT initial_lines,status INTO lines,current_status FROM public.restaurant_kitchen WHERE id=batch;
 ELSE SELECT a.lines,a.status INTO lines,current_status FROM public.restaurant_addons a WHERE a.id=batch; END IF;
 SELECT coalesce(bool_and(coalesce(p.delivered,CASE WHEN current_status='served' THEN (x->>'qty')::int ELSE 0 END)>=(x->>'qty')::int),true),
 coalesce(bool_or(coalesce(p.delivered,CASE WHEN current_status='served' THEN (x->>'qty')::int ELSE 0 END)>0),false)
 INTO complete,any_done FROM jsonb_array_elements(coalesce(lines,'[]')) x
 LEFT JOIN public.restaurant_delivery p ON p.source=kind AND p.batch_id=batch AND p.menu_id=x->>'id';
 IF complete THEN current_status:='served'; ELSIF any_done THEN current_status:='preparing'; END IF;
 IF kind='original' THEN UPDATE public.restaurant_kitchen SET status=current_status WHERE id=batch;
 ELSE UPDATE public.restaurant_addons SET status=current_status WHERE id=batch; END IF;
END; $$;
CREATE OR REPLACE FUNCTION public.restaurant_deliver_item(kind text,batch uuid,item_id text,expected_quantity integer,expected_delivered integer)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE ticket uuid;lines jsonb;current_status text;q integer;done integer;
BEGIN
 IF NOT public.restaurant_has_role() THEN RAISE EXCEPTION '需要員工權限' USING ERRCODE='42501'; END IF;
 IF kind='original' THEN ticket:=batch;
 ELSIF kind='addon' THEN SELECT ticket_id INTO ticket FROM public.restaurant_addons WHERE id=batch;
 ELSE RAISE EXCEPTION '出餐單類型不正確'; END IF;
 IF ticket IS NULL THEN RAISE EXCEPTION '找不到出餐單'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(ticket::text,0));
 IF NOT EXISTS(SELECT 1 FROM public.restaurant_kitchen WHERE id=ticket AND cancelled_at IS NULL) THEN RAISE EXCEPTION '桌單已取消，請查看異動通知' USING ERRCODE='22023'; END IF;
 IF kind='original' THEN SELECT initial_lines,status INTO lines,current_status FROM public.restaurant_kitchen WHERE id=batch FOR UPDATE;
 ELSE SELECT a.lines,a.status INTO lines,current_status FROM public.restaurant_addons a WHERE id=batch FOR UPDATE; END IF;
 SELECT (x->>'qty')::int INTO q FROM jsonb_array_elements(lines) x WHERE x->>'id'=item_id;
 SELECT coalesce((SELECT delivered FROM public.restaurant_delivery WHERE source=kind AND batch_id=batch AND menu_id=item_id),CASE WHEN current_status='served' THEN q ELSE 0 END) INTO done;
 IF q IS DISTINCT FROM expected_quantity OR done IS DISTINCT FROM expected_delivered OR done>=q THEN RAISE EXCEPTION '餐點或送餐進度已更新，請重新整理' USING ERRCODE='40001'; END IF;
 INSERT INTO public.restaurant_delivery(source,batch_id,menu_id,delivered) VALUES(kind,batch,item_id,done+1)
 ON CONFLICT ON CONSTRAINT restaurant_delivery_pkey DO UPDATE SET delivered=excluded.delivered;
 PERFORM public.restaurant_sync_batch(kind,batch);
END; $$;
CREATE OR REPLACE FUNCTION public.restaurant_batch_status(batch_id uuid,batch_source text,old_status text,new_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE ticket uuid;lines jsonb;current_status text;
BEGIN
 IF NOT public.restaurant_has_role() THEN RAISE EXCEPTION '需要員工權限' USING ERRCODE='42501'; END IF;
 IF NOT ((old_status='queued' AND new_status='preparing') OR (old_status='preparing' AND new_status='served')) THEN RAISE EXCEPTION '出餐狀態無效'; END IF;
 IF batch_source='original' THEN ticket:=batch_id;ELSIF batch_source='addon' THEN SELECT ticket_id INTO ticket FROM public.restaurant_addons WHERE id=batch_id;ELSE RAISE EXCEPTION '出餐單類型無效'; END IF;
 IF ticket IS NULL THEN RAISE EXCEPTION '找不到出餐單'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(ticket::text,0));
 IF NOT EXISTS(SELECT 1 FROM public.restaurant_kitchen WHERE id=ticket AND cancelled_at IS NULL) THEN RAISE EXCEPTION '桌單已取消'; END IF;
 IF batch_source='original' THEN SELECT initial_lines,status INTO lines,current_status FROM public.restaurant_kitchen WHERE id=batch_id FOR UPDATE;
 ELSE SELECT a.lines,a.status INTO lines,current_status FROM public.restaurant_addons a WHERE id=batch_id FOR UPDATE; END IF;
 IF current_status IS DISTINCT FROM old_status THEN RAISE EXCEPTION '出餐狀態已更新，請重新整理' USING ERRCODE='40001'; END IF;
 IF new_status='served' THEN
 INSERT INTO public.restaurant_delivery(source,batch_id,menu_id,delivered)
 SELECT batch_source,batch_id,x->>'id',(x->>'qty')::int FROM jsonb_array_elements(lines) x
 ON CONFLICT ON CONSTRAINT restaurant_delivery_pkey DO UPDATE SET delivered=excluded.delivered;
 END IF;
 IF batch_source='original' THEN UPDATE public.restaurant_kitchen SET status=new_status WHERE id=batch_id;
 ELSE UPDATE public.restaurant_addons SET status=new_status WHERE id=batch_id; END IF;
END; $$;

CREATE OR REPLACE FUNCTION public.restaurant_ticket_amend(ticket_id uuid,request_id uuid,expected jsonb,quantities jsonb,change_reason text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE k public.restaurant_kitchen;before_lines jsonb;after_lines jsonb:='[]';new_items jsonb:='{}';increases jsonb:='{}';
 line jsonb;target integer;remaining integer;b record;batch_lines jsonb;batch_line jsonb;oldq integer;take integer;done integer;updated jsonb;
 prior public.restaurant_ticket_changes;request_payload jsonb:=jsonb_build_object('expected',expected,'quantities',quantities,'reason',change_reason);
BEGIN
 IF NOT public.restaurant_is_cashier() THEN RAISE EXCEPTION '需要櫃台權限' USING ERRCODE='42501'; END IF;
 IF request_id IS NULL OR ticket_id IS NULL THEN RAISE EXCEPTION '缺少異動編號'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(ticket_id::text,0));
 SELECT * INTO prior FROM public.restaurant_ticket_changes c WHERE c.id=request_id;
 IF FOUND THEN IF prior.ticket_id<>ticket_id OR prior.payload IS DISTINCT FROM request_payload THEN RAISE EXCEPTION '異動編號已使用'; END IF; RETURN request_id; END IF;
 SELECT * INTO k FROM public.restaurant_kitchen WHERE id=ticket_id FOR UPDATE;
 IF NOT FOUND OR k.cancelled_at IS NOT NULL OR EXISTS(SELECT 1 FROM public.restaurant_sales WHERE id=ticket_id) THEN RAISE EXCEPTION '桌單已結帳或取消，請重新查詢' USING ERRCODE='22023'; END IF;
 before_lines:=public.restaurant_ticket_lines(k);
 IF expected IS DISTINCT FROM before_lines THEN RAISE EXCEPTION '餐點已被其他人更新，請重新叫回後修改' USING ERRCODE='40001'; END IF;
 IF length(btrim(coalesce(change_reason,''))) NOT BETWEEN 1 AND 200 OR jsonb_typeof(quantities) IS DISTINCT FROM 'object'
 OR (SELECT count(*) FROM jsonb_each(quantities))<>jsonb_array_length(before_lines) THEN RAISE EXCEPTION '請填寫異動原因及每項餐點份數' USING ERRCODE='22023'; END IF;
 FOR line IN SELECT value FROM jsonb_array_elements(before_lines) LOOP
  IF NOT quantities ? (line->>'id') OR jsonb_typeof(quantities->(line->>'id'))<>'number' OR quantities->>(line->>'id') !~ '^([0-9]|[1-9][0-9])$' THEN RAISE EXCEPTION '份數需為 0 至 99 的整數' USING ERRCODE='22023'; END IF;
  target:=(quantities->>(line->>'id'))::int;
  IF target>(line->>'qty')::int THEN increases:=increases||jsonb_build_object(line->>'id',target-(line->>'qty')::int); END IF;
  remaining:=greatest(0,(line->>'qty')::int-target);
  -- 先退尚未出餐的批次，再處理已送出的部分；每次異動會留下前後明細。
  FOR b IN SELECT * FROM (
    SELECT t.id,'original'::text AS source,t.initial_lines AS lines,t.status,t.created_at FROM public.restaurant_kitchen t WHERE t.id=k.id
    UNION ALL SELECT a.id,'addon',a.lines,a.status,a.created_at FROM public.restaurant_addons a WHERE a.ticket_id=k.id
   ) batches ORDER BY CASE status WHEN 'queued' THEN 0 WHEN 'preparing' THEN 1 ELSE 2 END,created_at DESC,id LOOP
   EXIT WHEN remaining=0;
   batch_lines:=b.lines;
   SELECT value INTO batch_line FROM jsonb_array_elements(coalesce(batch_lines,'[]')) WHERE value->>'id'=line->>'id';
   IF NOT FOUND THEN CONTINUE; END IF;
   oldq:=(batch_line->>'qty')::int;take:=least(remaining,oldq);remaining:=remaining-take;
   SELECT coalesce((SELECT delivered FROM public.restaurant_delivery WHERE source=b.source AND batch_id=b.id AND menu_id=line->>'id'),CASE WHEN b.status='served' THEN oldq ELSE 0 END) INTO done;
   SELECT coalesce(jsonb_agg(CASE WHEN x->>'id'=line->>'id' THEN x||jsonb_build_object('qty',oldq-take) ELSE x END),'[]'::jsonb)
    INTO updated FROM jsonb_array_elements(batch_lines) x WHERE x->>'id'<>line->>'id' OR oldq-take>0;
   INSERT INTO public.restaurant_delivery(source,batch_id,menu_id,delivered) VALUES(b.source,b.id,line->>'id',least(done,oldq-take))
    ON CONFLICT ON CONSTRAINT restaurant_delivery_pkey DO UPDATE SET delivered=excluded.delivered;
   IF b.source='original' THEN UPDATE public.restaurant_kitchen SET initial_lines=updated WHERE id=k.id;
   ELSE UPDATE public.restaurant_addons SET lines=updated WHERE id=b.id; END IF;
   UPDATE public.restaurant_guest_orders SET lines=updated,reason='店員已調整餐點：'||change_reason,
    status=CASE WHEN updated='[]'::jsonb THEN 'rejected' ELSE status END WHERE batch_id=b.id AND status='accepted';
   PERFORM public.restaurant_sync_batch(b.source,b.id);
  END LOOP;
  IF remaining<>0 THEN RAISE EXCEPTION '餐點批次資料不一致，請洽管理者' USING ERRCODE='22023'; END IF;
  IF least(target,(line->>'qty')::int)>0 THEN
   after_lines:=after_lines||jsonb_build_array(line||jsonb_build_object('qty',least(target,(line->>'qty')::int)));
   new_items:=new_items||jsonb_build_object(line->>'id',least(target,(line->>'qty')::int));
  END IF;
 END LOOP;
 UPDATE public.restaurant_kitchen SET items=new_items,lines=after_lines WHERE id=k.id;
 IF increases<>'{}'::jsonb THEN PERFORM public.restaurant_add_items(k.id,request_id,increases); END IF;
 SELECT public.restaurant_ticket_lines(t) INTO after_lines FROM public.restaurant_kitchen t WHERE t.id=k.id;
 IF before_lines<>'[]'::jsonb AND before_lines=after_lines THEN RAISE EXCEPTION '尚未變更份數' USING ERRCODE='22023'; END IF;
 IF after_lines='[]'::jsonb THEN
  UPDATE public.restaurant_kitchen SET cancelled_at=now() WHERE id=k.id;
  UPDATE public.restaurant_guest_orders o SET status='rejected',reason='整桌取消：'||change_reason,reviewed_at=now(),reviewed_by=auth.uid()
   WHERE o.status='pending' AND o.session_id IN (SELECT d.id FROM public.restaurant_dining_sessions d WHERE d.ticket_id=k.id);
  UPDATE public.restaurant_dining_sessions d SET closed_at=now() WHERE d.ticket_id=k.id AND d.closed_at IS NULL;
 END IF;
 INSERT INTO public.restaurant_ticket_changes(id,ticket_id,table_label,service,before_lines,after_lines,reason,payload,actor)
 VALUES(request_id,k.id,k.table_label,k.service,before_lines,after_lines,btrim(change_reason),request_payload,auth.uid());
 RETURN request_id;
END; $$;
CREATE OR REPLACE FUNCTION public.restaurant_ticket_change_list()
RETURNS TABLE(id uuid,ticket_id uuid,table_label text,service text,before_lines jsonb,after_lines jsonb,reason text,created_at timestamptz,kitchen_seen_at timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT id,ticket_id,table_label,service,before_lines,after_lines,reason,created_at,kitchen_seen_at FROM public.restaurant_ticket_changes
 WHERE public.restaurant_has_role() AND (kitchen_seen_at IS NULL OR created_at>=(now() AT TIME ZONE 'Asia/Taipei')::date AT TIME ZONE 'Asia/Taipei') ORDER BY created_at DESC
$$;
CREATE OR REPLACE FUNCTION public.restaurant_ticket_change_ack(change_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT public.restaurant_has_role() THEN RAISE EXCEPTION '需要員工權限' USING ERRCODE='42501'; END IF;
 UPDATE public.restaurant_ticket_changes SET kitchen_seen_at=coalesce(kitchen_seen_at,now()),seen_by=coalesce(seen_by,auth.uid()) WHERE id=change_id;
 IF NOT FOUND THEN RAISE EXCEPTION '找不到異動紀錄'; END IF;
END; $$;
CREATE OR REPLACE FUNCTION public.restaurant_close_report(report_day date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE start_at timestamptz;end_at timestamptz;result jsonb;
BEGIN
 IF NOT public.restaurant_is_cashier() THEN RAISE EXCEPTION '需要櫃台權限' USING ERRCODE='42501'; END IF;
 IF report_day IS NULL THEN RAISE EXCEPTION '請選日期'; END IF;
 start_at:=report_day::timestamp AT TIME ZONE 'Asia/Taipei';end_at:=(report_day+1)::timestamp AT TIME ZONE 'Asia/Taipei';
 SELECT jsonb_build_object('day',report_day,'count',count(*),'subtotal',coalesce(sum(s.subtotal),0),
 'discount',coalesce(sum(s.discount_amount),0),'revenue',coalesce(sum(s.total),0),
 'cash',coalesce(sum(s.total) FILTER(WHERE s.payment='現金'),0),
 'card',coalesce(sum(s.total) FILTER(WHERE s.payment='刷卡'),0),
 'mobile',coalesce(sum(s.total) FILTER(WHERE s.payment='行動支付'),0)) INTO result
 FROM public.restaurant_sales s WHERE s.created_at>=start_at AND s.created_at<end_at AND s.deleted_at IS NULL;
 RETURN result||jsonb_build_object('cancelled',(SELECT count(*) FROM public.restaurant_kitchen WHERE cancelled_at>=start_at AND cancelled_at<end_at),
 'unpaid',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.restaurant_open_tables() t),
 'sales',(SELECT coalesce(jsonb_agg(to_jsonb(s) ORDER BY s.created_at),'[]') FROM
 (SELECT id,service,table_label,payment,subtotal,discount_amount,total,created_at FROM public.restaurant_sales WHERE created_at>=start_at AND created_at<end_at AND deleted_at IS NULL) s));
END; $$;
REVOKE ALL ON FUNCTION public.restaurant_unavailable_guard(),public.restaurant_sync_batch(text,uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.restaurant_set_sold_out(text,boolean),public.restaurant_delivery_rows(),public.restaurant_deliver_item(text,uuid,text,integer,integer),
 public.restaurant_ticket_amend(uuid,uuid,jsonb,jsonb,text),public.restaurant_ticket_change_list(),public.restaurant_ticket_change_ack(uuid),public.restaurant_close_report(date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.restaurant_set_sold_out(text,boolean),public.restaurant_delivery_rows(),public.restaurant_deliver_item(text,uuid,text,integer,integer),
 public.restaurant_ticket_amend(uuid,uuid,jsonb,jsonb,text),public.restaurant_ticket_change_list(),public.restaurant_ticket_change_ack(uuid),public.restaurant_close_report(date) TO authenticated;

CREATE OR REPLACE FUNCTION public.restaurant_lock_table_ticket() RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF NEW.service='內用' THEN
    NEW.table_label:=upper(btrim(NEW.table_label));
    PERFORM pg_advisory_xact_lock(hashtextextended('linglan:table:'||NEW.table_label,0));
    IF EXISTS(SELECT 1 FROM public.restaurant_kitchen k WHERE k.cancelled_at IS NULL AND k.service='內用'
       AND upper(btrim(k.table_label))=NEW.table_label
       AND NOT EXISTS(SELECT 1 FROM public.restaurant_sales s WHERE s.id=k.id)) THEN
      RAISE EXCEPTION '此桌已有待結帳單，請從待結帳清單叫回原單' USING ERRCODE='23505';
    END IF;
  END IF;
  SELECT jsonb_agg(jsonb_build_object('id',m.id,'name',m.name,'price',m.price,'qty',(e.value::text)::int))
  INTO NEW.lines FROM jsonb_each(NEW.items) e JOIN public.restaurant_menu m ON m.id=e.key;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.restaurant_checkout_before_discount(sale_id uuid,service_mode text,table_name text,payment_mode text,items jsonb)
RETURNS public.restaurant_sales LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  ticket public.restaurant_kitchen;
  result public.restaurant_sales;
  snapshot jsonb;
  amount integer;
  label text := CASE WHEN service_mode='內用' THEN btrim(coalesce(table_name,'')) ELSE '' END;
BEGIN
  IF NOT public.restaurant_is_cashier() THEN RAISE EXCEPTION '需要櫃台權限' USING ERRCODE='42501'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(sale_id::text,0));
  SELECT * INTO ticket FROM public.restaurant_kitchen k WHERE k.id=sale_id;
  IF FOUND AND ticket.cancelled_at IS NOT NULL THEN RAISE EXCEPTION '桌單已取消，不能結帳' USING ERRCODE='22023'; END IF;
  IF NOT FOUND THEN
    IF service_mode='內用' THEN
      PERFORM pg_advisory_xact_lock(hashtextextended('linglan:table:'||upper(label),0));
      IF EXISTS(SELECT 1 FROM public.restaurant_kitchen k WHERE k.cancelled_at IS NULL AND k.service='內用'
         AND upper(btrim(k.table_label))=upper(label)
         AND NOT EXISTS(SELECT 1 FROM public.restaurant_sales s WHERE s.id=k.id)) THEN
        RAISE EXCEPTION '此桌已有待結帳單，請從待結帳清單叫回原單' USING ERRCODE='23505';
      END IF;
    END IF;
    RETURN public.restaurant_checkout_v1(sale_id,service_mode,table_name,payment_mode,items);
  END IF;
  IF ticket.service IS DISTINCT FROM service_mode OR ticket.items IS DISTINCT FROM items
     OR upper(ticket.table_label) IS DISTINCT FROM upper(label) THEN
    RAISE EXCEPTION '餐點或桌號與已送出的出餐單不符' USING ERRCODE='22023';
  END IF;
  SELECT * INTO result FROM public.restaurant_sales s WHERE s.id=sale_id;
  IF FOUND THEN
    IF result.payment IS DISTINCT FROM payment_mode THEN
      RAISE EXCEPTION '此桌已結帳，付款方式為 %',result.payment USING ERRCODE='23505';
    END IF;
    RETURN result;
  END IF;
  snapshot:=public.restaurant_ticket_lines(ticket);
  SELECT sum(x.price*x.qty) INTO amount FROM jsonb_to_recordset(snapshot) x(price integer,qty integer);
  IF amount IS NULL THEN RAISE EXCEPTION '待結帳單缺少餐點資料' USING ERRCODE='22023'; END IF;
  INSERT INTO public.restaurant_sales(id,service,table_label,payment,total,created_by,request_items)
  VALUES(sale_id,ticket.service,ticket.table_label,payment_mode,amount,auth.uid(),ticket.items)
  RETURNING * INTO result;
  INSERT INTO public.restaurant_sale_items(sale_id,menu_id,name,unit_price,quantity)
  SELECT sale_id,x.id,x.name,x.price,x.qty
  FROM jsonb_to_recordset(snapshot) x(id text,name text,price integer,qty integer);
  RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION public.restaurant_open_tables()
RETURNS TABLE(id uuid,service text,table_label text,status text,created_at timestamptz,lines jsonb)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT k.id,k.service,k.table_label,
   CASE WHEN k.status='queued' OR EXISTS(SELECT 1 FROM public.restaurant_addons a WHERE a.ticket_id=k.id AND a.status='queued') THEN 'queued'
        WHEN k.status='preparing' OR EXISTS(SELECT 1 FROM public.restaurant_addons a WHERE a.ticket_id=k.id AND a.status='preparing') THEN 'preparing'
        ELSE 'served' END,
   k.created_at,public.restaurant_ticket_lines(k)
 FROM public.restaurant_kitchen k WHERE k.cancelled_at IS NULL AND public.restaurant_is_cashier()
 AND NOT EXISTS(SELECT 1 FROM public.restaurant_sales s WHERE s.id=k.id) ORDER BY k.created_at
$$;

CREATE OR REPLACE FUNCTION public.restaurant_kitchen_batches()
RETURNS TABLE(id uuid,source text,service text,table_label text,lines jsonb,status text,created_at timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT k.id,'original'::text,k.service,k.table_label,coalesce(k.initial_lines,k.lines),k.status,k.created_at
 FROM public.restaurant_kitchen k WHERE k.cancelled_at IS NULL AND public.restaurant_has_role() AND jsonb_array_length(coalesce(k.initial_lines,k.lines,'[]'))>0 AND
 (k.status<>'served' OR k.created_at>=(now() AT TIME ZONE 'Asia/Taipei')::date AT TIME ZONE 'Asia/Taipei')
 UNION ALL
 SELECT a.id,'addon'::text,k.service,k.table_label,a.lines,a.status,a.created_at
 FROM public.restaurant_addons a JOIN public.restaurant_kitchen k ON k.id=a.ticket_id WHERE k.cancelled_at IS NULL AND public.restaurant_has_role() AND jsonb_array_length(a.lines)>0 AND
 (a.status<>'served' OR a.created_at>=(now() AT TIME ZONE 'Asia/Taipei')::date AT TIME ZONE 'Asia/Taipei') ORDER BY created_at DESC
$$;

CREATE OR REPLACE FUNCTION public.restaurant_guest_submit(table_key uuid,request_id uuid,requested jsonb,order_note text DEFAULT '',visit_key uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE t public.restaurant_qr_tables; d public.restaurant_dining_sessions; ticket uuid; prior public.restaurant_guest_orders; e record; line jsonb; snapshot jsonb:='[]'; original jsonb;
BEGIN
 SELECT * INTO t FROM public.restaurant_qr_tables WHERE id=table_key;
 IF NOT FOUND OR NOT t.active THEN RAISE EXCEPTION '此桌未開放點餐，請洽店員' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('linglan:table:'||t.table_label,0));
 SELECT * INTO prior FROM public.restaurant_guest_orders WHERE id=request_id;
 IF FOUND THEN
  IF NOT EXISTS(SELECT 1 FROM public.restaurant_dining_sessions WHERE id=prior.session_id AND qr_table_id=table_key)
   OR prior.requested IS DISTINCT FROM requested OR prior.note<>coalesce(order_note,'') THEN RAISE EXCEPTION '點餐編號已使用' USING ERRCODE='22023'; END IF;
  RETURN jsonb_build_object('id',prior.id,'status',prior.status,'session_id',prior.session_id);
 END IF;
 SELECT * INTO d FROM public.restaurant_dining_sessions WHERE qr_table_id=table_key AND closed_at IS NULL;
 IF d.id IS NOT NULL THEN
  PERFORM pg_advisory_xact_lock(hashtextextended(d.ticket_id::text,0));
  SELECT * INTO d FROM public.restaurant_dining_sessions WHERE qr_table_id=table_key AND closed_at IS NULL FOR UPDATE;
 END IF;
 IF visit_key IS NOT NULL AND visit_key IS DISTINCT FROM d.id THEN
  RAISE EXCEPTION '上一批用餐已結束，若是本次用餐請按「開始新的用餐」' USING ERRCODE='22023'; END IF;
 IF d.id IS NULL THEN
  SELECT k.id INTO ticket FROM public.restaurant_kitchen k WHERE k.cancelled_at IS NULL AND k.service='內用' AND upper(btrim(k.table_label))=t.table_label
    AND NOT EXISTS(SELECT 1 FROM public.restaurant_sales s WHERE s.id=k.id) LIMIT 1;
  IF ticket IS NULL THEN
   ticket:=gen_random_uuid();
   INSERT INTO public.restaurant_kitchen(id,service,table_label,items,lines,status) VALUES(ticket,'內用',t.table_label,'{}','[]','served');
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(ticket::text,0));
  INSERT INTO public.restaurant_dining_sessions(table_label,ticket_id,qr_table_id,opened_by)
   VALUES(t.table_label,ticket,table_key,coalesce(auth.uid(),'00000000-0000-0000-0000-000000000000'::uuid)) RETURNING * INTO d;
 END IF;
 IF d.closed_at IS NOT NULL OR d.expires_at<=now() OR EXISTS(SELECT 1 FROM public.restaurant_sales WHERE id=d.ticket_id) THEN
  RAISE EXCEPTION '本次用餐已結束或連結已到期，請洽店員' USING ERRCODE='22023'; END IF;
 IF request_id IS NULL OR jsonb_typeof(requested) IS DISTINCT FROM 'object' OR requested='{}'::jsonb OR length(coalesce(order_note,''))>300 THEN
  RAISE EXCEPTION '請確認餐點及備註' USING ERRCODE='22023'; END IF;
 IF (SELECT count(*) FROM jsonb_each(requested))>30 THEN RAISE EXCEPTION '每次最多 30 種餐點' USING ERRCODE='22023'; END IF;
 IF (SELECT count(*) FROM public.restaurant_guest_orders WHERE session_id=d.id AND status='pending')>=20
 OR (SELECT count(*) FROM public.restaurant_guest_orders WHERE session_id=d.id)>=200
 OR EXISTS(SELECT 1 FROM public.restaurant_guest_orders WHERE session_id=d.id AND created_at>now()-interval '2 seconds') THEN
  RAISE EXCEPTION '送單較頻繁，請稍後再試或洽店員' USING ERRCODE='22023'; END IF;
 SELECT public.restaurant_ticket_lines(k) INTO original FROM public.restaurant_kitchen k WHERE id=d.ticket_id;
 FOR e IN SELECT j.key,j.value,m.name,m.price FROM jsonb_each(requested) j LEFT JOIN public.restaurant_menu m ON m.id=j.key AND m.active AND m.sold_out_date IS DISTINCT FROM (now() AT TIME ZONE 'Asia/Taipei')::date LOOP
  IF e.name IS NULL OR jsonb_typeof(e.value)<>'number' OR e.value::text !~ '^[1-9][0-9]?$' THEN
   RAISE EXCEPTION '餐點已下架或份數無效，請重新整理' USING ERRCODE='22023'; END IF;
  SELECT value INTO line FROM jsonb_array_elements(coalesce(original,'[]')) WHERE value->>'id'=e.key;
  snapshot:=snapshot||jsonb_build_array(jsonb_build_object('id',e.key,'name',coalesce(line->>'name',e.name),'price',coalesce((line->>'price')::int,e.price),'qty',(e.value::text)::int));
 END LOOP;
 INSERT INTO public.restaurant_guest_orders(id,session_id,requested,lines,note) VALUES(request_id,d.id,requested,snapshot,coalesce(order_note,''));
 RETURN jsonb_build_object('id',request_id,'status','pending','session_id',d.id);
END; $$;

-- Original migration 2-11
-- 接續 v2.10：櫃台每次送單與加點備註。

ALTER TABLE public.restaurant_kitchen ADD COLUMN IF NOT EXISTS staff_note text NOT NULL DEFAULT '' CHECK(length(staff_note)<=300);
ALTER TABLE public.restaurant_addons ADD COLUMN IF NOT EXISTS staff_note text NOT NULL DEFAULT '' CHECK(length(staff_note)<=300);
ALTER TABLE public.restaurant_sales ADD COLUMN IF NOT EXISTS staff_note text NOT NULL DEFAULT '';
GRANT SELECT(staff_note) ON public.restaurant_sales TO authenticated;
CREATE OR REPLACE FUNCTION public.restaurant_send_kitchen_note(ticket_id uuid,mode text,table_name text,requested jsonb,order_note text DEFAULT '')
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE note text:=btrim(coalesce(order_note,''));prior text;result uuid;
BEGIN
 IF NOT public.restaurant_is_cashier() THEN RAISE EXCEPTION '需要櫃台權限' USING ERRCODE='42501'; END IF;
 IF length(note)>300 THEN RAISE EXCEPTION '備註最多 300 字' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(ticket_id::text,0));
 SELECT k.staff_note INTO prior FROM public.restaurant_kitchen k WHERE k.id=ticket_id;
 IF FOUND AND prior IS DISTINCT FROM note THEN RAISE EXCEPTION '送單備註與原單不符，請用原內容重試' USING ERRCODE='22023'; END IF;
 result:=public.restaurant_send_kitchen(ticket_id,mode,table_name,requested);
 UPDATE public.restaurant_kitchen k SET staff_note=note WHERE k.id=result;
 RETURN result;
END; $$;
CREATE OR REPLACE FUNCTION public.restaurant_add_items_note(ticket_id uuid,request_id uuid,requested jsonb,order_note text DEFAULT '')
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE note text:=btrim(coalesce(order_note,''));prior text;result uuid;
BEGIN
 IF NOT public.restaurant_is_cashier() THEN RAISE EXCEPTION '需要櫃台權限' USING ERRCODE='42501'; END IF;
 IF length(note)>300 THEN RAISE EXCEPTION '備註最多 300 字' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(ticket_id::text,0));
 SELECT a.staff_note INTO prior FROM public.restaurant_addons a WHERE a.id=request_id;
 IF FOUND AND prior IS DISTINCT FROM note THEN RAISE EXCEPTION '加點備註與原單不符，請用原內容重試' USING ERRCODE='22023'; END IF;
 result:=public.restaurant_add_items(ticket_id,request_id,requested);
 UPDATE public.restaurant_addons a SET staff_note=note WHERE a.id=result;
 RETURN result;
END; $$;
CREATE OR REPLACE FUNCTION public.restaurant_staff_kitchen_notes()
RETURNS TABLE(batch_id uuid,source text,ticket_id uuid,note text,created_at timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT k.id,'original'::text,k.id,k.staff_note,k.created_at FROM public.restaurant_kitchen k
 WHERE public.restaurant_has_role() AND k.staff_note<>'' AND k.cancelled_at IS NULL
 AND (k.status<>'served' OR k.created_at>=now()-interval '7 days' OR NOT EXISTS(SELECT 1 FROM public.restaurant_sales s WHERE s.id=k.id))
 UNION ALL
 SELECT a.id,'addon'::text,k.id,a.staff_note,a.created_at FROM public.restaurant_addons a JOIN public.restaurant_kitchen k ON k.id=a.ticket_id
 WHERE public.restaurant_has_role() AND a.staff_note<>'' AND k.cancelled_at IS NULL
 AND (a.status<>'served' OR a.created_at>=now()-interval '7 days' OR NOT EXISTS(SELECT 1 FROM public.restaurant_sales s WHERE s.id=k.id))
 ORDER BY created_at
$$;
CREATE OR REPLACE FUNCTION public.restaurant_checkout_note(sale_id uuid,service_mode text,table_name text,payment_mode text,items jsonb,discount integer DEFAULT 0,order_note text DEFAULT '')
RETURNS public.restaurant_sales LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE note text:=btrim(coalesce(order_note,''));existing text;result public.restaurant_sales;
BEGIN
 IF NOT public.restaurant_is_cashier() THEN RAISE EXCEPTION '需要櫃台權限' USING ERRCODE='42501'; END IF;
 IF length(note)>300 THEN RAISE EXCEPTION '備註最多 300 字' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(sale_id::text,0));
 IF EXISTS(SELECT 1 FROM public.restaurant_kitchen k WHERE k.id=sale_id) THEN
  SELECT string_agg(n.note,E'\n' ORDER BY n.created_at,n.note) INTO existing FROM (
   SELECT '首次點餐：'||k.staff_note AS note,k.created_at FROM public.restaurant_kitchen k WHERE k.id=sale_id AND k.staff_note<>''
   UNION ALL SELECT '加點：'||a.staff_note,a.created_at FROM public.restaurant_addons a WHERE a.ticket_id=sale_id AND a.staff_note<>''
  ) n;
  note:=coalesce(existing,'');
 END IF;
 SELECT s.staff_note INTO existing FROM public.restaurant_sales s WHERE s.id=sale_id;
 IF FOUND AND existing IS DISTINCT FROM note THEN RAISE EXCEPTION '結帳備註與原交易不同，請核對原單' USING ERRCODE='22023'; END IF;
 result:=public.restaurant_checkout_discount(sale_id,service_mode,table_name,payment_mode,items,discount);
 UPDATE public.restaurant_sales s SET staff_note=note WHERE s.id=sale_id RETURNING * INTO result;
 RETURN result;
END; $$;
REVOKE ALL ON FUNCTION public.restaurant_send_kitchen_note(uuid,text,text,jsonb,text),public.restaurant_add_items_note(uuid,uuid,jsonb,text),
 public.restaurant_staff_kitchen_notes(),public.restaurant_checkout_note(uuid,text,text,text,jsonb,integer,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.restaurant_send_kitchen_note(uuid,text,text,jsonb,text),public.restaurant_add_items_note(uuid,uuid,jsonb,text),
 public.restaurant_staff_kitchen_notes(),public.restaurant_checkout_note(uuid,text,text,text,jsonb,integer,text) TO authenticated;

-- Original migration 2-12
-- 接續 v2.11。主桌單仍按餐點計價，另保存每筆不同需求及送餐進度。

CREATE TABLE IF NOT EXISTS public.restaurant_variant_batches (
 source text NOT NULL CHECK(source IN ('original','addon','guest')),batch_id uuid NOT NULL,
 request_lines jsonb NOT NULL,lines jsonb NOT NULL,PRIMARY KEY(source,batch_id)
);
CREATE TABLE IF NOT EXISTS public.restaurant_variant_delivery (
 source text NOT NULL,batch_id uuid NOT NULL,line_id text NOT NULL,delivered integer NOT NULL CHECK(delivered>=0),
 PRIMARY KEY(source,batch_id,line_id)
);
CREATE TABLE IF NOT EXISTS public.restaurant_sale_line_details (
 sale_id uuid PRIMARY KEY REFERENCES public.restaurant_sales(id),lines jsonb NOT NULL,request_lines jsonb
);
ALTER TABLE public.restaurant_variant_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.restaurant_variant_delivery ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.restaurant_sale_line_details ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.restaurant_variant_batches,public.restaurant_variant_delivery,public.restaurant_sale_line_details FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.restaurant_normalize_variants(input_lines jsonb)
RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $$
DECLARE row jsonb;raw jsonb:='[]';ids text[]:='{}';items jsonb:='{}';quantity integer;key text;note text;
BEGIN
 IF jsonb_typeof(input_lines) IS DISTINCT FROM 'array' OR jsonb_array_length(input_lines) NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION '每次請選擇 1 至 100 筆餐點' USING ERRCODE='22023'; END IF;
 FOR row IN SELECT value FROM jsonb_array_elements(input_lines) LOOP
  key:=row->>'line_id';note:=btrim(coalesce(row->>'note',''));
  IF key IS NULL OR key !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' OR key=ANY(ids)
   OR jsonb_typeof(row->'menu_id') IS DISTINCT FROM 'string' OR length(row->>'menu_id') NOT BETWEEN 1 AND 150
   OR jsonb_typeof(row->'qty') IS DISTINCT FROM 'number' OR (row->>'qty') !~ '^[1-9][0-9]?$' OR length(note)>300 THEN
   RAISE EXCEPTION '請確認每筆餐點編號、份數及備註（最多 300 字）' USING ERRCODE='22023'; END IF;
  quantity:=(row->>'qty')::int;ids:=array_append(ids,key);
  items:=items||jsonb_build_object(row->>'menu_id',coalesce((items->>(row->>'menu_id'))::int,0)+quantity);
  IF (items->>(row->>'menu_id'))::int>99 THEN RAISE EXCEPTION '同品項每次總份數不可超過 99' USING ERRCODE='22023'; END IF;
  raw:=raw||jsonb_build_array(jsonb_build_object('line_id',key,'menu_id',row->>'menu_id','qty',quantity,'note',note));
 END LOOP;
 RETURN jsonb_build_object('items',items,'raw',raw);
END; $$;
CREATE OR REPLACE FUNCTION public.restaurant_snapshot_variants(raw jsonb,priced jsonb)
RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $$
DECLARE row jsonb;item jsonb;result jsonb:='[]';
BEGIN
 FOR row IN SELECT value FROM jsonb_array_elements(raw) LOOP
  SELECT value INTO item FROM jsonb_array_elements(priced) WHERE value->>'id'=row->>'menu_id';
  IF NOT FOUND THEN RAISE EXCEPTION '餐點計價資料不完整，請重新整理' USING ERRCODE='22023'; END IF;
  result:=result||jsonb_build_array(jsonb_build_object('id',row->>'line_id','menu_id',row->>'menu_id',
   'name',item->>'name','price',(item->>'price')::int,'qty',(row->>'qty')::int,'note',row->>'note'));
 END LOOP;
 RETURN result;
END; $$;
CREATE OR REPLACE FUNCTION public.restaurant_variant_lines(kind text,batch uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
 SELECT lines INTO result FROM public.restaurant_variant_batches WHERE source=kind AND batch_id=batch;
 IF FOUND THEN RETURN result; END IF;
 IF kind='original' THEN SELECT coalesce(k.initial_lines,k.lines) INTO result FROM public.restaurant_kitchen k WHERE id=batch;
 ELSIF kind='addon' THEN SELECT a.lines INTO result FROM public.restaurant_addons a WHERE id=batch;
 ELSIF kind='guest' THEN SELECT o.lines INTO result FROM public.restaurant_guest_orders o WHERE id=batch;
 ELSE RETURN '[]'; END IF;
 RETURN coalesce((SELECT jsonb_agg(x||jsonb_build_object('menu_id',x->>'id','note','')) FROM jsonb_array_elements(coalesce(result,'[]')) x),'[]');
END; $$;
CREATE OR REPLACE FUNCTION public.restaurant_ticket_variant_snapshot(ticket uuid)
RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT coalesce(jsonb_agg(x||jsonb_build_object('source',b.source,'batch_id',b.id) ORDER BY b.created_at,b.id,x->>'id'),'[]') FROM
 (SELECT k.id,'original'::text AS source,k.created_at FROM public.restaurant_kitchen k WHERE k.id=ticket
 UNION ALL SELECT a.id,'addon',a.created_at FROM public.restaurant_addons a WHERE a.ticket_id=ticket) b
 CROSS JOIN LATERAL jsonb_array_elements(public.restaurant_variant_lines(b.source,b.id)) x
$$;
CREATE OR REPLACE FUNCTION public.restaurant_send_kitchen_lines(ticket_id uuid,mode text,table_name text,request_lines jsonb,order_note text DEFAULT '')
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE normalized jsonb;prior jsonb;priced jsonb;
BEGIN
 IF NOT public.restaurant_is_cashier() THEN RAISE EXCEPTION '需要櫃台權限' USING ERRCODE='42501'; END IF;
 normalized:=public.restaurant_normalize_variants(request_lines);
 PERFORM pg_advisory_xact_lock(hashtextextended(ticket_id::text,0));
 SELECT v.request_lines INTO prior FROM public.restaurant_variant_batches v WHERE v.source='original' AND v.batch_id=ticket_id;
 IF FOUND AND prior IS DISTINCT FROM normalized->'raw' THEN RAISE EXCEPTION '逐筆需求與原單不符，請用原內容重試' USING ERRCODE='22023'; END IF;
 PERFORM public.restaurant_send_kitchen_note(ticket_id,mode,table_name,normalized->'items',order_note);
 IF prior IS NULL THEN
  SELECT public.restaurant_ticket_lines(k) INTO priced FROM public.restaurant_kitchen k WHERE id=ticket_id;
  INSERT INTO public.restaurant_variant_batches VALUES('original',ticket_id,normalized->'raw',public.restaurant_snapshot_variants(normalized->'raw',priced));
 END IF;
 RETURN ticket_id;
END; $$;
CREATE OR REPLACE FUNCTION public.restaurant_add_items_lines(ticket_id uuid,request_id uuid,request_lines jsonb,order_note text DEFAULT '')
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE normalized jsonb;prior jsonb;priced jsonb;
BEGIN
 IF NOT public.restaurant_is_cashier() THEN RAISE EXCEPTION '需要櫃台權限' USING ERRCODE='42501'; END IF;
 normalized:=public.restaurant_normalize_variants(request_lines);
 PERFORM pg_advisory_xact_lock(hashtextextended(ticket_id::text,0));
 SELECT v.request_lines INTO prior FROM public.restaurant_variant_batches v WHERE v.source='addon' AND v.batch_id=request_id;
 IF FOUND AND prior IS DISTINCT FROM normalized->'raw' THEN RAISE EXCEPTION '加點逐筆需求與原單不符，請用原內容重試' USING ERRCODE='22023'; END IF;
 PERFORM public.restaurant_add_items_note(ticket_id,request_id,normalized->'items',order_note);
 IF prior IS NULL THEN
  SELECT a.lines INTO priced FROM public.restaurant_addons a WHERE id=request_id;
  INSERT INTO public.restaurant_variant_batches VALUES('addon',request_id,normalized->'raw',public.restaurant_snapshot_variants(normalized->'raw',priced));
 END IF;
 RETURN request_id;
END; $$;
CREATE OR REPLACE FUNCTION public.restaurant_guest_submit_lines(table_key uuid,request_id uuid,request_lines jsonb,order_note text DEFAULT '',visit_key uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE normalized jsonb;prior jsonb;priced jsonb;result jsonb;label text;
BEGIN
 normalized:=public.restaurant_normalize_variants(request_lines);
 SELECT table_label INTO label FROM public.restaurant_qr_tables WHERE id=table_key AND active;
 IF NOT FOUND THEN RAISE EXCEPTION '此桌未開放點餐，請洽店員' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('linglan:table:'||label,0));
 SELECT v.request_lines INTO prior FROM public.restaurant_variant_batches v WHERE v.source='guest' AND v.batch_id=request_id;
 IF FOUND AND prior IS DISTINCT FROM normalized->'raw' THEN RAISE EXCEPTION '逐筆需求與原客單不符，請用原內容重試' USING ERRCODE='22023'; END IF;
 result:=public.restaurant_guest_submit(table_key,request_id,normalized->'items',order_note,visit_key);
 IF prior IS NULL THEN
  SELECT o.lines INTO priced FROM public.restaurant_guest_orders o WHERE o.id=request_id;
  INSERT INTO public.restaurant_variant_batches VALUES('guest',request_id,normalized->'raw',public.restaurant_snapshot_variants(normalized->'raw',priced));
 END IF;
 RETURN result;
END; $$;
CREATE OR REPLACE FUNCTION public.restaurant_guest_review_lines(order_id uuid,accept_order boolean)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result text;raw jsonb;priced jsonb;ticket uuid;
BEGIN
 IF NOT public.restaurant_is_cashier() THEN RAISE EXCEPTION '需要櫃台權限' USING ERRCODE='42501'; END IF;
 SELECT d.ticket_id INTO ticket FROM public.restaurant_guest_orders o JOIN public.restaurant_dining_sessions d ON d.id=o.session_id WHERE o.id=order_id;
 PERFORM pg_advisory_xact_lock(hashtextextended(ticket::text,0));
 result:=public.restaurant_guest_review(order_id,accept_order);
 IF result='accepted' AND NOT EXISTS(SELECT 1 FROM public.restaurant_variant_batches WHERE source='addon' AND batch_id=order_id) THEN
  SELECT request_lines INTO raw FROM public.restaurant_variant_batches WHERE source='guest' AND batch_id=order_id;
  IF FOUND THEN SELECT a.lines INTO priced FROM public.restaurant_addons a WHERE a.id=order_id;
   INSERT INTO public.restaurant_variant_batches VALUES('addon',order_id,raw,public.restaurant_snapshot_variants(raw,priced)); END IF;
 END IF;
 RETURN result;
END; $$;
CREATE OR REPLACE FUNCTION public.restaurant_guest_pending_lines()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT coalesce(jsonb_agg(to_jsonb(o)||jsonb_build_object('lines',public.restaurant_variant_lines('guest',o.id)) ORDER BY o.created_at),'[]') FROM public.restaurant_guest_pending() o
$$;
CREATE OR REPLACE FUNCTION public.restaurant_guest_view_lines(table_key uuid,visit_key uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;orders jsonb:='[]';o jsonb;batch uuid;kind text;
BEGIN
 result:=public.restaurant_guest_view(table_key,visit_key);
 FOR o IN SELECT value FROM jsonb_array_elements(result->'orders') LOOP
  batch:=(o->>'id')::uuid;kind:=CASE WHEN o->>'status'='accepted' THEN 'addon' ELSE 'guest' END;
  orders:=orders||jsonb_build_array(o||jsonb_build_object('lines',public.restaurant_variant_lines(kind,batch)));
 END LOOP;
 RETURN result||jsonb_build_object('orders',orders);
END; $$;
CREATE OR REPLACE FUNCTION public.restaurant_open_tables_lines()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT coalesce(jsonb_agg(to_jsonb(t)||jsonb_build_object('variant_lines',public.restaurant_ticket_variant_snapshot(t.id)) ORDER BY t.created_at),'[]') FROM public.restaurant_open_tables() t
$$;
CREATE OR REPLACE FUNCTION public.restaurant_kitchen_variant_batches()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT coalesce(jsonb_agg(to_jsonb(b)||jsonb_build_object('lines',public.restaurant_variant_lines(b.source,b.id)) ORDER BY b.created_at DESC),'[]') FROM public.restaurant_kitchen_batches() b
$$;
CREATE OR REPLACE FUNCTION public.restaurant_delivery_rows()
RETURNS TABLE(source text,batch_id uuid,menu_id text,quantity integer,delivered integer)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT b.source,b.id,x->>'id',(x->>'qty')::int,
 coalesce(v.delivered,p.delivered,CASE WHEN b.status='served' THEN (x->>'qty')::int ELSE 0 END)
 FROM public.restaurant_kitchen_batches() b CROSS JOIN LATERAL jsonb_array_elements(public.restaurant_variant_lines(b.source,b.id)) x
 LEFT JOIN public.restaurant_variant_delivery v ON v.source=b.source AND v.batch_id=b.id AND v.line_id=x->>'id'
 LEFT JOIN public.restaurant_delivery p ON p.source=b.source AND p.batch_id=b.id AND p.menu_id=x->>'id'
 WHERE public.restaurant_has_role()
$$;
CREATE OR REPLACE FUNCTION public.restaurant_sync_batch(kind text,batch uuid)
RETURNS void LANGUAGE plpgsql SET search_path='' AS $$
DECLARE current_status text;complete boolean;any_done boolean;
BEGIN
 IF kind='original' THEN SELECT status INTO current_status FROM public.restaurant_kitchen WHERE id=batch;
 ELSE SELECT a.status INTO current_status FROM public.restaurant_addons a WHERE a.id=batch; END IF;
 SELECT coalesce(bool_and(coalesce(v.delivered,p.delivered,CASE WHEN current_status='served' THEN (x->>'qty')::int ELSE 0 END)>=(x->>'qty')::int),true),
 coalesce(bool_or(coalesce(v.delivered,p.delivered,CASE WHEN current_status='served' THEN (x->>'qty')::int ELSE 0 END)>0),false)
 INTO complete,any_done FROM jsonb_array_elements(public.restaurant_variant_lines(kind,batch)) x
 LEFT JOIN public.restaurant_variant_delivery v ON v.source=kind AND v.batch_id=batch AND v.line_id=x->>'id'
 LEFT JOIN public.restaurant_delivery p ON p.source=kind AND p.batch_id=batch AND p.menu_id=x->>'id';
 IF complete THEN current_status:='served';ELSIF any_done THEN current_status:='preparing';END IF;
 IF kind='original' THEN UPDATE public.restaurant_kitchen SET status=current_status WHERE id=batch;
 ELSE UPDATE public.restaurant_addons SET status=current_status WHERE id=batch;END IF;
END; $$;
CREATE OR REPLACE FUNCTION public.restaurant_deliver_item(kind text,batch uuid,item_id text,expected_quantity integer,expected_delivered integer)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE ticket uuid;current_status text;q integer;done integer;
BEGIN
 IF NOT public.restaurant_has_role() THEN RAISE EXCEPTION '需要員工權限' USING ERRCODE='42501'; END IF;
 IF kind='original' THEN ticket:=batch;ELSIF kind='addon' THEN SELECT ticket_id INTO ticket FROM public.restaurant_addons WHERE id=batch;ELSE RAISE EXCEPTION '出餐單類型不正確';END IF;
 IF ticket IS NULL THEN RAISE EXCEPTION '找不到出餐單';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(ticket::text,0));
 IF NOT EXISTS(SELECT 1 FROM public.restaurant_kitchen WHERE id=ticket AND cancelled_at IS NULL) THEN RAISE EXCEPTION '桌單已取消';END IF;
 IF kind='original' THEN SELECT status INTO current_status FROM public.restaurant_kitchen WHERE id=batch;
 ELSE SELECT status INTO current_status FROM public.restaurant_addons WHERE id=batch;END IF;
 SELECT (x->>'qty')::int INTO q FROM jsonb_array_elements(public.restaurant_variant_lines(kind,batch)) x WHERE x->>'id'=item_id;
 SELECT coalesce((SELECT delivered FROM public.restaurant_variant_delivery WHERE source=kind AND batch_id=batch AND line_id=item_id),
 (SELECT delivered FROM public.restaurant_delivery WHERE source=kind AND batch_id=batch AND menu_id=item_id),CASE WHEN current_status='served' THEN q ELSE 0 END) INTO done;
 IF q IS DISTINCT FROM expected_quantity OR done IS DISTINCT FROM expected_delivered OR done>=q THEN RAISE EXCEPTION '餐點或送餐進度已更新，請重新整理' USING ERRCODE='40001';END IF;
 INSERT INTO public.restaurant_variant_delivery VALUES(kind,batch,item_id,done+1) ON CONFLICT(source,batch_id,line_id) DO UPDATE SET delivered=excluded.delivered;
 PERFORM public.restaurant_sync_batch(kind,batch);
END; $$;
-- 修改時以每個批次的每筆需求為單位，不再把不同要求的同品項合成一列。
CREATE OR REPLACE FUNCTION public.restaurant_ticket_amend_lines(ticket_id uuid,request_id uuid,expected jsonb,quantities jsonb,change_reason text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE k public.restaurant_kitchen;before_lines jsonb;kept jsonb:='[]';intended jsonb:='[]';inc_raw jsonb:='[]';
 line jsonb;target integer;key text;b record;batch_lines jsonb;priced jsonb;aggregate_lines jsonb;new_items jsonb;
 raw jsonb;old_status text;done integer;prior public.restaurant_ticket_changes;
 payload jsonb:=jsonb_build_object('expected',expected,'quantities',quantities,'reason',change_reason,'variants',true);
BEGIN
 IF NOT public.restaurant_is_cashier() THEN RAISE EXCEPTION '需要櫃台權限' USING ERRCODE='42501';END IF;
 IF request_id IS NULL OR ticket_id IS NULL THEN RAISE EXCEPTION '缺少異動編號' USING ERRCODE='22023';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(ticket_id::text,0));
 SELECT * INTO prior FROM public.restaurant_ticket_changes c WHERE c.id=request_id;
 IF FOUND THEN IF prior.ticket_id<>ticket_id OR prior.payload IS DISTINCT FROM payload THEN RAISE EXCEPTION '異動編號已使用' USING ERRCODE='22023';END IF;RETURN request_id;END IF;
 SELECT * INTO k FROM public.restaurant_kitchen WHERE id=ticket_id FOR UPDATE;
 IF NOT FOUND OR k.cancelled_at IS NOT NULL OR EXISTS(SELECT 1 FROM public.restaurant_sales WHERE id=ticket_id) THEN RAISE EXCEPTION '桌單已結帳或取消，請重新查詢' USING ERRCODE='22023';END IF;
 before_lines:=public.restaurant_ticket_variant_snapshot(k.id);
 IF expected IS DISTINCT FROM before_lines THEN RAISE EXCEPTION '逐筆餐點已更新，請重新叫回後修改' USING ERRCODE='40001';END IF;
 IF length(btrim(coalesce(change_reason,''))) NOT BETWEEN 1 AND 200 OR jsonb_typeof(quantities) IS DISTINCT FROM 'object'
 OR (SELECT count(*) FROM jsonb_each(quantities))<>jsonb_array_length(before_lines) THEN RAISE EXCEPTION '請填寫原因與每筆份數' USING ERRCODE='22023';END IF;
 FOR line IN SELECT value FROM jsonb_array_elements(before_lines) LOOP
  key:=(line->>'source')||':'||(line->>'batch_id')||':'||(line->>'id');
  IF NOT quantities ? key OR jsonb_typeof(quantities->key)<>'number' OR quantities->>key !~ '^([0-9]|[1-9][0-9])$' THEN RAISE EXCEPTION '每筆份數需為 0 至 99 的整數' USING ERRCODE='22023';END IF;
  target:=(quantities->>key)::int;
  IF target>0 THEN intended:=intended||jsonb_build_array(line||jsonb_build_object('qty',target));END IF;
  IF least(target,(line->>'qty')::int)>0 THEN kept:=kept||jsonb_build_array(line||jsonb_build_object('qty',least(target,(line->>'qty')::int)));END IF;
  IF target>(line->>'qty')::int THEN inc_raw:=inc_raw||jsonb_build_array(jsonb_build_object('line_id',gen_random_uuid(),'menu_id',line->>'menu_id','qty',target-(line->>'qty')::int,'note',line->>'note'));END IF;
 END LOOP;
 IF before_lines<>'[]'::jsonb AND intended=before_lines THEN RAISE EXCEPTION '尚未變更份數' USING ERRCODE='22023';END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(intended) x GROUP BY x->>'menu_id' HAVING sum((x->>'qty')::int)>99) THEN RAISE EXCEPTION '同品項整桌總份數不可超過 99' USING ERRCODE='22023';END IF;
 FOR b IN SELECT k.id AS id,'original'::text AS source,k.status UNION ALL SELECT a.id,'addon',a.status FROM public.restaurant_addons a WHERE a.ticket_id=k.id LOOP
  SELECT coalesce(jsonb_agg(x-'source'-'batch_id'),'[]') INTO batch_lines FROM jsonb_array_elements(kept) x WHERE x->>'source'=b.source AND x->>'batch_id'=b.id::text;
  -- 將舊的完成狀態轉成逐筆進度，減量時保留尚存餐點的已送份數。
  FOR line IN SELECT value FROM jsonb_array_elements(batch_lines) LOOP
   SELECT coalesce((SELECT delivered FROM public.restaurant_variant_delivery WHERE source=b.source AND batch_id=b.id AND line_id=line->>'id'),
    (SELECT delivered FROM public.restaurant_delivery WHERE source=b.source AND batch_id=b.id AND menu_id=line->>'id'),
    CASE WHEN b.status='served' THEN (line->>'qty')::int ELSE 0 END) INTO done;
   INSERT INTO public.restaurant_variant_delivery VALUES(b.source,b.id,line->>'id',least(done,(line->>'qty')::int))
    ON CONFLICT(source,batch_id,line_id) DO UPDATE SET delivered=excluded.delivered;
  END LOOP;
  INSERT INTO public.restaurant_variant_batches VALUES(b.source,b.id,'[]',batch_lines)
   ON CONFLICT(source,batch_id) DO UPDATE SET lines=excluded.lines;
  SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'price',price,'qty',qty) ORDER BY id),'[]') INTO priced FROM
   (SELECT x->>'menu_id' id,max(x->>'name') name,max((x->>'price')::int) price,sum((x->>'qty')::int)::int qty FROM jsonb_array_elements(batch_lines) x GROUP BY x->>'menu_id') v;
  IF b.source='original' THEN UPDATE public.restaurant_kitchen SET initial_lines=priced WHERE id=k.id;
  ELSE UPDATE public.restaurant_addons SET lines=priced WHERE id=b.id;END IF;
  UPDATE public.restaurant_guest_orders SET lines=priced,reason='店員已調整餐點：'||change_reason,
   status=CASE WHEN priced='[]'::jsonb THEN 'rejected' ELSE status END WHERE batch_id=b.id AND status='accepted';
  PERFORM public.restaurant_sync_batch(b.source,b.id);
 END LOOP;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'price',price,'qty',qty) ORDER BY id),'[]'),coalesce(jsonb_object_agg(id,qty),'{}') INTO aggregate_lines,new_items FROM
 (SELECT x->>'menu_id' id,max(x->>'name') name,max((x->>'price')::int) price,sum((x->>'qty')::int)::int qty FROM jsonb_array_elements(kept) x GROUP BY x->>'menu_id') v;
 UPDATE public.restaurant_kitchen SET lines=aggregate_lines,items=new_items WHERE id=k.id;
 IF inc_raw<>'[]'::jsonb THEN PERFORM public.restaurant_add_items_lines(k.id,request_id,inc_raw,'份數調整增加');END IF;
 IF intended='[]'::jsonb THEN
  UPDATE public.restaurant_kitchen SET cancelled_at=now() WHERE id=k.id;
  UPDATE public.restaurant_guest_orders o SET status='rejected',reason='整桌取消：'||change_reason,reviewed_at=now(),reviewed_by=auth.uid()
   WHERE o.status='pending' AND o.session_id IN (SELECT d.id FROM public.restaurant_dining_sessions d WHERE d.ticket_id=k.id);
  UPDATE public.restaurant_dining_sessions d SET closed_at=now() WHERE d.ticket_id=k.id AND d.closed_at IS NULL;
 END IF;
 INSERT INTO public.restaurant_ticket_changes(id,ticket_id,table_label,service,before_lines,after_lines,reason,payload,actor)
 VALUES(request_id,k.id,k.table_label,k.service,before_lines,intended,btrim(change_reason),payload,auth.uid());
 RETURN request_id;
END; $$;
CREATE OR REPLACE FUNCTION public.restaurant_checkout_lines(sale_id uuid,service_mode text,table_name text,payment_mode text,items jsonb,discount integer DEFAULT 0,order_note text DEFAULT '',request_lines jsonb DEFAULT NULL,expected_lines jsonb DEFAULT NULL)
RETURNS public.restaurant_sales LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE normalized jsonb;snapshot jsonb;stored public.restaurant_sale_line_details;result public.restaurant_sales;aggregate_items jsonb;calculated_amount bigint;
BEGIN
 IF NOT public.restaurant_is_cashier() THEN RAISE EXCEPTION '需要櫃台權限' USING ERRCODE='42501';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(sale_id::text,0));
 IF request_lines IS NOT NULL THEN normalized:=public.restaurant_normalize_variants(request_lines);
  IF normalized->'items' IS DISTINCT FROM items THEN RAISE EXCEPTION '逐筆份數與結帳餐點不符' USING ERRCODE='22023';END IF;END IF;
 SELECT * INTO stored FROM public.restaurant_sale_line_details WHERE restaurant_sale_line_details.sale_id=restaurant_checkout_lines.sale_id;
 IF FOUND THEN
  IF normalized IS NOT NULL AND stored.request_lines IS DISTINCT FROM normalized->'raw' THEN RAISE EXCEPTION '此交易的餐點需求與原單不同' USING ERRCODE='22023';END IF;
  RETURN public.restaurant_checkout_note(sale_id,service_mode,table_name,payment_mode,items,discount,order_note);
 END IF;
 IF EXISTS(SELECT 1 FROM public.restaurant_kitchen WHERE id=sale_id) THEN
  snapshot:=public.restaurant_ticket_variant_snapshot(sale_id);
  IF expected_lines IS NOT NULL AND expected_lines IS DISTINCT FROM snapshot THEN RAISE EXCEPTION '逐筆需求已更新，請重新叫回原單核對' USING ERRCODE='40001';END IF;
 ELSIF normalized IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.restaurant_sales WHERE id=sale_id) THEN
  PERFORM public.restaurant_send_kitchen_lines(sale_id,service_mode,table_name,request_lines,order_note);
  snapshot:=public.restaurant_ticket_variant_snapshot(sale_id);
 END IF;
 result:=public.restaurant_checkout_note(sale_id,service_mode,table_name,payment_mode,items,discount,order_note);
 IF snapshot IS NULL THEN
  SELECT coalesce(jsonb_agg(jsonb_build_object('id',i.menu_id,'menu_id',i.menu_id,'name',i.name,'price',i.unit_price,'qty',i.quantity,'note','')),'[]') INTO snapshot FROM public.restaurant_sale_items i WHERE i.sale_id=restaurant_checkout_lines.sale_id;
 END IF;
 SELECT coalesce(jsonb_object_agg(id,qty),'{}'),coalesce(sum(amount),0) INTO aggregate_items,calculated_amount FROM
 (SELECT x->>'menu_id' id,sum((x->>'qty')::int)::int qty,sum((x->>'qty')::int*(x->>'price')::bigint) amount FROM jsonb_array_elements(snapshot) x GROUP BY x->>'menu_id') t;
 IF aggregate_items IS DISTINCT FROM items OR calculated_amount<>result.subtotal THEN RAISE EXCEPTION '逐筆計價與桌單不一致，請核對後重試' USING ERRCODE='22023';END IF;
 INSERT INTO public.restaurant_sale_line_details VALUES(sale_id,snapshot,normalized->'raw');
 RETURN result;
END; $$;
CREATE OR REPLACE FUNCTION public.restaurant_sale_variants(sale_ids uuid[])
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT public.restaurant_is_cashier() THEN RAISE EXCEPTION '需要櫃台權限' USING ERRCODE='42501';END IF;
 IF cardinality(sale_ids)>1000 THEN RAISE EXCEPTION '一次最多查詢 1000 筆交易';END IF;
 RETURN (SELECT coalesce(jsonb_agg(jsonb_build_object('id',s.sale_id,'lines',s.lines)),'[]') FROM public.restaurant_sale_line_details s WHERE s.sale_id=ANY(sale_ids));
END; $$;
-- 防止舊版按整個品項退菜而誤改分開的需求。
DO $$ BEGIN
 IF to_regprocedure('public.restaurant_ticket_amend_legacy(uuid,uuid,jsonb,jsonb,text)') IS NULL THEN
  ALTER FUNCTION public.restaurant_ticket_amend(uuid,uuid,jsonb,jsonb,text) RENAME TO restaurant_ticket_amend_legacy;
 END IF;
END; $$;
REVOKE ALL ON FUNCTION public.restaurant_ticket_amend_legacy(uuid,uuid,jsonb,jsonb,text) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.restaurant_ticket_amend(ticket_id uuid,request_id uuid,expected jsonb,quantities jsonb,change_reason text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT public.restaurant_is_cashier() THEN RAISE EXCEPTION '需要櫃台權限' USING ERRCODE='42501';END IF;
 IF EXISTS(SELECT 1 FROM public.restaurant_variant_batches v WHERE (v.source='original' AND v.batch_id=ticket_id) OR (v.source='addon' AND v.batch_id IN (SELECT a.id FROM public.restaurant_addons a WHERE a.ticket_id=restaurant_ticket_amend.ticket_id))) THEN
  RAISE EXCEPTION '本桌已採逐筆需求，請更新網頁後再修改' USING ERRCODE='22023';END IF;
 RETURN public.restaurant_ticket_amend_legacy(ticket_id,request_id,expected,quantities,change_reason);
END; $$;
REVOKE ALL ON FUNCTION public.restaurant_normalize_variants(jsonb),public.restaurant_snapshot_variants(jsonb,jsonb),public.restaurant_variant_lines(text,uuid),public.restaurant_ticket_variant_snapshot(uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.restaurant_send_kitchen_lines(uuid,text,text,jsonb,text),public.restaurant_add_items_lines(uuid,uuid,jsonb,text),public.restaurant_guest_review_lines(uuid,boolean),
 public.restaurant_guest_pending_lines(),public.restaurant_open_tables_lines(),public.restaurant_kitchen_variant_batches(),public.restaurant_ticket_amend_lines(uuid,uuid,jsonb,jsonb,text),
 public.restaurant_checkout_lines(uuid,text,text,text,jsonb,integer,text,jsonb,jsonb),public.restaurant_sale_variants(uuid[]) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.restaurant_send_kitchen_lines(uuid,text,text,jsonb,text),public.restaurant_add_items_lines(uuid,uuid,jsonb,text),public.restaurant_guest_review_lines(uuid,boolean),
 public.restaurant_guest_pending_lines(),public.restaurant_open_tables_lines(),public.restaurant_kitchen_variant_batches(),public.restaurant_ticket_amend_lines(uuid,uuid,jsonb,jsonb,text),
 public.restaurant_checkout_lines(uuid,text,text,text,jsonb,integer,text,jsonb,jsonb),public.restaurant_sale_variants(uuid[]) TO authenticated;
REVOKE ALL ON FUNCTION public.restaurant_guest_submit_lines(uuid,uuid,jsonb,text,uuid),public.restaurant_guest_view_lines(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.restaurant_guest_submit_lines(uuid,uuid,jsonb,text,uuid),public.restaurant_guest_view_lines(uuid,uuid) TO anon,authenticated;

CREATE OR REPLACE FUNCTION public.restaurant_batch_status(batch_id uuid,batch_source text,old_status text,new_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE ticket uuid;lines jsonb;current_status text;
BEGIN
 IF NOT public.restaurant_has_role() THEN RAISE EXCEPTION '需要員工權限' USING ERRCODE='42501'; END IF;
 IF NOT ((old_status='queued' AND new_status='preparing') OR (old_status='preparing' AND new_status='served')) THEN RAISE EXCEPTION '出餐狀態無效'; END IF;
 IF batch_source='original' THEN ticket:=batch_id;ELSIF batch_source='addon' THEN SELECT ticket_id INTO ticket FROM public.restaurant_addons WHERE id=batch_id;ELSE RAISE EXCEPTION '出餐單類型無效'; END IF;
 IF ticket IS NULL THEN RAISE EXCEPTION '找不到出餐單'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(ticket::text,0));
 IF NOT EXISTS(SELECT 1 FROM public.restaurant_kitchen WHERE id=ticket AND cancelled_at IS NULL) THEN RAISE EXCEPTION '桌單已取消'; END IF;
 IF batch_source='original' THEN SELECT initial_lines,status INTO lines,current_status FROM public.restaurant_kitchen WHERE id=batch_id FOR UPDATE;
 ELSE SELECT a.lines,a.status INTO lines,current_status FROM public.restaurant_addons a WHERE id=batch_id FOR UPDATE; END IF;
 IF current_status IS DISTINCT FROM old_status THEN RAISE EXCEPTION '出餐狀態已更新，請重新整理' USING ERRCODE='40001'; END IF;
 IF new_status='served' THEN
 INSERT INTO public.restaurant_variant_delivery(source,batch_id,line_id,delivered)
 SELECT batch_source,batch_id,x->>'id',(x->>'qty')::int FROM jsonb_array_elements(public.restaurant_variant_lines(batch_source,batch_id)) x
 ON CONFLICT ON CONSTRAINT restaurant_variant_delivery_pkey DO UPDATE SET delivered=excluded.delivered;
 END IF;
 IF batch_source='original' THEN UPDATE public.restaurant_kitchen SET status=new_status WHERE id=batch_id;
 ELSE UPDATE public.restaurant_addons SET status=new_status WHERE id=batch_id; END IF;
END; $$;

INSERT INTO public.restaurant_menu(id,name,category,price) VALUES
 ('green-salad', '綜合生菜沙拉', '前菜', 280),
 ('salmon-salad', '煙燻鮭魚生菜捲', '前菜', 320),
 ('fish-chips', '炸魚柳與楔型薯條', '前菜', 220),
 ('fried-chicken', '無骨鹹酥雞', '前菜', 220),
 ('sauteed-vegetables', '橄欖油清炒野菇甜椒櫛瓜', '前菜', 280),
 ('garlic-mushrooms', '蒜香香草清炒雙菇', '前菜', 280),
 ('tomato-mozzarella', '蕃茄起司盤', '前菜', 320),
 ('ham-melon', '蜜瓜火腿', '前菜', 320),
 ('roast-chicken', '煙燻紅椒香料爐烤半雞', '主菜', 420),
 ('pork-knuckle', '德國豬腳', '主菜', 480),
 ('sea-bass', '鼠尾草奶油慢煎鱸魚', '主菜', 480),
 ('john-dory', '酥炸多利魚排與季節時蔬', '主菜', 420),
 ('blade-steak', '舒肥美國 Choice 翼板牛排 4 oz', '主菜', 580),
 ('short-rib', 'U.S. 帶骨牛小排', '主菜', 580),
 ('duck-breast', '慢煎舒肥櫻桃鴨胸', '主菜', 580),
 ('fish-papillote', '紙包魚', '主菜', 680),
 ('aglio-olio', '橄欖油香蒜細扁麵（無肉）', '麵食', 220),
 ('salmon-conchiglioni', '煙燻鮭魚淡奶油大貝殼麵', '麵食', 320),
 ('nero-spaghetti', '蒜香白酒墨魚墨汁直圓麵', '麵食', 320),
 ('urchin-conchiglioni', '和風海膽魚卵醬大貝殼麵', '麵食', 320),
 ('truffle-pappardelle', '黑松露醬雙菇淡奶油寬帶麵', '麵食', 320),
 ('clam-linguine', '香蒜白酒蛤蜊細扁麵', '麵食', 320),
 ('bacon-spaghetti', '清炒厚切原肉煙燻培根直圓麵', '麵食', 300),
 ('carbonara', '蛋奶醬厚切原肉煙燻培根直圓麵', '麵食', 320),
 ('seafood-spaghetti', '海鮮直圓麵', '麵食', 350),
 ('balsamic-spaghetti', '香蒜洋蔥香菇巴薩米可醋直圓麵（無肉）', '麵食', 280),
 ('pork-spaghetti', '塔塔義式炸豬排直圓麵', '麵食', 380),
 ('blade-linguine', '薄片舒肥美國 CH 翼板牛 4 oz 香蒜牛油細扁麵', '麵食', 480),
 ('beef-cheek-pappardelle', '波爾多紅酒慢燉牛頰寬帶麵', '麵食', 420),
 ('bolognese-conchiglioni', '義式肉醬大貝殼麵', '麵食', 320),
 ('truffle-risotto', '黑松露醬淡奶油雙菇燉飯（無肉）', '燉飯', 320),
 ('seafood-risotto', '海鮮燉飯', '燉飯', 350),
 ('squid-risotto', '蒜香墨魚墨汁燉飯', '燉飯', 320),
 ('pork-risotto', '塔塔義式炸豬排燉飯', '燉飯', 380),
 ('vegetable-risotto', '白酒時蔬燉飯（無肉）', '燉飯', 350),
 ('lasagne', '起司焗烤牛肉醬千層麵', '小樂義推薦', 320),
 ('ravioli', '松露帕馬森起司餃', '小樂義推薦', 350),
 ('sage-gnocchi', '鼠尾草奶油乾煎義式麵疙瘩', '小樂義推薦', 360),
 ('cheese-gnocchi', '起司醬義式麵疙瘩', '小樂義推薦', 380),
 ('pesto-gnocchi', '青醬義式麵疙瘩', '小樂義推薦', 380),
 ('basque-slice', '鹽之花焦糖巴斯克乳酪蛋糕（片）', '甜點', 150),
 ('tiramisu', '提拉米蘇', '甜點', 150),
 ('basque-4in', '四吋巴斯克乳酪蛋糕', '甜點', 480),
 ('americano', '美式咖啡', '咖啡', 100),
 ('latte', '拿鐵', '咖啡', 120),
 ('flavored-latte', '風味拿鐵', '咖啡', 130),
 ('macchiato', '焦糖瑪奇朵', '咖啡', 140),
 ('earl-grey', '英式伯爵茶／奶茶', '茶', 150),
 ('osmanthus', '桂花香草茶', '茶', 150),
 ('rose-tea', '天然玫瑰香草茶', '茶', 150),
 ('lavender-tea', '薰衣草香草茶', '茶', 150),
 ('americano-soda', '美式咖啡氣泡飲', '氣泡飲', 150),
 ('grapefruit-soda', '蜂蜜柚香氣泡飲', '氣泡飲', 150),
 ('peach-soda', '白桃茉莉氣泡飲', '氣泡飲', 150),
 ('grape-soda', '香檳葡萄氣泡飲', '氣泡飲', 150),
 ('heineken', '海尼根', '啤酒', 120),
 ('anchovy-dip', '鯷魚沾醬（限內用）', '內用加點', 30),
 ('soup', '今日湯（限內用）', '內用加點', 50),
 ('add-drink', '飲料任選（限內用）', '內用加點', 70),
 ('add-dessert', '今日甜點（限內用）', '內用加點', 60);

COMMIT;
