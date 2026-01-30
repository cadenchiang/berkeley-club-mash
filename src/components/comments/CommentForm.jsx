import { useState } from 'react';

/**
 * Comment form component.
 * Allows users to submit anonymous comments.
 * @param {{ onSubmit: function, parentId: string, onCancel: function, isReply: boolean }} props
 */
export function CommentForm({ onSubmit, parentId = null, onCancel = null, isReply = false }) {
  const [content, setContent] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!content.trim() || submitting) return;

    setSubmitting(true);
    setError(null);

    try {
      await onSubmit(content, parentId);
      setContent('');
      if (onCancel) onCancel();
    } catch (err) {
      setError(err.message);
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className={isReply ? "mt-2" : "mb-4"}>
      <textarea
        value={content}
        onChange={(e) => setContent(e.target.value)}
        placeholder={isReply ? "write a reply..." : "what do you think?"}
        rows={isReply ? 1 : 2}
        maxLength={500}
        className={`w-full px-3 py-2 text-sm border border-gray-200 rounded resize-none focus:outline-none focus:border-gray-400 placeholder:text-gray-400 ${isReply ? 'text-xs' : ''}`}
      />
      <div className="flex items-center justify-between mt-1">
        <span className="text-xs text-gray-400">
          {content.length}/500
        </span>
        <div className="flex gap-2">
          {onCancel && (
            <button
              type="button"
              onClick={onCancel}
              className="px-3 py-1 text-xs text-gray-400 hover:text-gray-600 transition-colors"
            >
              cancel
            </button>
          )}
          <button
            type="submit"
            disabled={!content.trim() || submitting}
            className="px-3 py-1 text-xs bg-gray-100 text-gray-600 rounded hover:bg-gray-200 transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
          >
            {submitting ? '...' : isReply ? 'reply' : 'post'}
          </button>
        </div>
      </div>
      {error && (
        <p className="mt-1 text-xs text-red-500">{error}</p>
      )}
    </form>
  );
}
