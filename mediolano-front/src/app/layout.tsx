import type { Metadata } from "next";
import "./globals.css";
import { StarknetProvider } from "@/components/starknet-provider";
import { ThemeProvider } from "@/components/theme-provider"
import { Header } from '@/components/header'
import { Footer } from '@/components/footer'
import Image from "next/image";
import AnimatedBackground from '@/components/AnimatedBackground'

export const metadata: Metadata = {
  title: "Mediolano.app",
  description: "Powered by Starknet",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className="gradient-background">
         <ThemeProvider
            attribute="class"
            defaultTheme="system"
            enableSystem
            disableTransitionOnChange
          >
        <StarknetProvider>
        <AnimatedBackground />
        <Header />
        
        {children}
        <Footer />
        </StarknetProvider>
        </ThemeProvider>
      </body>
    </html>
  );
}
