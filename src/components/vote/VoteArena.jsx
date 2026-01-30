import { Link } from 'react-router-dom';
import { ClubCard } from './ClubCard';
import { VoteCounter } from './VoteCounter';
import { useVoting } from '../../hooks/useVoting';

/**
 * Main voting arena component.
 * Displays two clubs side by side for comparison voting.
 */
export function VoteArena() {
  const { clubs, loading, error, todayVotes, vote, skip } = useVoting();

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
    <div className="max-w-4xl w-full px-3 sm:px-4 flex flex-col items-center">
      <div className="text-center mb-4 sm:mb-8">
        <h1 className="text-2xl sm:text-3xl font-bold text-gray-900">
          Which club is better?
        </h1>
      </div>

      {loading ? (
        <div className="flex justify-center items-center py-20">
          <div className="animate-spin rounded-full h-12 w-12 border-4 border-berkeley-blue border-t-transparent"></div>
        </div>
      ) : (
        <>
          <div className="grid grid-cols-2 gap-3 sm:gap-6 mb-4 sm:mb-8 w-full">
            {clubs.map((club) => (
              <ClubCard
                key={club.id}
                club={club}
                onVote={vote}
                disabled={loading}
              />
            ))}
          </div>

          <div className="flex flex-col items-center gap-3 sm:gap-4">
            <div className="flex gap-3 sm:gap-4">
              <button
                onClick={skip}
                disabled={loading}
                className="px-4 sm:px-6 py-2 border border-gray-300 rounded-lg text-gray-600 hover:bg-gray-50 transition-colors disabled:opacity-50 text-sm sm:text-base"
              >
                Skip
              </button>
              <Link
                to="/rankings"
                className="px-4 sm:px-6 py-2 bg-berkeley-gold text-berkeley-blue font-semibold rounded-lg hover:bg-berkeley-gold-light transition-colors text-sm sm:text-base"
              >
                See Rankings
              </Link>
            </div>

            <VoteCounter count={todayVotes} />
          </div>
        </>
      )}
    </div>
  );
}
