import { Link, useLocation } from 'react-router-dom';

/**
 * Header component with navigation.
 * Displays logo and navigation links.
 */
export function Header() {
  const location = useLocation();

  const navLinks = [
    { path: '/', label: 'Vote' },
    { path: '/rankings', label: 'Rankings' },
    { path: '/about', label: 'About' },
  ];

  return (
    <header className="bg-berkeley-blue text-white shadow-lg">
      <div className="max-w-6xl mx-auto px-3 sm:px-4 py-3 sm:py-4">
        <div className="flex items-center justify-between">
          <Link to="/" className="flex items-center gap-1.5 sm:gap-2">
            <span className="text-xl sm:text-2xl">🐻</span>
            <span className="text-lg sm:text-xl font-bold text-berkeley-gold">ClubMash</span>
          </Link>

          <nav className="flex items-center gap-4 sm:gap-6">
            {navLinks.map((link) => (
              <Link
                key={link.path}
                to={link.path}
                className={`text-sm font-medium transition-colors hover:text-berkeley-gold ${
                  location.pathname === link.path
                    ? 'text-berkeley-gold'
                    : 'text-white/80'
                }`}
              >
                {link.label}
              </Link>
            ))}
          </nav>
        </div>
      </div>
    </header>
  );
}
