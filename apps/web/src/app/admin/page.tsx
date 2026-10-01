"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { supabase } from "@/lib/supabase";
import {
  ShieldCheck,
  CheckCircle2,
  XCircle,
  Clock,
  ExternalLink,
  ArrowLeft,
  ZoomIn,
  RefreshCw,
  Search,
  Users,
  AlertTriangle,
  FileText
} from "lucide-react";

interface Profile {
  id: string;
  email: string;
  name: string;
  phone: string;
  nim?: string;
  campus_name?: string;
  ktm_image_url?: string;
  is_ktm_verified: boolean;
  verification_status: "VERIFIED" | "PENDING_REVIEW" | "REJECTED" | "UNVERIFIED";
  created_at: string;
}

export default function AdminPage() {
  const [profiles, setProfiles] = useState<Profile[]>([]);
  const [loading, setLoading] = useState(true);
  const [filterTab, setFilterTab] = useState<"PENDING_REVIEW" | "VERIFIED" | "REJECTED" | "ALL">("PENDING_REVIEW");
  const [searchQuery, setSearchQuery] = useState("");
  const [selectedImage, setSelectedImage] = useState<string | null>(null);
  const [processingId, setProcessingId] = useState<string | null>(null);
  const [feedbackMsg, setFeedbackMsg] = useState<{ text: string; type: "success" | "error" } | null>(null);

  useEffect(() => {
    loadProfiles();
  }, []);

  async function loadProfiles() {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from("profiles")
        .select("id, email, name, phone, nim, campus_name, ktm_image_url, is_ktm_verified, verification_status, created_at")
        .order("created_at", { ascending: false });

      if (!error && data) {
        setProfiles(data as Profile[]);
      }
    } catch (err) {
      console.error("Failed to load profiles:", err);
    } finally {
      setLoading(false);
    }
  }

  async function handleUpdateStatus(userId: string, newStatus: "VERIFIED" | "REJECTED") {
    setProcessingId(userId);
    setFeedbackMsg(null);

    try {
      const isVerified = newStatus === "VERIFIED";
      const { error } = await supabase
        .from("profiles")
        .update({
          verification_status: newStatus,
          is_ktm_verified: isVerified,
          updated_at: new Date().toISOString(),
        })
        .eq("id", userId);

      if (error) throw error;

      setProfiles((prev) =>
        prev.map((p) =>
          p.id === userId
            ? { ...p, verification_status: newStatus, is_ktm_verified: isVerified }
            : p
        )
      );

      setFeedbackMsg({
        text: isVerified
          ? "✓ Berhasil menyetujui verifikasi KTM mahasiswa!"
          : "✕ Status verifikasi mahasiswa telah ditolak.",
        type: "success",
      });
    } catch (err: any) {
      setFeedbackMsg({
        text: `Gagal memperbarui status: ${err.message}`,
        type: "error",
      });
    } finally {
      setProcessingId(null);
    }
  }

  const filtered = profiles.filter((p) => {
    const matchesTab =
      filterTab === "ALL"
        ? true
        : p.verification_status === filterTab ||
          (filterTab === "PENDING_REVIEW" && (!p.verification_status || p.verification_status === "PENDING_REVIEW") && p.ktm_image_url);

    const matchesSearch =
      (p.name || "").toLowerCase().includes(searchQuery.toLowerCase()) ||
      (p.nim || "").toLowerCase().includes(searchQuery.toLowerCase()) ||
      (p.email || "").toLowerCase().includes(searchQuery.toLowerCase()) ||
      (p.phone || "").includes(searchQuery);

    return matchesTab && matchesSearch;
  });

  const countPending = profiles.filter((p) => p.verification_status === "PENDING_REVIEW" || (!p.verification_status && p.ktm_image_url && !p.is_ktm_verified)).length;
  const countVerified = profiles.filter((p) => p.is_ktm_verified || p.verification_status === "VERIFIED").length;
  const countRejected = profiles.filter((p) => p.verification_status === "REJECTED").length;

  return (
    <div className="min-h-screen bg-[#F5F5F5] flex flex-col">
      {/* Admin Top Navbar */}
      <header className="sticky top-0 z-40 bg-[#242D38] text-white shadow-md">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <Link href="/" className="p-2 rounded-lg hover:bg-white/10 transition-colors text-gray-300">
              <ArrowLeft className="w-5 h-5" />
            </Link>
            <div className="flex items-center gap-2">
              <ShieldCheck className="w-6 h-6 text-[#B4FFF9]" />
              <h1 className="text-lg font-bold tracking-tight">MPUS Admin Verification Center</h1>
            </div>
          </div>

          <div className="flex items-center gap-3">
            <button
              onClick={loadProfiles}
              disabled={loading}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold bg-white/10 hover:bg-white/20 transition-colors text-gray-200"
            >
              <RefreshCw className={`w-3.5 h-3.5 ${loading ? "animate-spin" : ""}`} />
              <span>Refresh</span>
            </button>
          </div>
        </div>
      </header>

      {/* Main Admin Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 w-full flex-1 space-y-6">
        {/* Feedback Alert */}
        {feedbackMsg && (
          <div
            className={`p-4 rounded-2xl border text-sm font-semibold flex items-center justify-between shadow-sm animate-in fade-in duration-200 ${
              feedbackMsg.type === "success"
                ? "bg-emerald-50 text-emerald-800 border-emerald-200"
                : "bg-rose-50 text-rose-800 border-rose-200"
            }`}
          >
            <span>{feedbackMsg.text}</span>
            <button onClick={() => setFeedbackMsg(null)} className="text-xs underline ml-4">
              Tutup
            </button>
          </div>
        )}

        {/* Stats Row */}
        <div className="grid grid-cols-1 sm:grid-cols-4 gap-4">
          <div
            onClick={() => setFilterTab("PENDING_REVIEW")}
            className={`p-5 rounded-2xl bg-white border cursor-pointer transition-all shadow-sm ${
              filterTab === "PENDING_REVIEW" ? "border-[#00C4B4] ring-2 ring-[#00C4B4]/20" : "border-[#D9D9D9] hover:border-gray-400"
            }`}
          >
            <div className="flex items-center justify-between text-amber-600">
              <span className="text-xs font-bold uppercase tracking-wider">Perlu Tinjauan</span>
              <Clock className="w-5 h-5" />
            </div>
            <p className="text-3xl font-extrabold text-[#242D38] mt-2">{countPending}</p>
            <p className="text-xs text-gray-500 mt-1">Pengajuan KTM yang menunggu review</p>
          </div>

          <div
            onClick={() => setFilterTab("VERIFIED")}
            className={`p-5 rounded-2xl bg-white border cursor-pointer transition-all shadow-sm ${
              filterTab === "VERIFIED" ? "border-emerald-500 ring-2 ring-emerald-500/20" : "border-[#D9D9D9] hover:border-gray-400"
            }`}
          >
            <div className="flex items-center justify-between text-emerald-600">
              <span className="text-xs font-bold uppercase tracking-wider">Terverifikasi</span>
              <CheckCircle2 className="w-5 h-5" />
            </div>
            <p className="text-3xl font-extrabold text-[#242D38] mt-2">{countVerified}</p>
            <p className="text-xs text-gray-500 mt-1">Mahasiswa sah & aktif menjual</p>
          </div>

          <div
            onClick={() => setFilterTab("REJECTED")}
            className={`p-5 rounded-2xl bg-white border cursor-pointer transition-all shadow-sm ${
              filterTab === "REJECTED" ? "border-rose-500 ring-2 ring-rose-500/20" : "border-[#D9D9D9] hover:border-gray-400"
            }`}
          >
            <div className="flex items-center justify-between text-rose-600">
              <span className="text-xs font-bold uppercase tracking-wider">Ditolak</span>
              <XCircle className="w-5 h-5" />
            </div>
            <p className="text-3xl font-extrabold text-[#242D38] mt-2">{countRejected}</p>
            <p className="text-xs text-gray-500 mt-1">KTM buram / tidak sesuai</p>
          </div>

          <div
            onClick={() => setFilterTab("ALL")}
            className={`p-5 rounded-2xl bg-white border cursor-pointer transition-all shadow-sm ${
              filterTab === "ALL" ? "border-gray-800 ring-2 ring-gray-800/20" : "border-[#D9D9D9] hover:border-gray-400"
            }`}
          >
            <div className="flex items-center justify-between text-gray-600">
              <span className="text-xs font-bold uppercase tracking-wider">Total Akun</span>
              <Users className="w-5 h-5" />
            </div>
            <p className="text-3xl font-extrabold text-[#242D38] mt-2">{profiles.length}</p>
            <p className="text-xs text-gray-500 mt-1">Semua pengguna terdaftar</p>
          </div>
        </div>

        {/* Filter & Search Bar */}
        <div className="bg-white p-4 rounded-2xl border border-[#D9D9D9] shadow-sm flex flex-col sm:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-2 w-full sm:w-auto overflow-x-auto">
            <button
              onClick={() => setFilterTab("PENDING_REVIEW")}
              className={`px-4 py-2 rounded-xl text-xs font-bold transition-all ${
                filterTab === "PENDING_REVIEW" ? "bg-amber-100 text-amber-900" : "bg-gray-100 text-gray-600 hover:bg-gray-200"
              }`}
            >
              ⏳ Antrean Review ({countPending})
            </button>
            <button
              onClick={() => setFilterTab("VERIFIED")}
              className={`px-4 py-2 rounded-xl text-xs font-bold transition-all ${
                filterTab === "VERIFIED" ? "bg-emerald-100 text-emerald-900" : "bg-gray-100 text-gray-600 hover:bg-gray-200"
              }`}
            >
              ✓ Terverifikasi ({countVerified})
            </button>
            <button
              onClick={() => setFilterTab("REJECTED")}
              className={`px-4 py-2 rounded-xl text-xs font-bold transition-all ${
                filterTab === "REJECTED" ? "bg-rose-100 text-rose-900" : "bg-gray-100 text-gray-600 hover:bg-gray-200"
              }`}
            >
              ✕ Ditolak ({countRejected})
            </button>
            <button
              onClick={() => setFilterTab("ALL")}
              className={`px-4 py-2 rounded-xl text-xs font-bold transition-all ${
                filterTab === "ALL" ? "bg-gray-800 text-white" : "bg-gray-100 text-gray-600 hover:bg-gray-200"
              }`}
            >
              Semua Akun
            </button>
          </div>

          <div className="relative w-full sm:w-72">
            <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
            <input
              type="text"
              placeholder="Cari Nama, NIM, No. WA..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full pl-9 pr-3 py-2 rounded-xl bg-gray-50 border border-gray-200 text-xs focus:outline-none focus:ring-2 focus:ring-[#00C4B4]"
            />
          </div>
        </div>

        {/* Verification Submissions List */}
        {loading ? (
          <div className="py-20 text-center space-y-3">
            <div className="w-10 h-10 border-4 border-[#00C4B4] border-t-transparent rounded-full animate-spin mx-auto" />
            <p className="text-sm text-gray-500 font-medium">Memuat data verifikasi...</p>
          </div>
        ) : filtered.length === 0 ? (
          <div className="py-16 text-center bg-white rounded-3xl border border-[#D9D9D9] p-8 shadow-sm">
            <CheckCircle2 className="w-12 h-12 text-emerald-400 mx-auto mb-3" />
            <h3 className="text-base font-bold text-gray-700">Tidak ada pengajuan dalam tab ini</h3>
            <p className="text-xs text-gray-500 mt-1">Semua data verifikasi mahasiswa telah selesai ditinjau.</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {filtered.map((profile) => {
              const hasKtm = Boolean(profile.ktm_image_url);
              const isVerified = profile.is_ktm_verified || profile.verification_status === "VERIFIED";
              const isRejected = profile.verification_status === "REJECTED";
              const isPending = !isVerified && !isRejected;

              return (
                <div
                  key={profile.id}
                  className="bg-white rounded-2xl border border-[#D9D9D9] shadow-sm hover:shadow-md transition-all overflow-hidden flex flex-col justify-between"
                >
                  <div className="p-5 space-y-4">
                    {/* Header Card */}
                    <div className="flex items-start justify-between">
                      <div>
                        <h3 className="font-bold text-base text-[#242D38]">{profile.name || "Nama Pengguna"}</h3>
                        <p className="text-xs text-gray-500">{profile.email || "Email tidak tersedia"}</p>
                      </div>
                      <span
                        className={`text-[10px] font-bold px-2.5 py-1 rounded-full uppercase tracking-wider ${
                          isVerified
                            ? "bg-emerald-100 text-emerald-800"
                            : isRejected
                            ? "bg-rose-100 text-rose-800"
                            : "bg-amber-100 text-amber-800"
                        }`}
                      >
                        {isVerified ? "✓ Verified" : isRejected ? "✕ Ditolak" : "⏳ Review"}
                      </span>
                    </div>

                    {/* Data Mahasiswa */}
                    <div className="p-3 bg-gray-50 rounded-xl space-y-1.5 text-xs text-gray-700">
                      <div className="flex justify-between">
                        <span className="text-gray-500">NIM:</span>
                        <span className="font-bold">{profile.nim || "Belum diisi"}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-500">Kampus:</span>
                        <span className="font-semibold">{profile.campus_name || "UNUGIRI"}</span>
                      </div>
                      <div className="flex justify-between items-center">
                        <span className="text-gray-500">WhatsApp:</span>
                        {profile.phone ? (
                          <a
                            href={`https://wa.me/${profile.phone}`}
                            target="_blank"
                            rel="noreferrer"
                            className="font-bold text-emerald-600 hover:underline inline-flex items-center gap-1"
                          >
                            <span>+{profile.phone}</span>
                            <ExternalLink className="w-3 h-3" />
                          </a>
                        ) : (
                          <span className="italic text-gray-400">-</span>
                        )}
                      </div>
                    </div>

                    {/* KTM Image Preview */}
                    <div>
                      <p className="text-xs font-bold text-gray-600 mb-1.5 flex items-center gap-1">
                        <FileText className="w-3.5 h-3.5 text-gray-400" />
                        Foto Kartu Tanda Mahasiswa (KTM)
                      </p>
                      {hasKtm ? (
                        <div
                          onClick={() => setSelectedImage(profile.ktm_image_url!)}
                          className="relative h-44 rounded-xl overflow-hidden border border-gray-200 bg-gray-100 group cursor-pointer"
                        >
                          <img
                            src={profile.ktm_image_url!}
                            alt="Foto KTM"
                            className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-200"
                          />
                          <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center text-white text-xs font-semibold gap-1">
                            <ZoomIn className="w-4 h-4" />
                            <span>Lihat Resolusi Penuh</span>
                          </div>
                        </div>
                      ) : (
                        <div className="h-28 rounded-xl border border-dashed border-gray-300 bg-gray-50 flex flex-col items-center justify-center text-gray-400 text-xs">
                          <AlertTriangle className="w-6 h-6 mb-1 text-amber-400" />
                          <span>Belum mengunggah foto KTM</span>
                        </div>
                      )}
                    </div>
                  </div>

                  {/* Actions Footer */}
                  <div className="p-4 bg-gray-50/80 border-t border-gray-100 flex items-center gap-2">
                    <button
                      onClick={() => handleUpdateStatus(profile.id, "VERIFIED")}
                      disabled={processingId === profile.id || isVerified}
                      className="flex-1 py-2.5 px-3 rounded-xl bg-emerald-600 hover:bg-emerald-700 disabled:opacity-50 text-white font-bold text-xs flex items-center justify-center gap-1.5 shadow-sm transition-colors"
                    >
                      <CheckCircle2 className="w-4 h-4" />
                      <span>{isVerified ? "Sudah Disetujui" : "Setujui KTM"}</span>
                    </button>

                    <button
                      onClick={() => handleUpdateStatus(profile.id, "REJECTED")}
                      disabled={processingId === profile.id || isRejected}
                      className="py-2.5 px-3 rounded-xl bg-white hover:bg-rose-50 border border-rose-200 text-rose-600 font-bold text-xs flex items-center justify-center gap-1 transition-colors disabled:opacity-50"
                    >
                      <XCircle className="w-4 h-4" />
                      <span>Tolak</span>
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </main>

      {/* Image Modal Preview */}
      {selectedImage && (
        <div
          onClick={() => setSelectedImage(null)}
          className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4"
        >
          <div className="relative max-w-3xl w-full bg-white rounded-3xl overflow-hidden shadow-2xl p-2 animate-in zoom-in-95 duration-200">
            <img src={selectedImage} alt="KTM Full Preview" className="w-full h-auto max-h-[80vh] object-contain rounded-2xl" />
            <div className="p-4 flex items-center justify-between">
              <span className="text-xs text-gray-500 font-semibold">Pratinjau Foto KTM Mahasiswa</span>
              <button
                onClick={() => setSelectedImage(null)}
                className="px-4 py-1.5 rounded-full bg-gray-900 text-white text-xs font-bold hover:bg-black"
              >
                Tutup
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
