import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';

/**
 * Hook for fetching and filtering clubs with comment counts.
 * Uses server-side function for efficient comment counting.
 * @param {{ category?: string, search?: string }} options - Filter options.
 * @returns {{ clubs: array, loading: boolean, error: string, refetch: function }}
 */
export function useClubs({ category = '', search = '' } = {}) {
  const [clubs, setClubs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const fetchClubs = useCallback(async () => {
    setLoading(true);
    setError(null);

    try {
      const { data, error: fetchError } = await supabase.rpc('get_clubs_with_comments', {
        p_category: category || null,
        p_search: search || null,
      });

      if (fetchError) throw fetchError;

      // Preload first 15 club images for instant rendering
      (data || []).slice(0, 15).forEach((club) => {
        if (club.image_url) {
          const img = new Image();
          img.src = club.image_url;
        }
      });

      setClubs(data || []);
    } catch (err) {
      console.error('Error fetching clubs:', err);
      setError('Failed to load clubs. Please try again.');
    } finally {
      setLoading(false);
    }
  }, [category, search]);

  useEffect(() => {
    fetchClubs();
  }, [fetchClubs]);

  return {
    clubs,
    loading,
    error,
    refetch: fetchClubs,
  };
}

/**
 * Hook for fetching a single club by ID.
 * @param {string} clubId - The club's UUID.
 * @returns {{ club: object, loading: boolean, error: string }}
 */
export function useClub(clubId) {
  const [club, setClub] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (!clubId) {
      setLoading(false);
      return;
    }

    const fetchClub = async () => {
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
    };

    fetchClub();
  }, [clubId]);

  return { club, loading, error };
}
