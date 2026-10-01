-- ==============================================================================
-- 🛒 APPS MPUS (MARKET KAMPUS) — SUPABASE MASTER DATABASE SCHEMA
-- Author: Dimas Adhi C. (Tech Lead DACZDev)
-- Model: Local Campus Marketplace (COD & Direct QRIS/E-Wallet System)
-- ==============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==============================================================================
-- 2. TABEL: PROFILES (Data Pengguna & Toko Penjual)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    name TEXT NOT NULL DEFAULT 'Pengguna Mpus',
    phone TEXT DEFAULT '',
    avatar_url TEXT DEFAULT '',
    qris_image_url TEXT DEFAULT '',
    ewallet_name TEXT DEFAULT 'DANA / GoPay / OVO',
    ewallet_number TEXT DEFAULT '',
    campus_name TEXT DEFAULT 'Kampus',
    fcm_token TEXT DEFAULT '',
    rating_total FLOAT DEFAULT 0.0,
    rating_count INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- RLS: Profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public profiles are viewable by everyone" 
ON public.profiles FOR SELECT USING (true);

CREATE POLICY "Users can insert their own profile" 
ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile" 
ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Trigger Otomatis: Buat profile saat user sign up via Supabase Auth
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, name, phone, avatar_url)
  VALUES (
    new.id,
    new.email,
    COALESCE(new.raw_user_meta_data->>'name', 'Pengguna Mpus'),
    COALESCE(new.raw_user_meta_data->>'phone', ''),
    COALESCE(new.raw_user_meta_data->>'avatar_url', '')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- ==============================================================================
-- 3. TABEL: PRODUCTS (Katalog Barang Marketplace)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    seller_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    price NUMERIC NOT NULL DEFAULT 0,
    description TEXT NOT NULL DEFAULT '',
    images TEXT[] DEFAULT ARRAY[]::TEXT[],
    category TEXT NOT NULL DEFAULT 'Lainnya',
    condition TEXT DEFAULT 'Bekas - Mulus',
    is_sold BOOLEAN DEFAULT FALSE,
    is_cod_available BOOLEAN DEFAULT TRUE,
    is_qris_available BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- RLS: Products
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Products are viewable by everyone" 
ON public.products FOR SELECT USING (true);

CREATE POLICY "Authenticated users can insert products" 
ON public.products FOR INSERT WITH CHECK (auth.uid() = seller_id);

CREATE POLICY "Sellers can update their own products" 
ON public.products FOR UPDATE USING (auth.uid() = seller_id);

CREATE POLICY "Sellers can delete their own products" 
ON public.products FOR DELETE USING (auth.uid() = seller_id);

-- ==============================================================================
-- 4. TABEL: ORDERS (Transaksi & Kesepakatan COD / QRIS)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    buyer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    seller_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    payment_method TEXT NOT NULL CHECK (payment_method IN ('COD', 'QRIS', 'TRANSFER')),
    status TEXT NOT NULL DEFAULT 'MENUNGGU_KONFIRMASI' CHECK (status IN ('MENUNGGU_KONFIRMASI', 'DISETUJUI_COD', 'SUDAH_BAYAR_QRIS', 'SELESAI', 'DIBATALKAN')),
    cod_location TEXT DEFAULT '',
    cod_meeting_time TEXT DEFAULT '',
    total_price NUMERIC NOT NULL DEFAULT 0,
    notes TEXT DEFAULT '',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- RLS: Orders
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view orders they are involved in" 
ON public.orders FOR SELECT 
USING (auth.uid() = buyer_id OR auth.uid() = seller_id);

CREATE POLICY "Buyers can create orders" 
ON public.orders FOR INSERT WITH CHECK (auth.uid() = buyer_id);

CREATE POLICY "Involved parties can update orders" 
ON public.orders FOR UPDATE 
USING (auth.uid() = buyer_id OR auth.uid() = seller_id);

-- ==============================================================================
-- 5. TABEL: REVIEWS (Ulasan & Rating Bintang)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID REFERENCES public.orders(id) ON DELETE SET NULL,
    product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
    reviewer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    seller_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT DEFAULT '',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- RLS: Reviews
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Reviews are viewable by everyone" 
ON public.reviews FOR SELECT USING (true);

CREATE POLICY "Buyers can write reviews" 
ON public.reviews FOR INSERT WITH CHECK (auth.uid() = reviewer_id);

-- Trigger: Update Rating Profil Penjual secara otomatis saat ada review baru
CREATE OR REPLACE FUNCTION public.update_seller_rating() 
RETURNS TRIGGER AS $$
DECLARE
    avg_rating FLOAT;
    total_reviews INT;
BEGIN
    SELECT AVG(rating), COUNT(id) 
    INTO avg_rating, total_reviews 
    FROM public.reviews 
    WHERE seller_id = NEW.seller_id;

    UPDATE public.profiles 
    SET rating_total = COALESCE(avg_rating, 0.0),
        rating_count = COALESCE(total_reviews, 0),
        updated_at = timezone('utc'::text, now())
    WHERE id = NEW.seller_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_review_created ON public.reviews;
CREATE TRIGGER on_review_created
  AFTER INSERT OR UPDATE ON public.reviews
  FOR EACH ROW EXECUTE PROCEDURE public.update_seller_rating();

-- ==============================================================================
-- 6. STORAGE BUCKETS CONFIGURATION
-- ==============================================================================
-- Buat bucket penyimpanan file publik
INSERT INTO storage.buckets (id, name, public) 
VALUES ('product-images', 'product-images', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public) 
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public) 
VALUES ('qris-codes', 'qris-codes', true)
ON CONFLICT (id) DO NOTHING;

-- Kebijakan Storage Security
CREATE POLICY "Public Access Product Images" 
ON storage.objects FOR SELECT USING (bucket_id = 'product-images');

CREATE POLICY "Authenticated Users can upload Product Images" 
ON storage.objects FOR INSERT 
WITH CHECK (bucket_id = 'product-images' AND auth.role() = 'authenticated');

CREATE POLICY "Public Access Avatars" 
ON storage.objects FOR SELECT USING (bucket_id = 'avatars');

CREATE POLICY "Authenticated Users can upload Avatars" 
ON storage.objects FOR INSERT 
WITH CHECK (bucket_id = 'avatars' AND auth.role() = 'authenticated');

CREATE POLICY "Public Access QRIS" 
ON storage.objects FOR SELECT USING (bucket_id = 'qris-codes');

CREATE POLICY "Authenticated Users can upload QRIS" 
ON storage.objects FOR INSERT 
WITH CHECK (bucket_id = 'qris-codes' AND auth.role() = 'authenticated');
