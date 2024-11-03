// src/pages/_app.tsx
import { AppProps } from "next/app";
import { Providers } from "@/components/Providers"; // Ensure this path matches your project structure
import { ThemeProvider } from "@/components/theme-provider";
import Header from "@/components/header";
import Footer from "@/components/footer";

import "@/styles/globals.css"; // You can add global styles here

export default function App({ Component, pageProps }: AppProps) {
  return (
    <ThemeProvider
              attribute="class"
              defaultTheme="system"
              enableSystem
              disableTransitionOnChange
            >
          <Providers>
            <div className="flex flex-col min-h-screen gradient-background">
              <Header />
                <main className="flex-grow container mx-auto px-4 py-8">
                <Component {...pageProps} />
                </main>
                <Footer />
            </div>
          </Providers>
        </ThemeProvider>
  );
}
