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
    const {
      origin,
      destination,
      category = 'pop',
      payment_method = 'pix',
      estimated_fare = 15.0,
      distance_meters = 5000,
      duration_seconds = 600,
      rider_id
    } = body;

    if (!origin || !destination) {
      return new Response(JSON.stringify({ error: 'Origem e destino são obrigatórios' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    const orderNumber = `UPPI-${Date.now().toString(36).toUpperCase()}-${Math.floor(1000 + Math.random() * 9000)}`;

    let pixCopyPaste = null;
    let pixQrUrl = null;

    if (payment_method === 'pix') {
      const pixKey = 'uppi-pagamentos@uppi.com.br';
      const pixAmountStr = Number(estimated_fare).toFixed(2);
      pixCopyPaste = `00020126580014br.gov.bcb.pix0136${pixKey}52040000530398654${pixAmountStr.length < 10 ? '0' + pixAmountStr.length : pixAmountStr.length}${pixAmountStr}5802BR5910UPPI BRASIL6009SAO PAULO62070503***6304ABCD`;
      pixQrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${encodeURIComponent(pixCopyPaste)}`;
    }

    // Criar a corrida no banco
    const { data: ride, error: rideErr } = await supabase
      .from('rides')
      .insert({
        order_number: orderNumber,
        rider_id: rider_id || null,
        origin_lat: origin.lat,
        origin_lon: origin.lon,
        origin_address: origin.address || 'Origem selecionada',
        dest_lat: destination.lat,
        dest_lon: destination.lon,
        dest_address: destination.address || 'Destino selecionado',
        category: category,
        distance_meters: Math.round(distance_meters),
        duration_seconds: Math.round(duration_seconds),
        estimated_fare: estimated_fare,
        status: 'searching',
        payment_method: payment_method,
        payment_status: 'pending',
        pix_copy_paste: pixCopyPaste,
        pix_qr_url: pixQrUrl
      })
      .select('*')
      .single();

    if (rideErr || !ride) {
      throw new Error(rideErr?.message || 'Falha ao criar corrida');
    }

    // Buscar motoristas próximos
    const { data: drivers } = await supabase.rpc('find_nearby_drivers', {
      p_lat: origin.lat,
      p_lon: origin.lon,
      p_radius_meters: 6000,
      p_category: category
    });

    const nearbyCount = drivers ? drivers.length : 0;

    const responsePayload: any = {
      status: 'ok',
      order_id: ride.id,
      order_number: ride.order_number,
      ride_status: 'searching',
      payment_method: payment_method,
      estimated_fare: estimated_fare,
      nearby_drivers_found: nearbyCount,
      message: nearbyCount > 0 
        ? `${nearbyCount} motoristas próximos notificados.` 
        : 'Procurando motoristas disponíveis na região...'
    };

    if (pixCopyPaste) {
      responsePayload.pix = {
        amount: estimated_fare,
        currency: 'BRL',
        pix_copy_paste: pixCopyPaste,
        qr_code_url: pixQrUrl,
        expires_in_minutes: 15
      };
    }

    return new Response(JSON.stringify(responsePayload), {
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
