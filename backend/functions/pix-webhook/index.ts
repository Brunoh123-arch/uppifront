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
    const { ride_id, order_number, status = 'PAID', amount, txid } = body;

    console.log(`[PIX WEBHOOK] Notificação de pagamento recebida:`, JSON.stringify(body));

    if (!ride_id && !order_number) {
      return new Response(JSON.stringify({ error: 'ride_id ou order_number é obrigatório' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    let query = supabase.from('rides').select('*');
    if (ride_id) {
      query = query.eq('id', ride_id);
    } else {
      query = query.eq('order_number', order_number);
    }

    const { data: ride, error: fetchErr } = await query.single();

    if (fetchErr || !ride) {
      return new Response(JSON.stringify({ error: 'Corrida não encontrada para liquidação' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Atualizar status para pago
    const isPaid = status === 'PAID' || status === 'CONFIRMED' || status === 'approved';
    const newPaymentStatus = isPaid ? 'paid' : 'failed';

    const { data: updatedRide } = await supabase
      .from('rides')
      .update({
        payment_status: newPaymentStatus,
        updated_at: new Date().toISOString()
      })
      .eq('id', ride.id)
      .select('*')
      .single();

    return new Response(JSON.stringify({
      status: 'ok',
      payment_confirmed: isPaid,
      ride_id: ride.id,
      order_number: ride.order_number,
      payment_status: newPaymentStatus,
      message: isPaid 
        ? 'Pagamento Pix liquidado com sucesso. Corrida liberada!' 
        : 'Status de pagamento atualizado.'
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
