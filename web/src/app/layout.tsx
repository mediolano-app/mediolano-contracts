import type { Metadata } from "next";
import { Inter } from "next/font/google";
import { Providers } from "@/components/Providers";
import "./globals.css";
import Header from '@/components/header'
import Footer from "@/components/footer"

const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: "Mediolano",
  description: "Intellectual Property Powered by Starknet",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className={inter.className}>
        <div className="flex flex-col min-h-screen">
        <Header />
        <main className="flex-grow container mx-auto px-4 py-8">
        <Providers>{children}</Providers>
        </main>
        <Footer />
        </div>
      </body>
    </html>
  );
}
