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
  const { club, loading, error } = useClub(id);

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
    <div className="max-w-4xl mx-auto px-4 py-8">
      <Link
        to="/rankings"
        className="inline-flex items-center text-gray-600 hover:text-berkeley-blue mb-6"
      >
        <svg className="w-5 h-5 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
        </svg>
        Back to Rankings
      </Link>

      <div className="bg-white rounded-xl shadow-lg p-6 mb-8">
        <div className="flex items-start gap-6 mb-6">
          {club.image_url ? (
            <img
              src={club.image_url}
              alt={club.name}
              className="w-24 h-24 rounded-xl object-cover"
            />
          ) : (
            <div className="w-24 h-24 rounded-xl bg-berkeley-blue/10 flex items-center justify-center">
              <span className="text-4xl">🏛️</span>
            </div>
          )}

          <div className="flex-1">
            <div className="flex items-center gap-3 mb-2">
              <h1 className="text-2xl font-bold text-gray-900">{club.name}</h1>
              <span className={`
                px-2 py-1 rounded-full text-xs font-medium
                ${categoryColors[club.category] || categoryColors.other}
              `}>
                {club.category}
              </span>
            </div>

            <p className="text-gray-600 mb-4">
              {club.description || 'No description available.'}
            </p>

            {club.website && (
              <a
                href={club.website}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center text-berkeley-blue hover:underline"
              >
                <svg className="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                </svg>
                Visit Website
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
