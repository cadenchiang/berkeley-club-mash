/**
 * Club statistics component.
 * Displays ELO rating, win rate, and total votes.
 * @param {{ club: object }} props
 */
export function ClubStats({ club }) {
  const winRate = club.total_votes > 0
    ? ((club.wins / club.total_votes) * 100).toFixed(1) + '%'
    : 'N/A';

  return (
    <div className="grid grid-cols-3 gap-2 sm:gap-4">
      <div className="bg-gray-50 rounded-lg p-2 sm:p-4 text-center">
        <div className="text-lg sm:text-3xl font-bold text-berkeley-blue">{club.elo_rating}</div>
        <div className="text-[10px] sm:text-sm text-gray-500">elo</div>
      </div>
      <div className="bg-gray-50 rounded-lg p-2 sm:p-4 text-center">
        <div className="text-lg sm:text-3xl font-bold text-green-600">{winRate}</div>
        <div className="text-[10px] sm:text-sm text-gray-500">win rate</div>
      </div>
      <div className="bg-gray-50 rounded-lg p-2 sm:p-4 text-center">
        <div className="text-lg sm:text-3xl font-bold text-gray-700">{club.total_votes}</div>
        <div className="text-[10px] sm:text-sm text-gray-500">votes</div>
      </div>
    </div>
  );
}
