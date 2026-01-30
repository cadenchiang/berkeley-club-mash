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
  const { sessionId } = useSession();

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
    if (!clubId || !content.trim()) return;

    // Check for profanity
    if (containsProfanity(content)) {
      throw new Error('Please keep comments respectful.');
    }

    try {
      const { error: insertError } = await supabase
        .from('comments')
        .insert({
          club_id: clubId,
          content: content.trim(),
          parent_id: parentId,
        });

      if (insertError) throw insertError;

      await fetchComments();
    } catch (err) {
      console.error('Error adding comment:', err);
      throw new Error(err.message || 'Failed to add comment.');
    }
  }, [clubId, fetchComments]);

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
      if (currentVote === voteType) {
        await supabase
          .from('comment_votes')
          .delete()
          .eq('comment_id', commentId)
          .eq('session_id', sessionId);

        const field = voteType === 'up' ? 'upvotes' : 'downvotes';
        await supabase
          .from('comments')
          .update({ [field]: Math.max(0, comment[field] - 1) })
          .eq('id', commentId);
      } else {
        if (currentVote) {
          await supabase
            .from('comment_votes')
            .update({ vote_type: voteType })
            .eq('comment_id', commentId)
            .eq('session_id', sessionId);

          const addField = voteType === 'up' ? 'upvotes' : 'downvotes';
          const removeField = voteType === 'up' ? 'downvotes' : 'upvotes';
          await supabase
            .from('comments')
            .update({
              [addField]: comment[addField] + 1,
              [removeField]: Math.max(0, comment[removeField] - 1),
            })
            .eq('id', commentId);
        } else {
          await supabase
            .from('comment_votes')
            .insert({
              comment_id: commentId,
              session_id: sessionId,
              vote_type: voteType,
            });

          const field = voteType === 'up' ? 'upvotes' : 'downvotes';
          await supabase
            .from('comments')
            .update({ [field]: comment[field] + 1 })
            .eq('id', commentId);
        }
      }
    } catch (err) {
      console.error('Error voting on comment:', err);
      // Revert on error
      await fetchComments();
    }
  }, [sessionId, userVotes, comments, fetchComments]);

  const reportComment = useCallback(async (commentId, reason) => {
    if (!commentId || !reason.trim()) return;

    try {
      const { error: insertError } = await supabase
        .from('reports')
        .insert({
          comment_id: commentId,
          reason: reason.trim(),
        });

      if (insertError) throw insertError;
    } catch (err) {
      console.error('Error reporting comment:', err);
      throw new Error('Failed to submit report.');
    }
  }, []);

  return {
    comments,
    userVotes,
    loading,
    error,
    addComment,
    voteComment,
    reportComment,
  };
}
