import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return json({ error: 'No autorizado' }, 401)
    }

    // Verificar que el caller está autenticado y es admin
    // Se usa el cliente admin para validar el JWT de forma confiable
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const jwt = authHeader.replace('Bearer ', '')
    const { data: { user: caller }, error: authError } = await supabaseAdmin.auth.getUser(jwt)
    if (authError || !caller) return json({ error: 'No autorizado' }, 401)

    if (caller.user_metadata?.role !== 'admin') {
      return json({ error: 'Acceso denegado: solo administradores pueden invitar usuarios' }, 403)
    }

    // Parsear body
    const { email, name } = await req.json()
    if (!email) return json({ error: 'El email es requerido' }, 400)

    const { data, error } = await supabaseAdmin.auth.admin.inviteUserByEmail(email, {
      data: { role: 'operario', name: name ?? '', email_verified: true },
      redirectTo: 'lacteosapp://auth-callback',
    })

    if (error) return json({ error: error.message }, 400)

    return json({ userId: data.user.id, email: data.user.email })
  } catch (err) {
    return json({ error: (err as Error).message }, 500)
  }
})

function json(body: object, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}
