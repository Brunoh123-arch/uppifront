import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.48.1";

export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
};

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') || '';
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || Deno.env.get('SUPABASE_ANON_KEY') || '';
    const supabase = createClient(supabaseUrl, supabaseKey);

    const body = await req.json().catch(() => ({}));
    const { action = 'request_code', phone, code, full_name = 'Passageiro Uppi' } = body;

    if (!phone) {
      return new Response(JSON.stringify({ error: 'Telefone é obrigatório' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // 1. Pedir código de SMS (Etapa 1 do Login)
    if (action === 'request_code' || action === 'phone_submit') {
      console.log(`[AUTH] Solicitado código de login para o telefone: ${phone}`);
      return new Response(JSON.stringify({
        status: 'ok',
        action: 'enter_code',
        phone: phone,
        code_length: 4,
        test_code: '1234',
        message: 'Código enviado com sucesso. Para ambiente de desenvolvimento/teste, utilize o código: 1234'
      }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // 2. Validar código de SMS e entrar (Etapa 2 do Login)
    if (action === 'verify_code' || action === 'code_submit') {
      const validCode = '1234';
      if (code !== validCode && code !== '123456') {
        return new Response(JSON.stringify({
          status: 'error',
          error: 'Código incorreto. Digite 1234 para acessar o Uppi.'
        }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      // Verificar se perfil já existe ou criar novo
      let { data: profile } = await supabase
        .from('profiles')
        .select('*')
        .eq('phone', phone)
        .single();

      if (!profile) {
        const { data: newProfile, error: createErr } = await supabase
          .from('profiles')
          .insert({
            phone: phone,
            full_name: full_name,
            role: 'rider',
            rating: 5.00
          })
          .select('*')
          .single();

        if (createErr) {
          throw createErr;
        }
        profile = newProfile;
      }

      // Gerar token simulado de sessão
      const sessionToken = `uppi_session_${profile.id}_${Date.now()}`;

      return new Response(JSON.stringify({
        status: 'ok',
        authenticated: true,
        session_token: sessionToken,
        user: {
          id: profile.id,
          phone: profile.phone,
          full_name: profile.full_name,
          role: profile.role,
          rating: profile.rating
        },
        message: 'Login realizado com sucesso!'
      }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    return new Response(JSON.stringify({ error: 'Ação de autenticação inválida' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });

  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});
