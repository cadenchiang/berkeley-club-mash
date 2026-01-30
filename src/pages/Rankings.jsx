import { useState } from 'react';
import { Leaderboard } from '../components/rankings/Leaderboard';
import { CategoryFilter } from '../components/rankings/CategoryFilter';
import { useClubs } from '../hooks/useClubs';

/**
 * Rankings page component.
 * Displays the club leaderboard with filtering options.
 */
export function Rankings() {
  const [category, setCategory] = useState('all');
  const [search, setSearch] = useState('');
  const { clubs, loading, error, refetch } = useClubs({ category, search });

  return (
    <div className="max-w-4xl mx-auto px-3 sm:px-4 py-4 sm:py-8 h-full overflow-auto">
      <div className="mb-4 sm:mb-8 flex items-start justify-between">
        <div>
          <h1 className="text-2xl sm:text-3xl font-bold text-gray-900 mb-1 sm:mb-2">Club Rankings</h1>
          <p className="text-gray-600 text-sm sm:text-base">
            See how Berkeley clubs stack up based on community votes.
          </p>
        </div>
        <button
          onClick={refetch}
          disabled={loading}
          className="p-2 text-gray-500 hover:text-berkeley-blue hover:bg-gray-100 rounded-lg transition-colors disabled:opacity-50"
          title="Refresh rankings"
        >
          <svg className={`w-5 h-5 ${loading ? 'animate-spin' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
          </svg>
        </button>
      </div>

      <div className="mb-4 sm:mb-6 space-y-3 sm:space-y-4">
        <div className="flex flex-col sm:flex-row gap-3 sm:gap-4">
          <input
            type="text"
            placeholder="Search clubs..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="flex-1 px-3 sm:px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-berkeley-blue/50 focus:border-berkeley-blue text-sm sm:text-base"
          />
        </div>

        <CategoryFilter value={category} onChange={setCategory} />
      </div>

      {error ? (
        <div className="text-center py-12">
          <p className="text-red-600">{error}</p>
        </div>
      ) : (
        <Leaderboard clubs={clubs} loading={loading} />
      )}
    </div>
  );
}
