import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed." }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const publishableKeys = Deno.env.get("SUPABASE_PUBLISHABLE_KEYS");
  const secretKeys = Deno.env.get("SUPABASE_SECRET_KEYS");
  const anonKey = publishableKeys ? JSON.parse(publishableKeys).default : Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = secretKeys ? JSON.parse(secretKeys).default : Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return json({ error: "Sunucu yapılandırması eksik." }, 500);
  }

  const authorization = req.headers.get("Authorization");
  const token = authorization?.replace(/^Bearer\s+/i, "");
  if (!token) return json({ error: "Oturum doğrulanamadı. Yeniden giriş yap." }, 401);

  const authClient = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: authData, error: authError } = await authClient.auth.getUser(token);
  if (authError || !authData.user) return json({ error: "Oturum geçersiz veya süresi dolmuş." }, 401);

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  let payload: { full_name?: unknown; email?: unknown; password?: unknown };
  try {
    payload = await req.json();
  } catch {
    return json({ error: "Gönderilen bilgiler okunamadı." }, 400);
  }

  const fullName = typeof payload.full_name === "string" ? payload.full_name.trim() : "";
  const email = typeof payload.email === "string" ? payload.email.trim().toLowerCase() : "";
  const password = typeof payload.password === "string" ? payload.password : "";
  if (fullName.length < 2 || fullName.length > 100) return json({ error: "Ad soyad 2-100 karakter olmalı." }, 400);
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254) return json({ error: "Geçerli bir e-posta adresi gir." }, 400);
  if (password.length < 8 || password.length > 72) return json({ error: "Şifre 8-72 karakter arasında olmalı." }, 400);

  const { data: caller, error: profileError } = await admin
    .from("profiles")
    .select("business_id, role, active")
    .eq("id", authData.user.id)
    .maybeSingle();

  if (profileError) return json({ error: "Yönetici profili doğrulanamadı." }, 500);
  if (!caller || caller.role !== "owner" || caller.active !== true) {
    return json({ error: "Bu işlemi yalnızca aktif işletme sahibi yapabilir." }, 403);
  }

  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { full_name: fullName },
  });
  if (createError || !created.user) {
    return json({ error: createError?.message || "Auth hesabı oluşturulamadı." }, 400);
  }

  const { error: insertError } = await admin.from("profiles").insert({
    id: created.user.id,
    business_id: caller.business_id,
    full_name: fullName,
    role: "staff",
    active: true,
  });

  if (insertError) {
    await admin.auth.admin.deleteUser(created.user.id);
    return json({ error: "Çalışan profili kaydedilemedi. Oluşturulan giriş hesabı geri alındı." }, 500);
  }

  return json({ success: true, employee: { id: created.user.id, full_name: fullName, role: "staff" } }, 201);
});
