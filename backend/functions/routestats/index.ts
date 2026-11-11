import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.48.1";

export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
};

function calculateDistanceKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371; // Raio da Terra em km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = 
    Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * 
    Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') || '';
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || Deno.env.get('SUPABASE_ANON_KEY') || '';
    const supabase = createClient(supabaseUrl, supabaseKey);

    const body = await req.json().catch(() => ({}));
    const { origin, destination } = body;

    if (!origin || !destination) {
      return new Response(JSON.stringify({ error: 'Origem e destino são obrigatórios' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Distância geodésica com fator de correção de malha viária urbana (1.3)
    const rawKm = calculateDistanceKm(origin.lat, origin.lon, destination.lat, destination.lon);
    const roadFactor = 1.30;
    const distanceKm = Math.max(0.5, rawKm * roadFactor);
    const distanceMeters = Math.round(distanceKm * 1000);
    
    // Estimativa de tempo (velocidade média urbana de 28 km/h)
    const durationMinutes = Math.max(3, Math.round((distanceKm / 28) * 60));
    const durationSeconds = durationMinutes * 60;

    // Buscar tarifas ativas do banco
    const { data: tariffs, error: tariffErr } = await supabase
      .from('tariffs')
      .select('*')
      .eq('is_active', true);

    if (tariffErr || !tariffs) {
      throw new Error('Falha ao carregar tarifas');
    }

    // Calcular preços para cada categoria
    const options = tariffs.map((t: any) => {
      const calculatedPrice = Number(t.base_fare) + 
        (distanceKm * Number(t.per_km_rate)) + 
        (durationMinutes * Number(t.per_minute_rate));
      
      const finalPrice = Math.max(Number(t.minimum_fare), calculatedPrice * Number(t.surge_multiplier || 1.0));
      const roundedPrice = Math.round(finalPrice * 100) / 100;

      return {
        category: t.category,
        name: t.name,
        price: roundedPrice,
        formatted_price: `R$ ${roundedPrice.toFixed(2).replace('.', ',')}`,
        currency: 'BRL',
        eta_minutes: t.category === 'moto' ? 3 : 4,
        eta_text: `${t.category === 'moto' ? 3 : 4} min`,
        distance_km: Math.round(distanceKm * 10) / 10,
        duration_minutes: durationMinutes
      };
    });

    return new Response(JSON.stringify({
      status: 'ok',
      distance_meters: distanceMeters,
      duration_seconds: durationSeconds,
      distance_km: Math.round(distanceKm * 10) / 10,
      duration_minutes: durationMinutes,
      options: options
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
