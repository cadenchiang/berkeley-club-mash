import { Header } from './Header';
import { Footer } from './Footer';

/**
 * Main layout wrapper component.
 * Provides consistent header, footer, and main content area.
 * @param {{ children: React.ReactNode }} props - Child components to render.
 */
export function Layout({ children }) {
  return (
    <div className="h-full flex flex-col">
      <Header />
      <main className="flex-1 flex items-start sm:items-center justify-center pt-4 sm:pt-0 overflow-auto">
        {children}
      </main>
      <Footer />
    </div>
  );
}
