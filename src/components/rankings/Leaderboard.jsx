import { Link } from 'react-router-dom';

/**
 * Leaderboard component.
 * Displays ranked list of clubs with comment counts.
 * @param {{ clubs: array, loading: boolean }} props
 */
export function Leaderboard({ clubs, loading }) {
  const categoryColors = {
    tech: 'bg-blue-100 text-blue-800',
    consulting: 'bg-purple-100 text-purple-800',
    finance: 'bg-green-100 text-green-800',
    cultural: 'bg-orange-100 text-orange-800',
    social: 'bg-pink-100 text-pink-800',
    other: 'bg-gray-100 text-gray-800',
  };

  if (loading) {
    return (
      <div className="flex justify-center items-center py-20">
        <div className="animate-spin rounded-full h-12 w-12 border-4 border-berkeley-blue border-t-transparent"></div>
      </div>
    );
  }

  if (clubs.length === 0) {
    return (
      <div className="text-center py-12 text-gray-500">
        No clubs found matching your criteria.
      </div>
    );
  }

  return (
    <div className="bg-white rounded-xl shadow-lg overflow-hidden">
      <table className="w-full">
        <thead className="bg-berkeley-blue text-white">
          <tr>
            <th className="px-2 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-semibold w-12 sm:w-16">#</th>
            <th className="px-2 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-semibold">Club</th>
            <th className="px-2 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-semibold hidden sm:table-cell">Category</th>
            <th className="px-2 sm:px-4 py-2 sm:py-3 text-right text-xs sm:text-sm font-semibold">ELO</th>
            <th className="px-2 sm:px-4 py-2 sm:py-3 text-right text-xs sm:text-sm font-semibold hidden sm:table-cell">Votes</th>
            <th className="px-2 sm:px-4 py-2 sm:py-3 text-right text-xs sm:text-sm font-semibold hidden md:table-cell">Win Rate</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-gray-100">
          {clubs.map((club, index) => {
            const winRate = club.total_votes > 0
              ? ((club.wins / club.total_votes) * 100).toFixed(1) + '%'
              : 'N/A';

            return (
              <tr
                key={club.id}
                className="hover:bg-gray-50 transition-colors"
              >
                <td className="px-2 sm:px-4 py-3 sm:py-4">
                  <span className={`
                    inline-flex items-center justify-center w-6 h-6 sm:w-8 sm:h-8 rounded-full font-bold text-xs sm:text-sm
                    ${index === 0 ? 'bg-yellow-100 text-yellow-800' : ''}
                    ${index === 1 ? 'bg-gray-200 text-gray-700' : ''}
                    ${index === 2 ? 'bg-orange-100 text-orange-800' : ''}
                    ${index > 2 ? 'bg-gray-100 text-gray-600' : ''}
                  `}>
                    {index + 1}
                  </span>
                </td>
                <td className="px-2 sm:px-4 py-3 sm:py-4">
                  <Link
                    to={`/club/${club.id}`}
                    className="flex items-center gap-2 sm:gap-3 font-medium text-gray-900 hover:text-berkeley-blue transition-colors"
                  >
                    {club.image_url ? (
                      <img
                        src={club.image_url}
                        alt={club.name}
                        loading="lazy"
                        decoding="async"
                        className="w-8 h-8 sm:w-10 sm:h-10 rounded-lg object-contain flex-shrink-0 bg-gray-100 p-1"
                      />
                    ) : (
                      <div className="w-8 h-8 sm:w-10 sm:h-10 rounded-lg bg-berkeley-blue/10 flex items-center justify-center flex-shrink-0">
                        <span className="text-sm sm:text-lg">🏛️</span>
                      </div>
                    )}
                    <span className="text-sm sm:text-base">{club.name}</span>
                    {(club.comment_count || 0) > 0 && (
                      <span className="text-xs text-gray-300 ml-1">{club.comment_count}</span>
                    )}
                  </Link>
                </td>
                <td className="px-2 sm:px-4 py-3 sm:py-4 hidden sm:table-cell">
                  <span className={`
                    inline-block px-2 py-1 rounded-full text-xs font-medium
                    ${categoryColors[club.category] || categoryColors.other}
                  `}>
                    {club.category}
                  </span>
                </td>
                <td className="px-2 sm:px-4 py-3 sm:py-4 text-right">
                  <span className="font-bold text-berkeley-blue text-sm sm:text-base">{club.elo_rating}</span>
                </td>
                <td className="px-2 sm:px-4 py-3 sm:py-4 text-right hidden sm:table-cell">
                  <span className="text-gray-600 text-sm sm:text-base">{club.total_votes}</span>
                </td>
                <td className="px-2 sm:px-4 py-3 sm:py-4 text-right hidden md:table-cell">
                  <span className="text-gray-600">{winRate}</span>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
