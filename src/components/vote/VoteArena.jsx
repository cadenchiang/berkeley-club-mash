import { useState } from 'react';
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
  const [votedClub, setVotedClub] = useState(null);
  const [showingResult, setShowingResult] = useState(false);

  const handleVote = async (club) => {
    setVotedClub(club);
    setShowingResult(true);

    // Show result for 1 second before voting
    setTimeout(async () => {
      setShowingResult(false);
      setVotedClub(null);
      await vote(club);
    }, 1000);
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
        ) : showingResult && votedClub ? (
          <div className="flex flex-col items-center justify-center py-10">
            <div className="bg-white rounded-xl shadow-lg p-6 text-center">
              <div className="text-lg font-bold text-gray-900 mb-3">{votedClub.name}</div>
              <div className="flex gap-6">
                <div>
                  <div className="text-2xl font-bold text-berkeley-blue">{votedClub.wins}</div>
                  <div className="text-xs text-gray-500">wins</div>
                </div>
                <div>
                  <div className="text-2xl font-bold text-green-600">
                    {votedClub.total_votes > 0
                      ? ((votedClub.wins / votedClub.total_votes) * 100).toFixed(1) + '%'
                      : 'N/A'}
                  </div>
                  <div className="text-xs text-gray-500">win rate</div>
                </div>
              </div>
            </div>
          </div>
        ) : (
          <div className="grid grid-cols-2 gap-2 sm:gap-6 w-full">
            {clubs.map((club) => (
              <ClubCard
                key={club.id}
                club={club}
                onVote={handleVote}
                disabled={loading || showingResult}
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
              className="px-3 sm:px-6 py-1.5 sm:py-2 bg-berkeley-gold text-berkeley-blue font-semibold rounded-lg hover:bg-berkeley-gold-light transition-colors text-xs sm:text-base"
            >
              rankings
            </Link>

            <VoteCounter count={todayVotes} />
          </div>
        )}
      </div>
    </div>
  );
}
