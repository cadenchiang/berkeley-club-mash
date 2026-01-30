/**
 * Club statistics component.
 * Displays ELO rating, win rate, and total votes.
 * @param {{ club: object }} props
 */
export function ClubStats({ club }) {
  const winRate = club.total_votes > 0
    ? ((club.wins / club.total_votes) * 100).toFixed(1)
    : '0.0';

  return (
    <div className="grid grid-cols-3 gap-4">
      <div className="bg-white rounded-lg p-4 text-center shadow-sm border border-gray-100">
        <div className="text-3xl font-bold text-berkeley-blue">{club.elo_rating}</div>
        <div className="text-sm text-gray-500">ELO Rating</div>
      </div>
      <div className="bg-white rounded-lg p-4 text-center shadow-sm border border-gray-100">
        <div className="text-3xl font-bold text-green-600">{winRate}%</div>
        <div className="text-sm text-gray-500">Win Rate</div>
      </div>
      <div className="bg-white rounded-lg p-4 text-center shadow-sm border border-gray-100">
        <div className="text-3xl font-bold text-gray-700">{club.total_votes}</div>
        <div className="text-sm text-gray-500">Total Votes</div>
      </div>
    </div>
  );
}
