import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useSession } from './useSession';

/**
 * Hook for managing the voting system.
 * Uses server-side ELO calculation for security.
 * Rate limited to 1000 votes per hour per session.
 * @returns {{ clubs: array, loading: boolean, error: string, todayVotes: number, lastVoteResult: object, vote: function, skip: function }}
 */
const MATCHUP_KEY = 'clubmash_current_matchup';

export function useVoting() {
  const [clubs, setClubs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [todayVotes, setTodayVotes] = useState(0);
  const [lastVoteResult, setLastVoteResult] = useState(null);
  const { sessionId, fingerprint } = useSession();

  const fetchRandomPair = useCallback(async (forceNew = false) => {
    setLoading(true);
    setError(null);

    // Check for stored matchup (prevents refresh abuse)
    if (!forceNew) {
      try {
        const stored = localStorage.getItem(MATCHUP_KEY);
        if (stored) {
          const parsed = JSON.parse(stored);
          // Check if matchup is less than 24 hours old
          if (parsed.timestamp && Date.now() - parsed.timestamp < 86400000) {
            setClubs(parsed.clubs);
            setLoading(false);
            return;
          }
        }
      } catch (e) {
        // Ignore parse errors
      }
    }

    try {
      const { data, error: fetchError } = await supabase.rpc('get_random_pair');

      if (fetchError) throw fetchError;

      if (!data || data.length < 2) {
        setError('Not enough clubs to compare. Please add more clubs.');
        return;
      }

      // Store the matchup to prevent refresh abuse
      localStorage.setItem(MATCHUP_KEY, JSON.stringify({
        clubs: data,
        timestamp: Date.now()
      }));

      setClubs(data);
    } catch (err) {
      console.error('Error fetching clubs:', err);
      setError('Failed to load clubs. Please try again.');
    } finally {
      setLoading(false);
    }
  }, []);

  const fetchTodayVotes = useCallback(async () => {
    try {
      const { data, error: countError } = await supabase.rpc('get_today_vote_count');
      if (countError) throw countError;
      setTodayVotes(data || 0);
    } catch (err) {
      console.error('Error fetching vote count:', err);
    }
  }, []);

  useEffect(() => {
    fetchRandomPair();
    fetchTodayVotes();
  }, [fetchRandomPair, fetchTodayVotes]);

  /**
   * Record a vote using server-side ELO calculation.
   * Prevents client-side manipulation and ensures atomic updates.
   * @param {object} winner - The winning club object.
   */
  const vote = useCallback(async (winner) => {
    if (!sessionId || clubs.length < 2) return;

    setLoading(true);
    setError(null);

    try {
      const { data, error: voteError } = await supabase.rpc('record_vote', {
        p_club_a_id: clubs[0].id,
        p_club_b_id: clubs[1].id,
        p_winner_id: winner.id,
        p_session_id: sessionId,
        p_fingerprint: fingerprint,
      });

      if (voteError) throw voteError;

      if (!data.success) {
        if (data.error === 'rate_limit_exceeded') {
          setError('Too many votes! Take a break and come back later.');
        } else {
          setError(data.message || 'Failed to record vote.');
        }
        setLoading(false);
        return;
      }

      setLastVoteResult(data);
      setTodayVotes((prev) => prev + 1);
      // Clear stored matchup and get new one
      localStorage.removeItem(MATCHUP_KEY);
      await fetchRandomPair(true);
    } catch (err) {
      console.error('Error recording vote:', err);
      setError('Failed to record vote. Please try again.');
      setLoading(false);
    }
  }, [sessionId, fingerprint, clubs, fetchRandomPair]);

  /**
   * Skip the current matchup without recording a vote.
   */
  const skip = useCallback(async () => {
    if (!sessionId || clubs.length < 2) return;

    try {
      await supabase.rpc('record_vote', {
        p_club_a_id: clubs[0].id,
        p_club_b_id: clubs[1].id,
        p_winner_id: null,
        p_session_id: sessionId,
        p_fingerprint: fingerprint,
      });
    } catch (err) {
      console.error('Error recording skip:', err);
    }

    fetchRandomPair();
  }, [sessionId, fingerprint, clubs, fetchRandomPair]);

  return {
    clubs,
    loading,
    error,
    todayVotes,
    lastVoteResult,
    vote,
    skip,
  };
}
