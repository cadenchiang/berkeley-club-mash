import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';

/**
 * Hook for fetching and filtering clubs with comment counts.
 * Uses server-side function for efficient comment counting.
 * @param {{ category?: string, search?: string }} options - Filter options.
 * @returns {{ clubs: array, loading: boolean, error: string, refetch: function }}
 */
export function useClubs({ category = '', search = '' } = {}) {
  const [allClubs, setAllClubs] = useState([]);
  const [clubs, setClubs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Fetch all clubs once with ranks assigned
  const fetchAllClubs = useCallback(async () => {
    setLoading(true);
    setError(null);

    try {
      const { data, error: fetchError } = await supabase.rpc('get_clubs_with_comments', {
        p_category: null,
        p_search: null,
      });

      if (fetchError) throw fetchError;

      // Assign global rank to each club (data is already sorted by ELO)
      const rankedData = (data || []).map((club, index) => ({
        ...club,
        rank: index + 1,
      }));

      // Preload first 15 club images for instant rendering
      rankedData.slice(0, 15).forEach((club) => {
        if (club.image_url) {
          const img = new Image();
          img.src = club.image_url;
        }
      });

      setAllClubs(rankedData);
    } catch (err) {
      console.error('Error fetching clubs:', err);
      setError('Failed to load clubs. Please try again.');
    } finally {
      setLoading(false);
    }
  }, []);

  // Filter clubs client-side based on category and search
  useEffect(() => {
    let filtered = allClubs;

    if (category && category !== 'all') {
      filtered = filtered.filter((club) => club.category === category);
    }

    if (search) {
      const searchLower = search.toLowerCase();
      filtered = filtered.filter((club) =>
        club.name.toLowerCase().includes(searchLower)
      );
    }

    setClubs(filtered);
  }, [allClubs, category, search]);

  // Initial fetch
  useEffect(() => {
    fetchAllClubs();
  }, [fetchAllClubs]);

  return {
    clubs,
    loading,
    error,
    refetch: fetchAllClubs,
  };
}

/**
 * Hook for fetching a single club by ID.
 * @param {string} clubId - The club's UUID.
 * @returns {{ club: object, loading: boolean, error: string, refetch: function }}
 */
export function useClub(clubId) {
  const [club, setClub] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const fetchClub = useCallback(async () => {
    if (!clubId) {
      setLoading(false);
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const { data, error: fetchError } = await supabase
        .from('clubs')
        .select('*')
        .eq('id', clubId)
        .single();

      if (fetchError) throw fetchError;

      setClub(data);
    } catch (err) {
      console.error('Error fetching club:', err);
      setError('Failed to load club. Please try again.');
    } finally {
      setLoading(false);
    }
  }, [clubId]);

  useEffect(() => {
    fetchClub();
  }, [fetchClub]);

  return { club, loading, error, refetch: fetchClub };
}
