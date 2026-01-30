import { Link } from 'react-router-dom';

/**
 * About page component.
 * Explains how the rating system works.
 */
export function About() {
  return (
    <div className="max-w-md mx-auto px-4 py-2 text-center">
      <h1 className="text-xl sm:text-2xl font-bold text-gray-900 mb-4">clubmash</h1>

      <div className="space-y-3 text-gray-500 text-sm mb-6">
        <p>hot or not but for berkeley clubs</p>
        <p>pick the better club. elo does the rest.</p>
        <p>no login. completely anonymous.</p>
        <p className="text-xs text-gray-400">not affiliated with berkeley lol</p>
      </div>

      <Link
        to="/"
        className="inline-block px-6 py-2 bg-berkeley-blue text-white rounded-lg hover:bg-berkeley-blue/90 transition-colors text-sm"
      >
        vote
      </Link>
    </div>
  );
}
