-- =====================================================================
-- UPPI BACKEND - ESQUEMA DE BANCO DE DADOS (SUPABASE POSTGRES + POSTGIS)
-- Região: sa-east-1 (São Paulo, Brasil)
-- Projeto: Uppi Back (bhyqkrnfdbrewcwaiomh)
-- =====================================================================

-- 1. Habilitar extensão geoespacial PostGIS
CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA extensions;

-- 2. Tabela de Perfis de Usuários (Passageiros e Motoristas)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name TEXT NOT NULL,
    phone TEXT NOT NULL UNIQUE,
    role TEXT NOT NULL DEFAULT 'rider' CHECK (role IN ('rider', 'driver', 'admin')),
    avatar_url TEXT,
    rating NUMERIC(3, 2) DEFAULT 5.00,
    pix_key TEXT,
    pix_key_type TEXT CHECK (pix_key_type IN ('cpf', 'phone', 'email', 'random')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Garantir geração automática de UUID e ausência de travas desnecessárias
ALTER TABLE public.profiles ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_id_fkey;

-- 3. Tabela de Veículos dos Motoristas
CREATE TABLE IF NOT EXISTS public.vehicles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    model TEXT NOT NULL,
    brand TEXT NOT NULL,
    color TEXT NOT NULL,
    license_plate TEXT NOT NULL UNIQUE,
    year INTEGER,
    category TEXT NOT NULL DEFAULT 'pop' CHECK (category IN ('pop', 'comfort', 'moto', 'delivery')),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Tabela de Localizações em Tempo Real (Telemetria com Índice Geoespacial GIST)
CREATE TABLE IF NOT EXISTS public.driver_locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE UNIQUE,
    location GEOGRAPHY(Point, 4326) NOT NULL,
    bearing NUMERIC(5, 2) DEFAULT 0,
    speed NUMERIC(5, 2) DEFAULT 0,
    is_online BOOLEAN DEFAULT TRUE,
    is_available BOOLEAN DEFAULT TRUE,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_driver_locations_spatial 
ON public.driver_locations USING GIST (location);

-- 5. Tabela de Tarifas Brasileiras (Valores em Reais - BRL)
CREATE TABLE IF NOT EXISTS public.tariffs (
    category TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    base_fare NUMERIC(10, 2) NOT NULL,
    per_km_rate NUMERIC(10, 2) NOT NULL,
    per_minute_rate NUMERIC(10, 2) NOT NULL,
    minimum_fare NUMERIC(10, 2) NOT NULL,
    currency TEXT DEFAULT 'BRL',
    surge_multiplier NUMERIC(3, 2) DEFAULT 1.00,
    is_active BOOLEAN DEFAULT TRUE
);

-- Seed de Tarifas Brasileiras
INSERT INTO public.tariffs (category, name, base_fare, per_km_rate, per_minute_rate, minimum_fare, currency)
VALUES
    ('pop', 'Uppi Pop', 5.50, 2.10, 0.35, 9.00, 'BRL'),
    ('comfort', 'Uppi Comfort', 8.00, 2.80, 0.45, 14.00, 'BRL'),
    ('moto', 'Uppi Moto', 3.50, 1.40, 0.25, 7.00, 'BRL'),
    ('delivery', 'Uppi Entrega', 5.00, 1.80, 0.30, 8.50, 'BRL')
ON CONFLICT (category) DO UPDATE SET
    name = EXCLUDED.name,
    base_fare = EXCLUDED.base_fare,
    per_km_rate = EXCLUDED.per_km_rate,
    per_minute_rate = EXCLUDED.per_minute_rate,
    minimum_fare = EXCLUDED.minimum_fare;

-- 6. Tabela de Corridas (Histórico e Ciclo de Vida da Viagem)
CREATE TABLE IF NOT EXISTS public.rides (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_number TEXT NOT NULL UNIQUE,
    rider_id UUID REFERENCES public.profiles(id),
    driver_id UUID REFERENCES public.profiles(id),
    origin_lat DOUBLE PRECISION NOT NULL,
    origin_lon DOUBLE PRECISION NOT NULL,
    origin_address TEXT NOT NULL,
    dest_lat DOUBLE PRECISION NOT NULL,
    dest_lon DOUBLE PRECISION NOT NULL,
    dest_address TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'pop',
    distance_meters INTEGER,
    duration_seconds INTEGER,
    estimated_fare NUMERIC(10, 2) NOT NULL,
    final_fare NUMERIC(10, 2),
    status TEXT NOT NULL DEFAULT 'searching' 
        CHECK (status IN ('searching', 'driver_assigned', 'arrived', 'in_progress', 'completed', 'cancelled')),
    payment_method TEXT DEFAULT 'pix' CHECK (payment_method IN ('pix', 'card', 'cash')),
    payment_status TEXT DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'refunded', 'failed')),
    pix_copy_paste TEXT,
    pix_qr_url TEXT,
    cancel_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. Tabela de Mensagens do Chat da Corrida
CREATE TABLE IF NOT EXISTS public.ride_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ride_id UUID NOT NULL REFERENCES public.rides(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES public.profiles(id),
    sender_role TEXT NOT NULL CHECK (sender_role IN ('rider', 'driver', 'system')),
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. Stored Procedure Geoespacial: Localizar Motoristas Próximos
CREATE OR REPLACE FUNCTION public.find_nearby_drivers(
    p_lat DOUBLE PRECISION,
    p_lon DOUBLE PRECISION,
    p_radius_meters DOUBLE PRECISION DEFAULT 5000,
    p_category TEXT DEFAULT 'pop'
)
RETURNS TABLE (
    driver_id UUID,
    full_name TEXT,
    phone TEXT,
    rating NUMERIC,
    model TEXT,
    brand TEXT,
    color TEXT,
    license_plate TEXT,
    distance_meters DOUBLE PRECISION,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id AS driver_id,
        p.full_name,
        p.phone,
        p.rating,
        v.model,
        v.brand,
        v.color,
        v.license_plate,
        ST_Distance(
            dl.location,
            ST_SetSRID(ST_MakePoint(p_lon, p_lat), 4326)::geography
        ) AS distance_meters,
        ST_Y(dl.location::geometry) AS latitude,
        ST_X(dl.location::geometry) AS longitude
    FROM public.driver_locations dl
    JOIN public.profiles p ON p.id = dl.driver_id
    JOIN public.vehicles v ON v.driver_id = p.id
    WHERE dl.is_online = TRUE 
      AND dl.is_available = TRUE
      AND v.is_active = TRUE
      AND v.category = p_category
      AND ST_DWithin(
          dl.location,
          ST_SetSRID(ST_MakePoint(p_lon, p_lat), 4326)::geography,
          p_radius_meters
      )
    ORDER BY distance_meters ASC
    LIMIT 20;
END;
$$;

-- 9. Habilitar Row Level Security (RLS)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tariffs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rides ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ride_messages ENABLE ROW LEVEL SECURITY;

-- Políticas de Acesso
CREATE POLICY "Leitura pública de tarifas" ON public.tariffs FOR SELECT USING (true);
CREATE POLICY "Leitura pública de perfis" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Leitura pública de veículos" ON public.vehicles FOR SELECT USING (true);
CREATE POLICY "Leitura pública de motoristas online" ON public.driver_locations FOR SELECT USING (true);
CREATE POLICY "Acesso completo de corridas" ON public.rides FOR ALL USING (true);
CREATE POLICY "Acesso completo de mensagens" ON public.ride_messages FOR ALL USING (true);
