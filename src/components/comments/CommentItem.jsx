import { useState } from 'react';
import { ReportModal } from './ReportModal';
import { CommentForm } from './CommentForm';

/**
 * Single comment item component.
 * Displays comment with voting, reply, delete, and report options.
 * @param {{ comment: object, userVote: string, onVote: function, onReport: function, onReply: function, onDelete: function, replies: array, userVotes: object, currentSessionId: string, isReply: boolean }} props
 */
export function CommentItem({ comment, userVote, onVote, onReport, onReply, onDelete, replies = [], userVotes = {}, currentSessionId = '', isReply = false }) {
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

  return (
    <div className={`bg-white rounded-lg p-4 border border-gray-200 ${isReply ? 'ml-6 border-l-2 border-l-gray-300' : ''}`}>
      <p className={`text-gray-800 mb-3 ${isReply ? 'text-sm' : ''}`}>{comment.content}</p>

      <div className="flex items-center justify-between">
        <div className="flex items-center gap-4">
          <div className="flex items-center gap-2">
            <button
              onClick={() => onVote(comment.id, 'up')}
              className={`p-1 rounded transition-colors ${
                userVote === 'up'
                  ? 'text-green-600 bg-green-50'
                  : 'text-gray-400 hover:text-green-600 hover:bg-green-50'
              }`}
              title="Upvote"
            >
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 15l7-7 7 7" />
              </svg>
            </button>
            <span className={`text-sm font-medium ${
              comment.upvotes - comment.downvotes > 0 ? 'text-green-600' :
              comment.upvotes - comment.downvotes < 0 ? 'text-red-600' : 'text-gray-500'
            }`}>
              {comment.upvotes - comment.downvotes}
            </span>
            <button
              onClick={() => onVote(comment.id, 'down')}
              className={`p-1 rounded transition-colors ${
                userVote === 'down'
                  ? 'text-red-600 bg-red-50'
                  : 'text-gray-400 hover:text-red-600 hover:bg-red-50'
              }`}
              title="Downvote"
            >
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
              </svg>
            </button>
          </div>

          <span className="text-sm text-gray-400">
            {formatDate(comment.created_at)}
          </span>

          {!isReply && (
            <button
              onClick={() => setShowReplyForm(!showReplyForm)}
              className="text-sm text-gray-400 hover:text-berkeley-blue transition-colors"
            >
              reply
            </button>
          )}
        </div>

        <div className="flex items-center gap-3">
          {isOwnComment && (
            <button
              onClick={handleDelete}
              disabled={deleting}
              className="text-sm text-gray-400 hover:text-red-600 transition-colors disabled:opacity-50"
            >
              {deleting ? '...' : 'delete'}
            </button>
          )}
          <button
            onClick={() => setShowReportModal(true)}
            className="text-sm text-gray-400 hover:text-red-600 transition-colors"
          >
            report
          </button>
        </div>
      </div>

      {showReplyForm && (
        <CommentForm
          onSubmit={onReply}
          parentId={comment.id}
          onCancel={() => setShowReplyForm(false)}
          isReply
        />
      )}

      {replies.length > 0 && (
        <div className="mt-3 space-y-2">
          {replies.map((reply) => (
            <CommentItem
              key={reply.id}
              comment={reply}
              userVote={userVotes[reply.id]}
              onVote={onVote}
              onReport={onReport}
              onReply={onReply}
              onDelete={onDelete}
              userVotes={userVotes}
              currentSessionId={currentSessionId}
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
