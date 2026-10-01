"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { supabase } from "@/lib/supabase";
import { ShoppingBag, ShieldCheck, Search, Sparkles, ExternalLink, UserCheck } from "lucide-react";

interface Product {
  id: string;
  name: string;
  price: number;
  description: string;
  category: string;
  images: string[];
  seller_id: string;
  created_at: string;
  is_sold: boolean;
  seller_name?: string;
  seller_campus?: string;
  seller_phone?: string;
}

const CATEGORIES = ["Semua", "Buku", "Elektronik", "Fashion", "Makanan", "Alat Tulis", "Jasa"];

export default function HomePage() {
  const [products, setProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedCategory, setSelectedCategory] = useState("Semua");
  const [searchQuery, setSearchQuery] = useState("");

  useEffect(() => {
    fetchProducts();
  }, [selectedCategory]);

  async function fetchProducts() {
    setLoading(true);
    try {
      let query = supabase
        .from("products")
        .select(`
          id, name, price, description, category, images, seller_id, created_at, is_sold,
          profiles:seller_id (name, campus_name, phone)
        `)
        .eq("is_sold", false)
        .order("created_at", { ascending: false });

      if (selectedCategory !== "Semua") {
        query = query.eq("category", selectedCategory);
      }

      const { data, error } = await query;
      if (!error && data) {
        const mapped: Product[] = data.map((item: any) => ({
          ...item,
          seller_name: item.profiles?.name || "Penjual Mahasiswa",
          seller_campus: item.profiles?.campus_name || "Kampus",
          seller_phone: item.profiles?.phone || "",
        }));
        setProducts(mapped);
      }
    } catch (err) {
      console.error("Error loading products:", err);
    } finally {
      setLoading(false);
    }
  }

  const filteredProducts = products.filter((p) =>
    p.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
    p.description.toLowerCase().includes(searchQuery.toLowerCase())
  );

  return (
    <div className="min-h-screen flex flex-col bg-[#F5F5F5]">
      {/* Header / Navbar */}
      <header className="sticky top-0 z-40 bg-[#B4FFF9] border-b border-[#D9D9D9] shadow-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-white flex items-center justify-center shadow-sm">
              <ShoppingBag className="w-6 h-6 text-[#00838F]" />
            </div>
            <div>
              <span className="text-xl font-bold tracking-tight text-[#242D38]">MPUS</span>
              <span className="hidden sm:inline-block text-xs font-semibold ml-2 px-2 py-0.5 rounded-full bg-white/70 text-[#00838F]">
                Marketplace Kampus
              </span>
            </div>
          </div>

          <div className="flex items-center gap-3">
            <Link
              href="/admin"
              className="inline-flex items-center gap-2 px-4 py-2 rounded-full text-xs sm:text-sm font-semibold bg-[#242D38] text-white hover:bg-black transition-colors shadow-sm"
            >
              <UserCheck className="w-4 h-4 text-[#B4FFF9]" />
              <span>Admin Portal</span>
            </Link>
          </div>
        </div>
      </header>

      {/* Hero Section */}
      <section className="bg-gradient-to-b from-[#B4FFF9]/40 to-[#F5F5F5] py-12 px-4 sm:px-6 lg:px-8 text-center">
        <div className="max-w-3xl mx-auto space-y-4">
          <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-white shadow-sm border border-[#B4FFF9] text-xs font-bold text-[#00838F]">
            <ShieldCheck className="w-4 h-4 text-[#00C4B4]" />
            100% Terverifikasi Mahasiswa (AI KTM Scanner)
          </div>
          <h1 className="text-3xl sm:text-4xl font-extrabold text-[#242D38] tracking-tight">
            Marketplace Komunitas Kampus Terpercaya
          </h1>
          <p className="text-sm sm:text-base text-gray-600">
            Jual beli aman antar mahasiswa, COD di area kampus, dan bebas penipuan.
          </p>

          {/* Search Bar */}
          <div className="pt-2 max-w-xl mx-auto relative">
            <Search className="w-5 h-5 absolute left-4 top-1/2 -translate-y-1/2 text-gray-400" />
            <input
              type="text"
              placeholder="Cari buku, modul, laptop, kosan, dll..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full pl-12 pr-4 py-3.5 rounded-2xl bg-white border border-[#D9D9D9] shadow-sm text-sm focus:outline-none focus:ring-2 focus:ring-[#00C4B4] transition-all"
            />
          </div>
        </div>
      </section>

      {/* Category Filter */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4 w-full">
        <div className="flex items-center gap-2 overflow-x-auto pb-2 scrollbar-none">
          {CATEGORIES.map((cat) => (
            <button
              key={cat}
              onClick={() => setSelectedCategory(cat)}
              className={`px-4 py-2 rounded-full text-xs sm:text-sm font-semibold whitespace-nowrap transition-all ${
                selectedCategory === cat
                  ? "bg-[#00838F] text-white shadow-sm"
                  : "bg-white text-gray-700 hover:bg-gray-100 border border-[#D9D9D9]"
              }`}
            >
              {cat}
            </button>
          ))}
        </div>
      </section>

      {/* Product Grid */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6 w-full flex-1">
        {loading ? (
          <div className="py-20 text-center space-y-3">
            <div className="w-10 h-10 border-4 border-[#00C4B4] border-t-transparent rounded-full animate-spin mx-auto" />
            <p className="text-sm text-gray-500 font-medium">Memuat katalog barang kampus...</p>
          </div>
        ) : filteredProducts.length === 0 ? (
          <div className="py-20 text-center bg-white rounded-3xl border border-[#D9D9D9] p-8 shadow-sm">
            <ShoppingBag className="w-12 h-12 text-gray-300 mx-auto mb-3" />
            <h3 className="text-base font-bold text-gray-700">Belum ada barang untuk kategori ini</h3>
            <p className="text-xs text-gray-500 mt-1">Jadilah mahasiswa pertama yang mengunggah barang jualan!</p>
          </div>
        ) : (
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-4 sm:gap-6">
            {filteredProducts.map((product) => {
              const imageSrc =
                product.images && product.images.length > 0
                  ? product.images[0]
                  : "https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=500&auto=format&fit=crop&q=60";

              return (
                <div
                  key={product.id}
                  className="bg-white rounded-2xl border border-[#D9D9D9] overflow-hidden shadow-sm hover:shadow-md transition-shadow flex flex-col justify-between group"
                >
                  <div className="relative aspect-square w-full bg-gray-100 overflow-hidden">
                    <img
                      src={imageSrc}
                      alt={product.name}
                      className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                    />
                    <span className="absolute top-2 left-2 text-[10px] font-bold px-2 py-0.5 rounded-md bg-black/60 text-white backdrop-blur-sm">
                      {product.category}
                    </span>
                  </div>

                  <div className="p-3.5 flex-1 flex flex-col justify-between">
                    <div>
                      <h4 className="font-bold text-sm text-[#242D38] line-clamp-1 group-hover:text-[#00838F] transition-colors">
                        {product.name}
                      </h4>
                      <p className="text-base font-extrabold text-[#00838F] mt-1">
                        Rp {Number(product.price).toLocaleString("id-ID")}
                      </p>
                      <p className="text-[11px] text-gray-500 line-clamp-2 mt-1">
                        {product.description}
                      </p>
                    </div>

                    <div className="mt-3 pt-2.5 border-t border-gray-100 flex items-center justify-between text-[11px] text-gray-500">
                      <span className="truncate max-w-[100px]">{product.seller_name}</span>
                      {product.seller_phone ? (
                        <a
                          href={`https://wa.me/${product.seller_phone}?text=Halo%20${encodeURIComponent(product.seller_name || '')},%20saya%20tertarik%20dengan%20barang%20${encodeURIComponent(product.name)}%20di%20MPUS`}
                          target="_blank"
                          rel="noreferrer"
                          className="inline-flex items-center gap-1 font-bold text-emerald-600 hover:text-emerald-700"
                        >
                          <span>Chat WA</span>
                          <ExternalLink className="w-3 h-3" />
                        </a>
                      ) : (
                        <span className="text-[10px] bg-gray-100 px-1.5 py-0.5 rounded">COD Kampus</span>
                      )}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </main>

      {/* Footer */}
      <footer className="bg-white border-t border-[#D9D9D9] py-8 text-center text-xs text-gray-500">
        <p className="font-medium">© 2026 MPUS — DACZDev (Pak Bos Dimas). All Rights Reserved.</p>
        <p className="text-gray-400 mt-1">Platform Mahasiswa Resmi dengan Proteksi AI Google Gemini 3.1</p>
      </footer>
    </div>
  );
}
