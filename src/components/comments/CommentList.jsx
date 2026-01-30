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
      <h2 className="text-xl font-bold text-gray-900 mb-4">
        Comments ({comments.length})
      </h2>

      <CommentForm onSubmit={addComment} />

      {loading ? (
        <div className="flex justify-center py-8">
          <div className="animate-spin rounded-full h-8 w-8 border-4 border-berkeley-blue border-t-transparent"></div>
        </div>
      ) : error ? (
        <p className="text-red-600 text-center py-4">{error}</p>
      ) : comments.length === 0 ? (
        <p className="text-gray-500 text-center py-8">
          No comments yet. Be the first to share your thoughts!
        </p>
      ) : (
        <div className="space-y-4">
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
