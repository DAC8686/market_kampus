import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "MPUS — Marketplace Komunitas Kampus Terpercaya",
  description: "Beli dan jual barang kampus aman dengan sistem COD terverifikasi mahasiswa.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="id">
      <body className="min-h-screen bg-[#F5F5F5] text-[#242D38] antialiased">
        {children}
      </body>
    </html>
  );
}
