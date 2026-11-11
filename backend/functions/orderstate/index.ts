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
    const { order_id, order_number } = body;

    if (!order_id && !order_number) {
      return new Response(JSON.stringify({ error: 'order_id ou order_number é obrigatório' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    let query = supabase.from('rides').select('*');
    if (order_id) {
      query = query.eq('id', order_id);
    } else {
      query = query.eq('order_number', order_number);
    }

    const { data: ride, error: rideErr } = await query.single();

    if (rideErr || !ride) {
      return new Response(JSON.stringify({ error: 'Corrida não encontrada' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    let driverData = null;
    let vehicleData = null;
    let telemetryData = null;

    if (ride.driver_id) {
      const { data: driver } = await supabase
        .from('profiles')
        .select('id, full_name, phone, avatar_url, rating')
        .eq('id', ride.driver_id)
        .single();
      driverData = driver;

      const { data: vehicle } = await supabase
        .from('vehicles')
        .select('model, brand, color, license_plate')
        .eq('driver_id', ride.driver_id)
        .eq('is_active', true)
        .single();
      vehicleData = vehicle;

      const { data: loc } = await supabase
        .from('driver_locations')
        .select('bearing, speed, updated_at')
        .eq('driver_id', ride.driver_id)
        .single();
      telemetryData = loc;
    }

    return new Response(JSON.stringify({
      status: 'ok',
      ride_id: ride.id,
      order_number: ride.order_number,
      ride_status: ride.status,
      payment_method: ride.payment_method,
      payment_status: ride.payment_status,
      estimated_fare: ride.estimated_fare,
      final_fare: ride.final_fare,
      driver: driverData,
      vehicle: vehicleData,
      telemetry: telemetryData,
      pix: ride.pix_copy_paste ? {
        pix_copy_paste: ride.pix_copy_paste,
        qr_code_url: ride.pix_qr_url
      } : null
    }), {
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
