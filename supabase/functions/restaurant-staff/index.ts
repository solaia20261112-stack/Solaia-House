import { createClient } from 'npm:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const reply = (data: unknown, status = 200) => Response.json(data, {status,headers:cors});
const passwordOK = (s: string) => s.length >= 12 && new TextEncoder().encode(s).length <= 72;
const emailOK = (s: string) => s.length <= 254 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s);

export async function handle(request: Request) {
  if(request.method==='OPTIONS') return new Response(null,{headers:cors});
  if(request.method!=='POST') return reply({message:'不支援此請求'},405);
  try {
    const token=request.headers.get('Authorization')?.match(/^Bearer (.+)$/i)?.[1];
    if(!token) return reply({message:'請先登入'},401);
    const client=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      {auth:{persistSession:false,autoRefreshToken:false}});
    const {data:{user},error:authError}=await client.auth.getUser(token);
    if(authError || !user) return reply({message:'登入已失效'},401);
    const {data:owner,error:roleError}=await client.from('restaurant_staff').select('role').eq('user_id',user.id).maybeSingle();
    if(roleError || owner?.role!=='owner') return reply({message:'需要管理者權限'},403);
    const body=await request.json();
    const action=body.action??'save';
    if(action==='list') {
      const {data:members,error}=await client.from('restaurant_staff').select('user_id,role');
      if(error) throw error;
      const roles=new Map((members??[]).map(m=>[m.user_id,m.role]));
      const users=[];
      for(let page=1;page<=100;page++) {
        const {data,error}=await client.auth.admin.listUsers({page,perPage:1000});
        if(error) throw error;
        for(const account of data.users) users.push({id:account.id,email:account.email??'',
          name:String(account.user_metadata?.display_name??''),role:roles.get(account.id)??null,
          created_at:account.created_at,self:account.id===user.id});
        if(data.users.length<1000) return reply({version:8,users});
      }
      return reply({message:'帳號數量超出清單上限，請聯絡管理者處理'},400);
    }
    if(!['save','delete'].includes(action)) return reply({message:'操作不正確'},400);
    let id=String(body.id??'');
    const email=String(body.email??'').trim().toLowerCase();
    const password=String(body.password??'');
    const name=String(body.name??'').trim();
    const role=body.role;
    if(action==='save' && (!emailOK(email)||!['staff','kitchen'].includes(role)||name.length>60 || (password && !passwordOK(password))))
      return reply({message:'請確認 Email、權限及姓名；密碼需至少 12 個字元，最多 72 位元組'},400);
    if(!id && action==='save') {
      const lookup=await client.rpc('restaurant_find_auth_user',{target_email:email});
      if(lookup.error) throw lookup.error;
      id=lookup.data??'';
    }
    if(id) {
      if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id))
        return reply({message:'帳號編號不正確'},400);
      const member=await client.from('restaurant_staff').select('role').eq('user_id',id).maybeSingle();
      if(member.error) throw member.error;
      if(id===user.id || member.data?.role==='owner') return reply({message:'管理者帳號不可在員工清單修改或刪除；請使用修改自己密碼'},403);
      if(action==='delete') {
        // 先禁止登入，再移除資格。即使 Auth 刪除受歷史外鍵或圖片限制，也不恢復存取權。
        const banned=await client.auth.admin.updateUserById(id,{ban_duration:'876000h'});
        if(banned.error) throw banned.error;
        const removed=await client.from('restaurant_staff').delete().eq('user_id',id);
        if(removed.error) return reply({message:'帳號已禁止登入，但移除員工資格失敗，請重試刪除'},400);
        const deleted=await client.auth.admin.deleteUser(id);
        if(deleted.error) return reply({ok:true,warning:'已停用並移除員工權限；帳號因歷史資料或圖片關聯尚未完全刪除，可重新整理後再刪除。營收與訂位均保留。'});
        return reply({ok:true});
      }
      const changed=await client.auth.admin.updateUserById(id,{email,email_confirm:true,
        user_metadata:{display_name:name},...(password?{password}:{}),ban_duration:'none'});
      if(changed.error) throw changed.error;
    } else {
      if(action==='delete') return reply({message:'請選擇員工'},400);
      if(!passwordOK(password)) return reply({message:'新增帳號請設定至少 12 個字元、最多 72 位元組的密碼'},400);
      const created=await client.auth.admin.createUser({email,password,email_confirm:true,user_metadata:{display_name:name}});
      if(created.error || !created.data.user) throw created.error??Error('新增帳號失敗');
      id=created.data.user.id;
    }
    const saved=await client.rpc('restaurant_set_staff_role',{target_id:id,target_role:role});
    if(saved.error) return reply({message:'帳號資料已儲存，但員工權限儲存失敗，請重新整理後再儲存：'+saved.error.message},400);
    return reply({ok:true,id});
  } catch(error) {
    return reply({message:error instanceof Error ? error.message : '員工設定失敗，請稍後重試'},400);
  }
}
Deno.serve(handle);
