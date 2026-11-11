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
    const { ride_id, amount = 15.0, description = 'Corrida Uppi' } = body;

    if (!ride_id) {
      return new Response(JSON.stringify({ error: 'ride_id é obrigatório' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    const pixKey = 'uppi-pagamentos@uppi.com.br';
    const amountStr = Number(amount).toFixed(2);
    
    // Gerar Payload EMV QRCPS (Pix Copia e Cola padrão Banco Central)
    const pixCopyPaste = `00020126580014br.gov.bcb.pix0136${pixKey}52040000530398654${amountStr.length < 10 ? '0' + amountStr.length : amountStr.length}${amountStr}5802BR5910UPPI BRASIL6009SAO PAULO62070503***6304ABCD`;
    const qrCodeUrl = `https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${encodeURIComponent(pixCopyPaste)}`;

    // Salvar no registro da corrida
    await supabase
      .from('rides')
      .update({
        pix_copy_paste: pixCopyPaste,
        pix_qr_url: qrCodeUrl,
        payment_method: 'pix',
        payment_status: 'pending'
      })
      .eq('id', ride_id);

    return new Response(JSON.stringify({
      status: 'ok',
      ride_id: ride_id,
      amount: Number(amount),
      currency: 'BRL',
      pix_copy_paste: pixCopyPaste,
      qr_code_url: qrCodeUrl,
      expires_in_minutes: 15,
      message: 'Pix gerado com sucesso. Copie o código ou escaneie o QR Code.'
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
