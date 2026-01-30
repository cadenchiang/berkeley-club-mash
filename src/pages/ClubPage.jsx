import { Link, useParams } from 'react-router-dom';
import { useClub } from '../hooks/useClubs';
import { ClubStats } from '../components/club/ClubStats';
import { CommentList } from '../components/comments/CommentList';

/**
 * Club detail page component.
 * Displays club information, stats, and comments.
 */
export function ClubPage() {
  const { id } = useParams();
  const { club, loading, error, refetch } = useClub(id);

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

  if (error || !club) {
    return (
      <div className="max-w-4xl mx-auto px-4 py-8 text-center">
        <p className="text-red-600 mb-4">{error || 'Club not found.'}</p>
        <Link
          to="/rankings"
          className="text-berkeley-blue hover:underline"
        >
          Back to Rankings
        </Link>
      </div>
    );
  }

  return (
    <div className="max-w-4xl mx-auto px-3 sm:px-4 py-4 sm:py-8 h-full overflow-auto w-full">
      <Link
        to="/rankings"
        className="inline-flex items-center text-gray-500 hover:text-berkeley-blue mb-3 sm:mb-6 text-sm"
      >
        <svg className="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
        </svg>
        back
      </Link>

      <div className="bg-white rounded-xl shadow-lg p-4 sm:p-6 mb-4 sm:mb-8">
        <div className="flex flex-col sm:flex-row items-center sm:items-start gap-3 sm:gap-6 mb-4 sm:mb-6">
          {club.image_url ? (
            <img
              src={club.image_url}
              alt={club.name}
              width={96}
              height={96}
              loading="eager"
              decoding="sync"
              fetchpriority="high"
              className="w-16 h-16 sm:w-24 sm:h-24 rounded-xl object-contain bg-gray-100 p-2"
            />
          ) : (
            <div className="w-16 h-16 sm:w-24 sm:h-24 rounded-xl bg-berkeley-blue/10 flex items-center justify-center">
              <span className="text-2xl sm:text-4xl">🏛️</span>
            </div>
          )}

          <div className="flex-1 text-center sm:text-left">
            <div className="flex flex-col sm:flex-row items-center gap-1 sm:gap-3 mb-2">
              <h1 className="text-lg sm:text-2xl font-bold text-gray-900">{club.name}</h1>
              <span className={`
                px-2 py-0.5 rounded-full text-[10px] sm:text-xs font-medium
                ${categoryColors[club.category] || categoryColors.other}
              `}>
                {club.category}
              </span>
              <button
                onClick={refetch}
                className="p-1 text-gray-400 hover:text-berkeley-blue transition-colors"
                title="Refresh stats"
              >
                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                </svg>
              </button>
            </div>

            <p className="text-gray-600 text-xs sm:text-base mb-2 sm:mb-4">
              {club.description || 'No description available.'}
            </p>

            {club.website && (
              <a
                href={club.website}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center text-berkeley-blue hover:underline text-xs sm:text-base"
              >
                <svg className="w-3 h-3 sm:w-4 sm:h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                </svg>
                website
              </a>
            )}
          </div>
        </div>

        <ClubStats club={club} />
      </div>

      <CommentList clubId={id} />
    </div>
  );
}
