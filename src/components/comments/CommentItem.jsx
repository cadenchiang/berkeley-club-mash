import { useState } from 'react';
import { ReportModal } from './ReportModal';

/**
 * Single comment item component.
 * Displays comment with voting and report options.
 * @param {{ comment: object, userVote: string, onVote: function, onReport: function }} props
 */
export function CommentItem({ comment, userVote, onVote, onReport }) {
  const [showReportModal, setShowReportModal] = useState(false);

  const formatDate = (dateString) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    });
  };

  return (
    <div className="bg-white rounded-lg p-4 border border-gray-200">
      <p className="text-gray-800 mb-3">{comment.content}</p>

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
        </div>

        <button
          onClick={() => setShowReportModal(true)}
          className="text-sm text-gray-400 hover:text-red-600 transition-colors"
        >
          Report
        </button>
      </div>

      <ReportModal
        isOpen={showReportModal}
        onClose={() => setShowReportModal(false)}
        onSubmit={(reason) => onReport(comment.id, reason)}
      />
    </div>
  );
}
