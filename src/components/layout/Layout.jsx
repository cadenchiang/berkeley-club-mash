import { useEffect, useRef } from 'react';
import { Header } from './Header';
import { Footer } from './Footer';

const TURNSTILE_SITE_KEY = '0x4AAAAAACV5Q_kQzhJqOwF2';

/**
 * Main layout wrapper component.
 * Provides consistent header, footer, and main content area.
 * @param {{ children: React.ReactNode }} props - Child components to render.
 */
export function Layout({ children }) {
  const turnstileRef = useRef(null);
  const widgetIdRef = useRef(null);

  useEffect(() => {
    const initTurnstile = () => {
      if (!window.turnstile || !turnstileRef.current || widgetIdRef.current) return;

      console.warn('[Turnstile] Initializing widget...');

      widgetIdRef.current = window.turnstile.render(turnstileRef.current, {
        sitekey: TURNSTILE_SITE_KEY,
        size: 'compact',
        callback: (token) => {
          console.warn('[Turnstile] ✓ Verified successfully');
        },
        'error-callback': (error) => {
          console.warn('[Turnstile] ✗ Error:', error);
        },
        'expired-callback': () => {
          console.warn('[Turnstile] Token expired, refreshing...');
          if (widgetIdRef.current) {
            window.turnstile.reset(widgetIdRef.current);
          }
        },
      });

      console.warn('[Turnstile] Widget rendered, id:', widgetIdRef.current);
    };

    // Wait for Turnstile script to load
    if (window.turnstile) {
      initTurnstile();
    } else {
      console.warn('[Turnstile] Waiting for script...');
      const checkInterval = setInterval(() => {
        if (window.turnstile) {
          clearInterval(checkInterval);
          initTurnstile();
        }
      }, 100);

      setTimeout(() => {
        clearInterval(checkInterval);
        if (!window.turnstile) {
          console.error('[Turnstile] ✗ Script failed to load after 10s');
        }
      }, 10000);
    }

    return () => {
      if (widgetIdRef.current && window.turnstile) {
        window.turnstile.remove(widgetIdRef.current);
        widgetIdRef.current = null;
      }
    };
  }, []);

  return (
    <div className="h-full flex flex-col">
      <Header />
      <main className="flex-1 flex items-center justify-center overflow-auto">
        {children}
      </main>
      <Footer />
      {/* Invisible Turnstile widget */}
      <div ref={turnstileRef} className="fixed -left-[9999px]" />
    </div>
  );
}
