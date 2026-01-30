import { Header } from './Header';
import { Footer } from './Footer';

/**
 * Main layout wrapper component.
 * Provides consistent header, footer, and main content area.
 * @param {{ children: React.ReactNode }} props - Child components to render.
 */
export function Layout({ children }) {
  return (
    <div className="h-full flex flex-col overflow-hidden sm:overflow-auto sm:min-h-screen">
      <Header />
      <main className="flex-1 flex items-center justify-center overflow-hidden">
        {children}
      </main>
      <Footer />
    </div>
  );
}
