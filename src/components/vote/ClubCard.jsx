/**
 * Club card component for voting display.
 * Shows club info and handles click to vote.
 * @param {{ club: object, onVote: function, disabled: boolean }} props
 */
export function ClubCard({ club, onVote, disabled }) {
  return (
    <button
      onClick={() => onVote(club)}
      disabled={disabled}
      className={`
        w-full p-4 sm:p-6 bg-white rounded-xl shadow-lg border-2 border-transparent
        transition-all duration-200 text-center
        ${disabled ? 'opacity-50 cursor-not-allowed' : 'hover:border-berkeley-gold hover:shadow-xl hover:-translate-y-1 cursor-pointer'}
      `}
    >
      <div className="flex flex-col h-full items-center">
        {club.image_url ? (
          <img
            src={club.image_url}
            alt={club.name}
            loading="eager"
            decoding="async"
            className="w-28 h-28 sm:w-44 sm:h-44 rounded-xl object-contain mb-3 sm:mb-4 bg-gray-100 p-2"
          />
        ) : (
          <div className="w-28 h-28 sm:w-44 sm:h-44 rounded-xl bg-berkeley-blue/10 flex items-center justify-center mb-3 sm:mb-4">
            <span className="text-5xl sm:text-7xl">🏛️</span>
          </div>
        )}

        <h3 className="text-lg sm:text-xl font-bold text-gray-900 mb-2 sm:mb-2 leading-tight line-clamp-2">{club.name}</h3>

        <p className="text-gray-500 text-[9px] sm:text-sm flex-1 line-clamp-3 sm:line-clamp-3 leading-tight">
          {club.description || 'No description available.'}
        </p>

      </div>
    </button>
  );
}
