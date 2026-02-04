import { Link } from 'react-router-dom';
import { ClubCard } from './ClubCard';
import { VoteCounter } from './VoteCounter';
import { useVoting } from '../../hooks/useVoting';

/**
 * Main voting arena component.
 * Displays two clubs side by side for comparison voting.
 */
export function VoteArena() {
  const { clubs, loading, error, totalWins, lastVoteResult, vote, skip } = useVoting();

  const handleVote = async (club) => {
    await vote(club);
  };

  if (error) {
    return (
      <div className="text-center py-12">
        <p className="text-red-600 mb-4">{error}</p>
        <button
          onClick={() => window.location.reload()}
          className="px-4 py-2 bg-berkeley-blue text-white rounded-lg hover:bg-berkeley-blue/90"
        >
          Try Again
        </button>
      </div>
    );
  }

  return (
    <div className="max-w-4xl w-full h-full px-2 sm:px-4 flex flex-col items-center justify-between py-4">
      <div className="flex-[0.6]" />

      <div className="flex flex-col items-center">
        <div className="text-center mb-2 sm:mb-8">
          <h1 className="text-xl sm:text-3xl font-bold text-gray-900">
            which club is better?
          </h1>
        </div>

        {loading ? (
          <div className="flex justify-center items-center py-10">
            <div className="animate-spin rounded-full h-8 w-8 border-4 border-berkeley-blue border-t-transparent"></div>
          </div>
        ) : (
          <div className="grid grid-cols-2 gap-2 sm:gap-6 w-full">
            {clubs.map((club) => (
              <ClubCard
                key={club.id}
                club={club}
                onVote={handleVote}
                disabled={loading}
              />
            ))}
          </div>
        )}
      </div>

      <div className="flex-1 flex flex-col justify-end">
        {!loading && (
          <div className="flex flex-col items-center gap-2 sm:gap-4 pb-2">
            <Link
              to="/rankings"
              className="px-3 sm:px-6 py-1.5 sm:py-2 bg-berkeley-gold font-semibold rounded-lg hover:bg-berkeley-gold-light transition-colors text-xs sm:text-base text-[#003262]"
            >
              rankings
            </Link>

            <VoteCounter count={totalWins} />
          </div>
        )}
      </div>

      {/* Turnstile container - positioned off-screen */}
      <div id="turnstile-container" className="fixed -left-[9999px]"></div>
    </div>
  );
}
