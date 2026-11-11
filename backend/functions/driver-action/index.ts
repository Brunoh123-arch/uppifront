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
    const { action, ride_id, driver_id, lat, lon, bearing = 0, speed = 0, final_fare } = body;

    if (!driver_id) {
      return new Response(JSON.stringify({ error: 'driver_id é obrigatório' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // 1. Atualizar localização do motorista em tempo real
    if (action === 'update_location') {
      if (lat === undefined || lon === undefined) {
        return new Response(JSON.stringify({ error: 'lat e lon são obrigatórios para update_location' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      await supabase.from('driver_locations').upsert({
        driver_id: driver_id,
        location: `POINT(${lon} ${lat})`,
        bearing: bearing,
        speed: speed,
        is_online: true,
        is_available: true,
        updated_at: new Date().toISOString()
      });

      return new Response(JSON.stringify({ status: 'ok', message: 'Localização atualizada com sucesso' }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Ações que exigem ride_id
    if (!ride_id) {
      return new Response(JSON.stringify({ error: 'ride_id é obrigatório para esta ação' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // 2. Aceitar corrida
    if (action === 'accept_ride') {
      const { data: ride, error: fetchErr } = await supabase
        .from('rides')
        .select('*')
        .eq('id', ride_id)
        .single();

      if (fetchErr || !ride) {
        return new Response(JSON.stringify({ error: 'Corrida não encontrada' }), {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      if (ride.status !== 'searching') {
        return new Response(JSON.stringify({ error: 'Corrida indisponível ou já aceita por outro motorista' }), {
          status: 409,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      const { data: updatedRide, error: updateErr } = await supabase
        .from('rides')
        .update({
          driver_id: driver_id,
          status: 'assigned',
          updated_at: new Date().toISOString()
        })
        .eq('id', ride_id)
        .select('*')
        .single();

      if (updateErr) {
        return new Response(JSON.stringify({ error: updateErr.message }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      // Deixar motorista ocupado
      await supabase.from('driver_locations')
        .update({ is_available: false })
        .eq('driver_id', driver_id);

      return new Response(JSON.stringify({
        status: 'ok',
        ride: updatedRide,
        message: 'Corrida aceita com sucesso! Dirija-se até o passageiro.'
      }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // 3. Motorista chegou no local de embarque
    if (action === 'arrived') {
      const { data: updatedRide, error: updateErr } = await supabase
        .from('rides')
        .update({ status: 'arrived', updated_at: new Date().toISOString() })
        .eq('id', ride_id)
        .eq('driver_id', driver_id)
        .select('*')
        .single();

      if (updateErr) {
        return new Response(JSON.stringify({ error: updateErr.message }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      return new Response(JSON.stringify({
        status: 'ok',
        ride: updatedRide,
        message: 'Chegada confirmada. Passageiro notificado.'
      }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // 4. Iniciar corrida
    if (action === 'start_trip') {
      const { data: updatedRide, error: updateErr } = await supabase
        .from('rides')
        .update({ status: 'in_progress', updated_at: new Date().toISOString() })
        .eq('id', ride_id)
        .eq('driver_id', driver_id)
        .select('*')
        .single();

      if (updateErr) {
        return new Response(JSON.stringify({ error: updateErr.message }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      return new Response(JSON.stringify({
        status: 'ok',
        ride: updatedRide,
        message: 'Viagem iniciada com sucesso.'
      }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // 5. Finalizar corrida e creditar carteira do motorista
    if (action === 'complete_trip') {
      const { data: ride } = await supabase
        .from('rides')
        .select('*')
        .eq('id', ride_id)
        .eq('driver_id', driver_id)
        .single();

      if (!ride) {
        return new Response(JSON.stringify({ error: 'Corrida não encontrada' }), {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      const totalValue = final_fare ? Number(final_fare) : Number(ride.estimated_fare);
      // Taxa Uppi da plataforma: 15% (repasse ao motorista: 85%)
      const driverEarnings = Math.round(totalValue * 0.85 * 100) / 100;

      // Finalizar a corrida
      const { data: completedRide, error: updateErr } = await supabase
        .from('rides')
        .update({
          status: 'completed',
          final_fare: totalValue,
          updated_at: new Date().toISOString()
        })
        .eq('id', ride_id)
        .select('*')
        .single();

      if (updateErr) {
        return new Response(JSON.stringify({ error: updateErr.message }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      // Creditar carteira do motorista
      const { data: driverProfile } = await supabase
        .from('profiles')
        .select('wallet_balance')
        .eq('id', driver_id)
        .single();

      const newBalance = (Number(driverProfile?.wallet_balance) || 0) + driverEarnings;

      await supabase
        .from('profiles')
        .update({ wallet_balance: newBalance })
        .eq('id', driver_id);

      // Liberar motorista para novas corridas
      await supabase.from('driver_locations')
        .update({ is_available: true })
        .eq('driver_id', driver_id);

      return new Response(JSON.stringify({
        status: 'ok',
        ride: completedRide,
        total_fare: totalValue,
        driver_earnings: driverEarnings,
        platform_fee: Math.round((totalValue - driverEarnings) * 100) / 100,
        driver_new_wallet_balance: newBalance,
        message: `Corrida finalizada! R$ ${driverEarnings.toFixed(2)} creditados na carteira do motorista.`
      }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    return new Response(JSON.stringify({ error: 'Ação do motorista não reconhecida' }), {
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
