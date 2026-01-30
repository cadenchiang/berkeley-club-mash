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
  const { clubs, loading, error, totalWins, lastVoteResult, vote, skip } = useVoting();
  const [voteResult, setVoteResult] = useState(null);
  const [showingResult, setShowingResult] = useState(false);

  const handleVote = async (club) => {
    const loser = clubs.find(c => c.id !== club.id);
    setVoteResult({ winner: club, loser });
    setShowingResult(true);

    // Record vote and get ELO changes
    const result = await vote(club);
    if (result?.winner_change !== undefined) {
      setVoteResult(prev => ({
        ...prev,
        winnerChange: result.winner_change,
        loserChange: result.loser_change
      }));
    }

    // Show result for 1.5 seconds then reset
    setTimeout(() => {
      setShowingResult(false);
      setVoteResult(null);
    }, 1500);
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
        ) : showingResult && voteResult ? (
          <div className="grid grid-cols-2 gap-2 sm:gap-6 w-full">
            {/* Winner */}
            <div className="relative bg-white rounded-xl shadow-lg p-4 sm:p-6 text-center border-2 border-green-400">
              <div className="absolute -top-3 left-1/2 -translate-x-1/2 bg-green-500 text-white px-3 py-1 rounded-full text-xs font-bold">
                WINNER
              </div>
              {voteResult.winner.image_url && (
                <img
                  src={voteResult.winner.image_url}
                  alt={voteResult.winner.name}
                  className="w-20 h-20 sm:w-28 sm:h-28 rounded-xl object-contain mx-auto mb-2 bg-gray-100 p-2"
                />
              )}
              <div className="text-sm sm:text-lg font-bold text-gray-900 mb-2">{voteResult.winner.name}</div>
              {voteResult.winnerChange !== undefined && (
                <div className="text-2xl sm:text-3xl font-bold text-green-500 animate-bounce">
                  +{voteResult.winnerChange} 🏆
                </div>
              )}
            </div>
            {/* Loser */}
            <div className="relative bg-white rounded-xl shadow-lg p-4 sm:p-6 text-center border-2 border-red-300 opacity-75">
              {voteResult.loser.image_url && (
                <img
                  src={voteResult.loser.image_url}
                  alt={voteResult.loser.name}
                  className="w-20 h-20 sm:w-28 sm:h-28 rounded-xl object-contain mx-auto mb-2 bg-gray-100 p-2 grayscale"
                />
              )}
              <div className="text-sm sm:text-lg font-bold text-gray-500 mb-2">{voteResult.loser.name}</div>
              {voteResult.loserChange !== undefined && (
                <div className="text-2xl sm:text-3xl font-bold text-red-500">
                  {voteResult.loserChange} 🏆
                </div>
              )}
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

            <VoteCounter count={totalWins} />
          </div>
        )}
      </div>
    </div>
  );
}
