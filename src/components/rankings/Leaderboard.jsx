import { Link } from 'react-router-dom';

/**
 * Formats a number with k suffix for thousands.
 * @param {number} num - Number to format.
 * @returns {string} Formatted string (e.g., "1.2k").
 */
function formatNumber(num) {
  if (num >= 1000) {
    return (num / 1000).toFixed(1).replace(/\.0$/, '') + 'k';
  }
  return num.toString();
}

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
    entrepreneurship: 'bg-yellow-100 text-yellow-800',
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
            <th className="px-2 sm:px-4 py-2 sm:py-3 text-center text-xs sm:text-sm font-semibold">
              <svg className="w-4 h-4 sm:w-5 sm:h-5 inline-block" fill="currentColor" viewBox="0 0 24 24">
                <path d="M19 5h-2V3H7v2H5c-1.1 0-2 .9-2 2v1c0 2.55 1.92 4.63 4.39 4.94.63 1.5 1.98 2.63 3.61 2.96V19H7v2h10v-2h-4v-3.1c1.63-.33 2.98-1.46 3.61-2.96C19.08 12.63 21 10.55 21 8V7c0-1.1-.9-2-2-2zM5 8V7h2v3.82C5.84 10.4 5 9.3 5 8zm14 0c0 1.3-.84 2.4-2 2.82V7h2v1z"/>
              </svg>
            </th>
            <th className="px-2 sm:px-4 py-2 sm:py-3 text-right text-xs sm:text-sm font-semibold">Wins</th>
            <th className="px-2 sm:px-4 py-2 sm:py-3 text-right text-xs sm:text-sm font-semibold hidden md:table-cell">Win Rate</th>
          </tr>
        </thead>
        <tbody>
          {clubs.map((club, index) => {
            const winRate = club.total_votes > 0
              ? ((club.wins / club.total_votes) * 100).toFixed(1) + '%'
              : 'N/A';

            return (
              <tr
                key={club.id}
                className="hover:bg-gray-50 transition-colors animate-fade-in"
                style={{ animationDelay: `${index * 30}ms` }}
              >
                <td className="px-2 sm:px-4 py-3 sm:py-4">
                  <span className={`
                    inline-flex items-center justify-center w-6 h-6 sm:w-8 sm:h-8 rounded-full font-bold text-xs sm:text-sm
                    ${club.rank === 1 ? 'bg-yellow-100 text-yellow-800' : ''}
                    ${club.rank === 2 ? 'bg-gray-200 text-gray-700' : ''}
                    ${club.rank === 3 ? 'bg-orange-100 text-orange-800' : ''}
                    ${club.rank > 3 ? 'bg-gray-100 text-gray-600' : ''}
                  `}>
                    {club.rank}
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
                        width={40}
                        height={40}
                        loading={index < 15 ? "eager" : "lazy"}
                        decoding={index < 15 ? "sync" : "async"}
                        fetchpriority={index < 5 ? "high" : "auto"}
                        className="w-8 h-8 sm:w-10 sm:h-10 rounded-lg object-contain flex-shrink-0 bg-gray-100 p-1"
                      />
                    ) : (
                      <div className="w-8 h-8 sm:w-10 sm:h-10 rounded-lg bg-berkeley-blue/10 flex items-center justify-center flex-shrink-0">
                        <span className="text-sm sm:text-lg">🏛️</span>
                      </div>
                    )}
                    <span className="text-sm sm:text-base">{club.name}</span>
                    {(club.comment_count || 0) > 0 && (
                      <span className="flex items-center gap-0.5 text-xs text-gray-300 ml-1">
                        <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                        </svg>
                        {club.comment_count}
                      </span>
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
                <td className="px-2 sm:px-4 py-3 sm:py-4 text-center">
                  <span className="font-bold text-berkeley-blue text-sm sm:text-base">{club.elo_rating}</span>
                </td>
                <td className="px-2 sm:px-4 py-3 sm:py-4 text-right">
                  <span className="text-gray-600 text-xs sm:text-base">{formatNumber(club.wins)}</span>
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
