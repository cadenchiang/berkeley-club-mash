import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useSession } from './useSession';

/**
 * Hook for managing the voting system.
 * Uses server-side ELO calculation for security.
 * Includes reCAPTCHA verification after every 20 votes.
 * @returns {{ clubs: array, loading: boolean, error: string, totalWins: number, lastVoteResult: object, vote: function, skip: function, needsCaptcha: boolean }}
 */
const MATCHUP_KEY = 'clubmash_current_matchup';
const RECAPTCHA_SITE_KEY = '6LcExample123456789012345678901234567890'; // Replace with your reCAPTCHA v3 site key

export function useVoting() {
  const [clubs, setClubs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [totalWins, setTotalWins] = useState(0);
  const [lastVoteResult, setLastVoteResult] = useState(null);
  const [needsCaptcha, setNeedsCaptcha] = useState(false);
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

      // Preload images for instant rendering
      data.forEach((club) => {
        if (club.image_url) {
          const img = new Image();
          img.src = club.image_url;
        }
      });

      setClubs(data);
    } catch (err) {
      console.error('Error fetching clubs:', err);
      setError('Failed to load clubs. Please try again.');
    } finally {
      setLoading(false);
    }
  }, []);

  const fetchTotalWins = useCallback(async () => {
    try {
      const { data, error: countError } = await supabase.rpc('get_total_vote_count');
      if (countError) throw countError;
      setTotalWins(data || 0);
    } catch (err) {
      console.error('Error fetching total wins:', err);
    }
  }, []);

  useEffect(() => {
    fetchRandomPair();
    fetchTotalWins();
  }, [fetchRandomPair, fetchTotalWins]);

  /**
   * Get reCAPTCHA token for verification.
   * @returns {Promise<string|null>} The reCAPTCHA token or null if unavailable.
   */
  const getRecaptchaToken = useCallback(async () => {
    if (typeof window === 'undefined' || !window.grecaptcha) {
      return null;
    }
    try {
      await new Promise((resolve) => window.grecaptcha.ready(resolve));
      const token = await window.grecaptcha.execute(RECAPTCHA_SITE_KEY, { action: 'vote' });
      return token;
    } catch (err) {
      console.error('reCAPTCHA error:', err);
      return null;
    }
  }, []);

  /**
   * Record a vote using server-side ELO calculation.
   * Includes reCAPTCHA verification after every 20 votes.
   * @param {object} winner - The winning club object.
   * @param {string} recaptchaToken - Optional reCAPTCHA token for verification.
   */
  const vote = useCallback(async (winner, recaptchaToken = null) => {
    if (!sessionId || clubs.length < 2) return;

    setLoading(true);
    setError(null);
    setNeedsCaptcha(false);

    try {
      const { data, error: voteError } = await supabase.rpc('record_vote', {
        p_club_a_id: clubs[0].id,
        p_club_b_id: clubs[1].id,
        p_winner_id: winner.id,
        p_session_id: sessionId,
        p_fingerprint: fingerprint,
        p_recaptcha_token: recaptchaToken,
      });

      if (voteError) throw voteError;

      if (!data.success) {
        if (data.error === 'captcha_required') {
          // Need to get reCAPTCHA token and retry
          setNeedsCaptcha(true);
          const token = await getRecaptchaToken();
          if (token) {
            // Retry with token
            return vote(winner, token);
          } else {
            setError('Please complete verification to continue voting.');
            setLoading(false);
            return null;
          }
        } else if (data.error === 'rate_limit_exceeded') {
          setError('Too many votes! Take a break and come back later.');
        } else if (data.error === 'suspicious_activity') {
          setError('Suspicious activity detected. Please try again later.');
        } else {
          setError(data.message || 'Failed to record vote.');
        }
        setLoading(false);
        return null;
      }

      setLastVoteResult(data);
      setTotalWins((prev) => prev + 1);
      // Clear stored matchup and get new one
      localStorage.removeItem(MATCHUP_KEY);
      await fetchRandomPair(true);
      return data;
    } catch (err) {
      console.error('Error recording vote:', err);
      setError('Failed to record vote. Please try again.');
      setLoading(false);
      return null;
    }
  }, [sessionId, fingerprint, clubs, fetchRandomPair, getRecaptchaToken]);

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
    totalWins,
    lastVoteResult,
    vote,
    skip,
    needsCaptcha,
  };
}
