import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useSession } from './useSession';

// Profanity filter - basic list of words to block
const BLOCKED_WORDS = [
  'nigger', 'nigga', 'faggot', 'fag', 'retard', 'kike', 'chink', 'spic', 'wetback', 'cunt'
];

const containsProfanity = (text) => {
  const lowerText = text.toLowerCase();
  return BLOCKED_WORDS.some((word) => lowerText.includes(word));
};

/**
 * Hook for managing comments on a club.
 * @param {string} clubId - The club's UUID.
 * @returns {{ comments: array, loading: boolean, error: string, addComment: function, voteComment: function, reportComment: function }}
 */
export function useComments(clubId) {
  const [comments, setComments] = useState([]);
  const [userVotes, setUserVotes] = useState({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const { sessionId, fingerprint } = useSession();

  const fetchComments = useCallback(async () => {
    if (!clubId) return;

    setLoading(true);
    setError(null);

    try {
      const { data, error: fetchError } = await supabase
        .from('comments')
        .select('*')
        .eq('club_id', clubId)
        .eq('is_hidden', false)
        .order('created_at', { ascending: false });

      if (fetchError) throw fetchError;

      setComments(data || []);

      if (sessionId && data?.length > 0) {
        const commentIds = data.map((c) => c.id);
        const { data: votes } = await supabase
          .from('comment_votes')
          .select('comment_id, vote_type')
          .eq('session_id', sessionId)
          .in('comment_id', commentIds);

        const votesMap = {};
        votes?.forEach((v) => {
          votesMap[v.comment_id] = v.vote_type;
        });
        setUserVotes(votesMap);
      }
    } catch (err) {
      console.error('Error fetching comments:', err);
      setError('Failed to load comments.');
    } finally {
      setLoading(false);
    }
  }, [clubId, sessionId]);

  useEffect(() => {
    fetchComments();
  }, [fetchComments]);

  const addComment = useCallback(async (content, parentId = null) => {
    if (!clubId || !sessionId || !content.trim()) return;

    // Check for profanity
    if (containsProfanity(content)) {
      throw new Error('Please keep comments respectful.');
    }

    try {
      const { data, error: rpcError } = await supabase.rpc('add_comment', {
        p_club_id: clubId,
        p_content: content.trim(),
        p_session_id: sessionId,
        p_parent_id: parentId,
      });

      if (rpcError) throw rpcError;

      if (!data.success) {
        throw new Error(data.message || 'Failed to add comment.');
      }

      await fetchComments();
    } catch (err) {
      console.error('Error adding comment:', err);
      throw new Error(err.message || 'Failed to add comment.');
    }
  }, [clubId, sessionId, fetchComments]);

  const voteComment = useCallback(async (commentId, voteType) => {
    if (!sessionId || !commentId) return;

    const currentVote = userVotes[commentId];
    const comment = comments.find((c) => c.id === commentId);
    if (!comment) return;

    // Optimistic update
    const newComments = comments.map((c) => {
      if (c.id !== commentId) return c;
      const updated = { ...c };
      if (currentVote === voteType) {
        // Removing vote
        if (voteType === 'up') updated.upvotes = Math.max(0, c.upvotes - 1);
        else updated.downvotes = Math.max(0, c.downvotes - 1);
      } else if (currentVote) {
        // Switching vote
        if (voteType === 'up') {
          updated.upvotes = c.upvotes + 1;
          updated.downvotes = Math.max(0, c.downvotes - 1);
        } else {
          updated.downvotes = c.downvotes + 1;
          updated.upvotes = Math.max(0, c.upvotes - 1);
        }
      } else {
        // New vote
        if (voteType === 'up') updated.upvotes = c.upvotes + 1;
        else updated.downvotes = c.downvotes + 1;
      }
      return updated;
    });
    setComments(newComments);

    // Optimistic vote state update
    const newUserVotes = { ...userVotes };
    if (currentVote === voteType) {
      delete newUserVotes[commentId];
    } else {
      newUserVotes[commentId] = voteType;
    }
    setUserVotes(newUserVotes);

    try {
      // Use local API proxy for IP-based rate limiting
      const response = await fetch('/api/vote-comment', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          p_comment_id: commentId,
          p_session_id: sessionId,
          p_vote_type: voteType,
          p_fingerprint: fingerprint,
        }),
      });

      const data = await response.json();
      if (!response.ok || !data.success) {
        throw new Error(data.message || data.error || 'Vote failed');
      }
    } catch (err) {
      console.error('Error voting on comment:', err);
      // Revert on error
      await fetchComments();
    }
  }, [sessionId, fingerprint, userVotes, comments, fetchComments]);

  const reportComment = useCallback(async (commentId, reason) => {
    if (!commentId || !sessionId || !reason.trim()) return;

    try {
      const { data, error: rpcError } = await supabase.rpc('report_comment', {
        p_comment_id: commentId,
        p_reason: reason.trim(),
        p_session_id: sessionId,
      });

      if (rpcError) throw rpcError;
      if (!data.success) throw new Error(data.error);
    } catch (err) {
      console.error('Error reporting comment:', err);
      throw new Error('Failed to submit report.');
    }
  }, [sessionId]);

  const deleteComment = useCallback(async (commentId) => {
    if (!commentId || !sessionId) return;

    try {
      const { data, error: rpcError } = await supabase.rpc('delete_own_comment', {
        p_comment_id: commentId,
        p_session_id: sessionId,
      });

      if (rpcError) throw rpcError;
      if (!data.success) throw new Error(data.message || 'Failed to delete comment.');

      // Remove from local state
      setComments((prev) => prev.filter((c) => c.id !== commentId && c.parent_id !== commentId));
    } catch (err) {
      console.error('Error deleting comment:', err);
      throw new Error(err.message || 'Failed to delete comment.');
    }
  }, [sessionId]);

  return {
    comments,
    userVotes,
    loading,
    error,
    sessionId,
    addComment,
    voteComment,
    reportComment,
    deleteComment,
  };
}
