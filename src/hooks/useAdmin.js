import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';

/**
 * Hook for admin authentication and authorization.
 * @returns {{ user: object, isAdmin: boolean, loading: boolean, signIn: function, signOut: function }}
 */
export function useAdmin() {
  const [user, setUser] = useState(null);
  const [isAdmin, setIsAdmin] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setUser(session?.user ?? null);
      if (session?.user) {
        checkAdminStatus(session.user.id);
      } else {
        setLoading(false);
      }
    });

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      setUser(session?.user ?? null);
      if (session?.user) {
        checkAdminStatus(session.user.id);
      } else {
        setIsAdmin(false);
        setLoading(false);
      }
    });

    return () => subscription.unsubscribe();
  }, []);

  const checkAdminStatus = async (userId) => {
    try {
      const { data } = await supabase
        .from('admins')
        .select('id')
        .eq('id', userId)
        .single();

      setIsAdmin(!!data);
    } catch (err) {
      setIsAdmin(false);
    } finally {
      setLoading(false);
    }
  };

  const signIn = useCallback(async (email, password) => {
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) throw error;
  }, []);

  const signOut = useCallback(async () => {
    await supabase.auth.signOut();
  }, []);

  return { user, isAdmin, loading, signIn, signOut };
}

/**
 * Hook for admin club management.
 * @returns {{ clubs: array, loading: boolean, addClub: function, updateClub: function, deleteClub: function }}
 */
export function useAdminClubs() {
  const [clubs, setClubs] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchClubs = useCallback(async () => {
    setLoading(true);
    const { data } = await supabase
      .from('clubs')
      .select('*')
      .order('name');
    setClubs(data || []);
    setLoading(false);
  }, []);

  useEffect(() => {
    fetchClubs();
  }, [fetchClubs]);

  const addClub = async (club) => {
    const { error } = await supabase.from('clubs').insert(club);
    if (error) throw error;
    await fetchClubs();
  };

  const updateClub = async (id, updates) => {
    const { error } = await supabase.from('clubs').update(updates).eq('id', id);
    if (error) throw error;
    await fetchClubs();
  };

  const deleteClub = async (id) => {
    const { error } = await supabase.from('clubs').delete().eq('id', id);
    if (error) throw error;
    await fetchClubs();
  };

  return { clubs, loading, addClub, updateClub, deleteClub, refetch: fetchClubs };
}

/**
 * Hook for admin comment moderation.
 * @returns {{ comments: array, loading: boolean, hideComment: function, unhideComment: function }}
 */
export function useAdminComments() {
  const [comments, setComments] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchComments = useCallback(async () => {
    setLoading(true);
    const { data } = await supabase
      .from('comments')
      .select('*, clubs(name)')
      .order('created_at', { ascending: false })
      .limit(100);
    setComments(data || []);
    setLoading(false);
  }, []);

  useEffect(() => {
    fetchComments();
  }, [fetchComments]);

  const hideComment = async (id) => {
    await supabase.from('comments').update({ is_hidden: true }).eq('id', id);
    await fetchComments();
  };

  const unhideComment = async (id) => {
    await supabase.from('comments').update({ is_hidden: false }).eq('id', id);
    await fetchComments();
  };

  return { comments, loading, hideComment, unhideComment, refetch: fetchComments };
}

/**
 * Hook for admin report management.
 * @returns {{ reports: array, loading: boolean, updateStatus: function }}
 */
export function useAdminReports() {
  const [reports, setReports] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchReports = useCallback(async () => {
    setLoading(true);
    const { data } = await supabase
      .from('reports')
      .select('*, comments(content, clubs(name))')
      .order('created_at', { ascending: false });
    setReports(data || []);
    setLoading(false);
  }, []);

  useEffect(() => {
    fetchReports();
  }, [fetchReports]);

  const updateStatus = async (id, status) => {
    await supabase.from('reports').update({ status }).eq('id', id);
    await fetchReports();
  };

  return { reports, loading, updateStatus, refetch: fetchReports };
}
