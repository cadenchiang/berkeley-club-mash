import { useState } from 'react';
import { ReportModal } from './ReportModal';
import { CommentForm } from './CommentForm';

/**
 * Single comment item component with Reddit-style threading.
 * No boxes — uses a vertical thread line on the left for nesting.
 * Anonymous: no profile pictures or usernames.
 * @param {{ comment: object, userVote: string, onVote: function, onReport: function, onReply: function, onDelete: function, replies: array, userVotes: object, currentSessionId: string, isReply: boolean, repliesByParent: object }} props
 */
export function CommentItem({ comment, userVote, onVote, onReport, onReply, onDelete, replies = [], userVotes = {}, currentSessionId = '', isReply = false, repliesByParent = {} }) {
  const [showReportModal, setShowReportModal] = useState(false);
  const [showReplyForm, setShowReplyForm] = useState(false);
  const [deleting, setDeleting] = useState(false);

  const isOwnComment = currentSessionId && comment.session_id === currentSessionId;

  const handleDelete = async () => {
    if (!confirm('Delete this comment?')) return;
    setDeleting(true);
    try {
      await onDelete(comment.id);
    } catch (err) {
      alert(err.message);
    } finally {
      setDeleting(false);
    }
  };

  const formatDate = (dateString) => {
    const date = new Date(dateString);
    const now = new Date();
    const diffMs = now - date;
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMs / 3600000);
    const diffDays = Math.floor(diffMs / 86400000);

    if (diffMins < 1) return 'just now';
    if (diffMins < 60) return `${diffMins}m ago`;
    if (diffHours < 24) return `${diffHours}h ago`;
    if (diffDays < 7) return `${diffDays}d ago`;
    return date.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
    });
  };

  const netVotes = (comment.upvotes || 0) - (comment.downvotes || 0);

  return (
    <div className={isReply ? 'mt-2' : ''}>
      {/* Timestamp */}
      <div className="mb-1">
        <span className="text-xs text-gray-400">{formatDate(comment.created_at)}</span>
      </div>

      {/* Content */}
      <p className="text-sm text-gray-800 mb-1.5 leading-relaxed">{comment.content}</p>

      {/* Actions row — inline like Reddit */}
      <div className="flex items-center gap-1 -ml-1">
        <button
          onClick={() => onVote(comment.id, 'up')}
          className={`p-0.5 rounded transition-colors ${
            userVote === 'up'
              ? 'text-orange-500'
              : 'text-gray-400 hover:text-orange-500'
          }`}
          title="Upvote"
        >
          <svg className="w-4 h-4" fill="none" stroke="currentColor" strokeWidth={2.5} viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" d="M5 15l7-7 7 7" />
          </svg>
        </button>
        <span className={`text-xs font-medium min-w-[1rem] text-center ${
          netVotes > 0 ? 'text-orange-500' :
          netVotes < 0 ? 'text-blue-500' : 'text-gray-400'
        }`}>
          {netVotes}
        </span>
        <button
          onClick={() => onVote(comment.id, 'down')}
          className={`p-0.5 rounded transition-colors ${
            userVote === 'down'
              ? 'text-blue-500'
              : 'text-gray-400 hover:text-blue-500'
          }`}
          title="Downvote"
        >
          <svg className="w-4 h-4" fill="none" stroke="currentColor" strokeWidth={2.5} viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" d="M19 9l-7 7-7-7" />
          </svg>
        </button>

        <button
          onClick={() => setShowReplyForm(!showReplyForm)}
          className="text-xs text-gray-400 hover:text-gray-600 transition-colors ml-2"
        >
          reply
        </button>

        {isOwnComment && (
          <button
            onClick={handleDelete}
            disabled={deleting}
            className="text-xs text-gray-400 hover:text-red-500 transition-colors ml-1 disabled:opacity-50"
          >
            {deleting ? '...' : 'delete'}
          </button>
        )}

        <button
          onClick={() => setShowReportModal(true)}
          className="text-xs text-gray-400 hover:text-red-500 transition-colors ml-1"
        >
          report
        </button>
      </div>

      {showReplyForm && (
        <div className="mt-2">
          <CommentForm
            onSubmit={onReply}
            parentId={comment.id}
            onCancel={() => setShowReplyForm(false)}
            isReply
          />
        </div>
      )}

      {/* Nested replies with thread line */}
      {replies.length > 0 && (
        <div className="mt-2 ml-2 pl-3 border-l-2 border-gray-200 hover:border-gray-400 transition-colors">
          {replies.map((reply) => (
            <CommentItem
              key={reply.id}
              comment={reply}
              userVote={userVotes[reply.id]}
              onVote={onVote}
              onReport={onReport}
              onReply={onReply}
              onDelete={onDelete}
              replies={repliesByParent[reply.id] || []}
              userVotes={userVotes}
              currentSessionId={currentSessionId}
              repliesByParent={repliesByParent}
              isReply
            />
          ))}
        </div>
      )}

      <ReportModal
        isOpen={showReportModal}
        onClose={() => setShowReportModal(false)}
        onSubmit={(reason) => onReport(comment.id, reason)}
      />
    </div>
  );
}
