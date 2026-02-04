import { useMemo, useState } from 'react';
import { CommentForm } from './CommentForm';
import { CommentItem } from './CommentItem';
import { useComments } from '../../hooks/useComments';

/**
 * Comment list component.
 * Displays all comments for a club with add/vote/report and sort functionality.
 * Supports "hot" (recency-weighted votes), "top" (pure net votes), and "new" (time) sort modes.
 * @param {{ clubId: string }} props
 */
export function CommentList({ clubId }) {
  const [sortMode, setSortMode] = useState('hot');
  const {
    comments,
    userVotes,
    loading,
    error,
    sessionId,
    addComment,
    voteComment,
    reportComment,
    deleteComment,
  } = useComments(clubId);

  // Organize comments into parent comments and replies, sorted by selected mode
  const { parentComments, repliesByParent } = useMemo(() => {
    const parents = [];
    const replies = {};

    comments.forEach((comment) => {
      if (comment.parent_id) {
        if (!replies[comment.parent_id]) {
          replies[comment.parent_id] = [];
        }
        replies[comment.parent_id].push(comment);
      } else {
        parents.push(comment);
      }
    });

    // Sort replies by date (oldest first for threaded view)
    Object.keys(replies).forEach((parentId) => {
      replies[parentId].sort((a, b) => new Date(a.created_at) - new Date(b.created_at));
    });

    // Sort parent comments by selected mode
    const now = Date.now();
    if (sortMode === 'hot') {
      // Hot: net votes decayed by age — recent popular comments rise to top
      parents.sort((a, b) => {
        const netA = (a.upvotes || 0) - (a.downvotes || 0);
        const netB = (b.upvotes || 0) - (b.downvotes || 0);
        const hoursA = (now - new Date(a.created_at).getTime()) / 3600000;
        const hoursB = (now - new Date(b.created_at).getTime()) / 3600000;
        const scoreA = netA / Math.pow(hoursA + 2, 1.5);
        const scoreB = netB / Math.pow(hoursB + 2, 1.5);
        if (scoreB !== scoreA) return scoreB - scoreA;
        return new Date(b.created_at) - new Date(a.created_at);
      });
    } else if (sortMode === 'top') {
      // Top: pure net votes, all-time highest first
      parents.sort((a, b) => {
        const netA = (a.upvotes || 0) - (a.downvotes || 0);
        const netB = (b.upvotes || 0) - (b.downvotes || 0);
        if (netB !== netA) return netB - netA;
        return new Date(b.created_at) - new Date(a.created_at);
      });
    } else {
      // New: most recent first
      parents.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
    }

    return { parentComments: parents, repliesByParent: replies };
  }, [comments, sortMode]);

  return (
    <div>
      <div className="flex items-center justify-between mb-3">
        <div className="flex items-center gap-2">
          <svg className="w-4 h-4 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
          </svg>
          <span className="text-sm font-medium text-gray-700">comments</span>
          <span className="text-xs text-gray-400">{comments.length}</span>
        </div>
        <div className="flex items-center gap-2">
          {['hot', 'top', 'new'].map((mode) => (
            <button
              key={mode}
              onClick={() => setSortMode(mode)}
              className={`text-xs transition-colors ${
                sortMode === mode
                  ? 'text-gray-600 font-medium'
                  : 'text-gray-350 hover:text-gray-500'
              }`}
            >
              {mode}
            </button>
          ))}
        </div>
      </div>

      <CommentForm onSubmit={addComment} />

      {loading ? (
        <div className="flex justify-center py-6">
          <div className="animate-spin rounded-full h-6 w-6 border-2 border-gray-300 border-t-gray-600"></div>
        </div>
      ) : error ? (
        <p className="text-red-500 text-sm py-3">{error}</p>
      ) : parentComments.length === 0 ? (
        <p className="text-gray-400 text-sm py-6">
          no comments yet
        </p>
      ) : (
        <div className="space-y-3">
          {parentComments.map((comment) => (
            <CommentItem
              key={comment.id}
              comment={comment}
              userVote={userVotes[comment.id]}
              onVote={voteComment}
              onReport={reportComment}
              onReply={addComment}
              onDelete={deleteComment}
              replies={repliesByParent[comment.id] || []}
              userVotes={userVotes}
              currentSessionId={sessionId}
            />
          ))}
        </div>
      )}
    </div>
  );
}
