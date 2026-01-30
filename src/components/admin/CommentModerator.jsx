import { useAdminComments } from '../../hooks/useAdmin';

/**
 * Comment moderator component for admins.
 * Allows hiding/unhiding comments.
 */
export function CommentModerator() {
  const { comments, loading, hideComment, unhideComment } = useAdminComments();

  if (loading) {
    return <div className="text-center py-8">Loading comments...</div>;
  }

  return (
    <div>
      <h2 className="text-xl font-bold text-gray-900 mb-6">
        Moderate Comments ({comments.length})
      </h2>

      {comments.length === 0 ? (
        <p className="text-gray-500 text-center py-8">No comments to moderate.</p>
      ) : (
        <div className="space-y-3">
          {comments.map((comment) => (
            <div
              key={comment.id}
              className={`bg-white p-4 rounded-lg border ${comment.is_hidden ? 'opacity-50' : ''}`}
            >
              <div className="flex justify-between items-start mb-2">
                <span className="text-sm text-gray-500">
                  On: {comment.clubs?.name || 'Unknown club'}
                </span>
                <span className={`text-xs px-2 py-1 rounded ${
                  comment.is_hidden ? 'bg-red-100 text-red-800' : 'bg-green-100 text-green-800'
                }`}>
                  {comment.is_hidden ? 'Hidden' : 'Visible'}
                </span>
              </div>

              <p className="text-gray-800 mb-3">{comment.content}</p>

              <div className="flex items-center justify-between text-sm">
                <span className="text-gray-500">
                  Votes: +{comment.upvotes} / -{comment.downvotes}
                </span>
                {comment.is_hidden ? (
                  <button
                    onClick={() => unhideComment(comment.id)}
                    className="px-3 py-1 bg-green-600 text-white rounded hover:bg-green-700"
                  >
                    Unhide
                  </button>
                ) : (
                  <button
                    onClick={() => hideComment(comment.id)}
                    className="px-3 py-1 bg-red-600 text-white rounded hover:bg-red-700"
                  >
                    Hide
                  </button>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
