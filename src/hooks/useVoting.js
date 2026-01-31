import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useSession } from './useSession';

/**
 * Hook for managing the voting system.
 * Optimized for speed with pre-fetching.
 */
const MATCHUP_KEY = 'clubmash_current_matchup';

export function useVoting() {
  const [clubs, setClubs] = useState([]);
  const [nextClubs, setNextClubs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [totalWins, setTotalWins] = useState(0);
  const [lastVoteResult, setLastVoteResult] = useState(null);
  const { sessionId, fingerprint } = useSession();

  const fetchPair = useCallback(async () => {
    const { data, error } = await supabase.rpc('get_random_pair');
    if (error || !data || data.length < 2) return null;

    data.forEach((club) => {
      if (club.image_url) {
        const img = new Image();
        img.src = club.image_url;
      }
    });

    return data;
  }, []);

  const prefetchNextPair = useCallback(async () => {
    const pair = await fetchPair();
    if (pair) setNextClubs(pair);
  }, [fetchPair]);

  useEffect(() => {
    const init = async () => {
      setLoading(true);

      let pair = null;
      try {
        const stored = localStorage.getItem(MATCHUP_KEY);
        if (stored) {
          const parsed = JSON.parse(stored);
          if (parsed.clubs && parsed.clubs.length >= 2) {
            pair = parsed.clubs;
          }
        }
      } catch {}

      const countResult = await supabase.rpc('get_total_vote_count');
      if (countResult.data) setTotalWins(countResult.data);

      if (!pair) {
        pair = await fetchPair();
        if (pair) {
          localStorage.setItem(MATCHUP_KEY, JSON.stringify({ clubs: pair }));
        }
      }

      if (pair) setClubs(pair);
      setLoading(false);

      prefetchNextPair();
    };

    init();
  }, [fetchPair, prefetchNextPair]);

  const vote = useCallback(async (winner) => {
    if (!sessionId || clubs.length < 2) return;

    const currentClubs = clubs;

    // Brief delay for natural feel
    setLoading(true);
    await new Promise((resolve) => setTimeout(resolve, 300));

    if (nextClubs.length >= 2) {
      setClubs(nextClubs);
      localStorage.setItem(MATCHUP_KEY, JSON.stringify({ clubs: nextClubs }));
      setNextClubs([]);
      setLoading(false);
    }

    setTotalWins((prev) => prev + 1);

    // Fire vote request
    fetch('/api/vote', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        p_club_a_id: currentClubs[0].id,
        p_club_b_id: currentClubs[1].id,
        p_winner_id: winner.id,
        p_session_id: sessionId,
        p_fingerprint: fingerprint,
      }),
    }).then(async (res) => {
      const data = await res.json();
      if (!res.ok || !data.success) {
        if (data.error === 'rate_limit') {
          setError('Too many votes! Take a break.');
        }
        setTotalWins((prev) => prev - 1);
      } else {
        setLastVoteResult(data);
      }
    }).catch(() => {
      setTotalWins((prev) => prev - 1);
    });

    prefetchNextPair();

    if (nextClubs.length < 2) {
      const pair = await fetchPair();
      if (pair) {
        setClubs(pair);
        localStorage.setItem(MATCHUP_KEY, JSON.stringify({ clubs: pair }));
      }
      setLoading(false);
    }

    return true;
  }, [sessionId, fingerprint, clubs, nextClubs, fetchPair, prefetchNextPair]);

  const skip = useCallback(async () => {
    if (!sessionId || clubs.length < 2) return;

    if (nextClubs.length >= 2) {
      setClubs(nextClubs);
      localStorage.setItem(MATCHUP_KEY, JSON.stringify({ clubs: nextClubs }));
      setNextClubs([]);
      prefetchNextPair();
    } else {
      setLoading(true);
      const pair = await fetchPair();
      if (pair) {
        setClubs(pair);
        localStorage.setItem(MATCHUP_KEY, JSON.stringify({ clubs: pair }));
      }
      setLoading(false);
    }
  }, [sessionId, clubs, nextClubs, fetchPair, prefetchNextPair]);

  return {
    clubs,
    loading,
    error,
    totalWins,
    lastVoteResult,
    vote,
    skip,
  };
}
