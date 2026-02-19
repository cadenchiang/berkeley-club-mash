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
  const [showInfo, setShowInfo] = useState(false);
  const { clubs, loading, error, refetch } = useClubs({ category, search });

  return (
    <div className="max-w-4xl mx-auto px-3 sm:px-4 py-4 sm:py-8 h-full overflow-y-auto overflow-x-hidden">
      <div className="mb-4 sm:mb-8 flex items-start justify-between">
        <div>
          <div className="flex items-center gap-2 mb-1 sm:mb-2">
            <h1 className="text-2xl sm:text-3xl font-bold text-gray-900">Club Rankings</h1>
            <div className="relative">
              <button
                onClick={() => setShowInfo(!showInfo)}
                className="text-gray-400 hover:text-berkeley-blue transition-colors"
                title="How rankings work"
              >
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </button>
              <div
                className={`fixed inset-0 z-40 transition-opacity duration-200 ${showInfo ? 'opacity-100' : 'opacity-0 pointer-events-none'}`}
                onClick={() => setShowInfo(false)}
              />
              <div className={`
                absolute left-0 top-8 z-50 w-[min(288px,calc(100vw-2rem))] bg-white border border-gray-200 rounded-lg shadow-lg p-4 text-sm
                transition-all duration-200 origin-top-left
                ${showInfo ? 'opacity-100 scale-100' : 'opacity-0 scale-95 pointer-events-none'}
              `}>
                <p className="font-semibold text-gray-900 mb-2">How rankings work</p>
                <ul className="list-disc list-inside space-y-1 text-gray-600">
                  <li>Rankings use the ELO system (like chess)</li>
                  <li>Beating higher-ranked clubs earns more points</li>
                  <li>Losing to lower-ranked clubs costs more points</li>
                  <li>More votes = more accurate rankings</li>
                </ul>
              </div>
            </div>
          </div>
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
