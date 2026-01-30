import { Link } from 'react-router-dom';

/**
 * About page component.
 * Explains how the rating system works.
 */
export function About() {
  return (
    <div className="max-w-3xl mx-auto px-4 py-8">
      <h1 className="text-3xl font-bold text-gray-900 mb-6">About ClubMash</h1>

      <div className="prose prose-lg">
        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mb-3">What is ClubMash?</h2>
          <p className="text-gray-600 mb-4">
            ClubMash is a fun, anonymous way for UC Berkeley students to rate and discover
            campus clubs. Inspired by the classic "Hot or Not" style comparisons, you vote
            between two clubs at a time, and rankings emerge from the collective wisdom of
            the Berkeley community.
          </p>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mb-3">How Does Voting Work?</h2>
          <p className="text-gray-600 mb-4">
            Each time you visit, you'll see two random clubs side by side. Simply click on
            the one you'd rather join. Your vote updates both clubs' rankings using an
            ELO rating system—the same system used in chess!
          </p>
          <div className="bg-berkeley-blue/5 rounded-lg p-4 mb-4">
            <h3 className="font-medium text-gray-900 mb-2">ELO Rating Explained:</h3>
            <ul className="list-disc list-inside text-gray-600 space-y-1">
              <li>All clubs start with a rating of 1500</li>
              <li>When you vote, the winner gains points and the loser loses points</li>
              <li>Upsets matter more: beating a highly-rated club gives more points</li>
              <li>Over time, the best clubs rise to the top</li>
            </ul>
          </div>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mb-3">Is It Anonymous?</h2>
          <p className="text-gray-600 mb-4">
            Yes! You don't need to create an account or log in. We use a random session ID
            stored in your browser to prevent spam, but we never track who you are or
            connect your votes to your identity.
          </p>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mb-3">Disclaimer</h2>
          <p className="text-gray-600 mb-4">
            ClubMash is an independent project created for entertainment purposes. It is
            not affiliated with, endorsed by, or connected to UC Berkeley, ASUC, or any
            official campus organization. Rankings are based solely on anonymous user
            votes and do not reflect any official assessment of club quality.
          </p>
        </section>

        <section>
          <h2 className="text-xl font-semibold text-gray-900 mb-3">Ready to Vote?</h2>
          <Link
            to="/"
            className="inline-block px-6 py-3 bg-berkeley-blue text-white font-semibold rounded-lg hover:bg-berkeley-blue/90 transition-colors"
          >
            Start Voting
          </Link>
        </section>
      </div>
    </div>
  );
}
