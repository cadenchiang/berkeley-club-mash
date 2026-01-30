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
  const { clubs, loading, error } = useClubs({ category, search });

  return (
    <div className="max-w-4xl mx-auto px-3 sm:px-4 py-4 sm:py-8">
      <div className="mb-4 sm:mb-8">
        <h1 className="text-2xl sm:text-3xl font-bold text-gray-900 mb-1 sm:mb-2">Club Rankings</h1>
        <p className="text-gray-600 text-sm sm:text-base">
          See how Berkeley clubs stack up based on community votes.
        </p>
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
