import { Link } from 'react-router-dom';

/**
 * About page component.
 * Explains how the rating system works.
 */
export function About() {
  return (
    <div className="max-w-3xl mx-auto px-4 py-4 sm:py-8 overflow-auto h-full">
      <h1 className="text-2xl sm:text-3xl font-bold text-gray-900 mb-4 sm:mb-6">About ClubMash</h1>

      <div className="prose prose-sm sm:prose-lg">
        <section className="mb-4 sm:mb-8">
          <h2 className="text-lg sm:text-xl font-semibold text-gray-900 mb-2">What is ClubMash?</h2>
          <p className="text-gray-600 text-sm sm:text-base mb-2">
            A fun way for Berkeley students to rate clubs. Vote between two clubs, rankings emerge from collective votes.
          </p>
        </section>

        <section className="mb-4 sm:mb-8">
          <h2 className="text-lg sm:text-xl font-semibold text-gray-900 mb-2">How It Works</h2>
          <p className="text-gray-600 text-sm sm:text-base mb-2">
            Click on the club you'd rather join. Uses ELO rating (like chess) - upsets matter more.
          </p>
        </section>

        <section className="mb-4 sm:mb-8">
          <h2 className="text-lg sm:text-xl font-semibold text-gray-900 mb-2">Anonymous</h2>
          <p className="text-gray-600 text-sm sm:text-base mb-2">
            No account needed. We don't track who you are.
          </p>
        </section>

        <section className="mb-4 sm:mb-8">
          <h2 className="text-lg sm:text-xl font-semibold text-gray-900 mb-2">Disclaimer</h2>
          <p className="text-gray-600 text-sm sm:text-base mb-2">
            Not affiliated with UC Berkeley or ASUC. For entertainment only.
          </p>
        </section>

        <section>
          <Link
            to="/"
            className="inline-block px-4 sm:px-6 py-2 sm:py-3 bg-berkeley-blue text-white font-semibold rounded-lg hover:bg-berkeley-blue/90 transition-colors text-sm sm:text-base"
          >
            Start Voting
          </Link>
        </section>
      </div>
    </div>
  );
}
