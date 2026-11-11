import "jsr:@supabase/functions-js/edge-runtime.d.ts";

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
    const body = await req.json().catch(() => ({}));
    const { lat, lon, locale = 'pt-BR' } = body;

    // Resposta de handshake e inicialização do app Uppi para o Brasil
    const startupConfig = {
      status: 'ok',
      app_name: 'Uppi',
      version: '1.0.0',
      region_supported: true,
      country: 'BR',
      country_code: 'BRA',
      phone_prefix: '+55',
      currency: {
        code: 'BRL',
        symbol: 'R$',
        format: 'R$ %s',
        rate: 1.0
      },
      emergency_numbers: {
        police: '190',
        ambulance: '192',
        fire: '193'
      },
      support: {
        phone: '+55 11 4002-8922',
        email: 'suporte@uppi.com.br',
        help_center_url: 'https://suporte.uppi.com.br'
      },
      pix_config: {
        enabled: true,
        receiver_name: 'UPPI BRASIL TECNOLOGIA LTDA',
        city: 'SAO PAULO'
      },
      user_location: {
        lat: lat || -23.550520,
        lon: lon || -46.633308,
        city: 'São Paulo',
        state: 'SP',
        country: 'Brasil'
      },
      available_categories: [
        {
          id: 'pop',
          name: 'Uppi Pop',
          description: 'Corridas econômicas no dia a dia',
          icon: 'car_pop'
        },
        {
          id: 'comfort',
          name: 'Uppi Comfort',
          description: 'Carros mais espaçosos e ar-condicionado',
          icon: 'car_comfort'
        },
        {
          id: 'moto',
          name: 'Uppi Moto',
          description: 'Chegue mais rápido evitando o trânsito',
          icon: 'motorcycle'
        },
        {
          id: 'delivery',
          name: 'Uppi Entrega',
          description: 'Envio rápido de encomendas e pacotes',
          icon: 'delivery_box'
        }
      ],
      payment_methods: ['pix', 'card', 'cash'],
      features: {
        chat_enabled: true,
        voip_calls_enabled: true,
        tips_enabled: true,
        live_tracking_enabled: true,
        sos_enabled: true
      }
    };

    return new Response(JSON.stringify(startupConfig), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});
