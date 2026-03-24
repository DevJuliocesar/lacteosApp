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
    if (!authHeader) return json({ error: 'No autorizado' }, 401)

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const jwt = authHeader.replace('Bearer ', '')
    const { data: { user: caller }, error: authError } = await supabaseAdmin.auth.getUser(jwt)
    if (authError || !caller) return json({ error: 'No autorizado' }, 401)
    if (caller.user_metadata?.role !== 'admin') return json({ error: 'Acceso denegado' }, 403)

    const { id, name } = await req.json()
    if (!id) return json({ error: 'El id es requerido' }, 400)
    if (!name) return json({ error: 'El nombre es requerido' }, 400)

    const { error } = await supabaseAdmin.auth.admin.updateUserById(id, {
      user_metadata: { name },
    })

    if (error) return json({ error: error.message }, 400)

    return json({ success: true })
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
