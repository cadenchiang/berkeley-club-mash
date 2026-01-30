import { CommentForm } from './CommentForm';
import { CommentItem } from './CommentItem';
import { useComments } from '../../hooks/useComments';

/**
 * Comment list component.
 * Displays all comments for a club with add/vote/report functionality.
 * @param {{ clubId: string }} props
 */
export function CommentList({ clubId }) {
  const {
    comments,
    userVotes,
    loading,
    error,
    addComment,
    voteComment,
    reportComment,
  } = useComments(clubId);

  return (
    <div>
      <div className="flex items-center gap-2 mb-3">
        <span className="text-sm font-medium text-gray-700">comments</span>
        <span className="text-xs text-gray-400">{comments.length}</span>
      </div>

      <CommentForm onSubmit={addComment} />

      {loading ? (
        <div className="flex justify-center py-6">
          <div className="animate-spin rounded-full h-6 w-6 border-2 border-gray-300 border-t-gray-600"></div>
        </div>
      ) : error ? (
        <p className="text-red-500 text-sm py-3">{error}</p>
      ) : comments.length === 0 ? (
        <p className="text-gray-400 text-sm py-6">
          no comments yet
        </p>
      ) : (
        <div className="space-y-3">
          {comments.map((comment) => (
            <CommentItem
              key={comment.id}
              comment={comment}
              userVote={userVotes[comment.id]}
              onVote={voteComment}
              onReport={reportComment}
            />
          ))}
        </div>
      )}
    </div>
  );
}
