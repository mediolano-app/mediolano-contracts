import Header from './header'
import Footer from './footer'
import { Providers } from "@/components/Providers";
import "../styles/globals.css"

export default function Layout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex flex-col min-h-screen bg-gray-100">
      <Header />
      <main className="flex-grow container mx-auto px-4 py-8">
      <Providers>{children}</Providers>
      </main>
      <Footer />
    </div>
  )
}