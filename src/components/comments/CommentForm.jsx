import { useState } from 'react';

/**
 * Comment form component.
 * Allows users to submit anonymous comments.
 * @param {{ onSubmit: function }} props
 */
export function CommentForm({ onSubmit }) {
  const [content, setContent] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!content.trim() || submitting) return;

    setSubmitting(true);
    setError(null);

    try {
      await onSubmit(content);
      setContent('');
    } catch (err) {
      setError(err.message);
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="mb-6">
      <textarea
        value={content}
        onChange={(e) => setContent(e.target.value)}
        placeholder="Share your thoughts about this club..."
        rows={3}
        maxLength={500}
        className="w-full px-4 py-3 border border-gray-300 rounded-lg resize-none focus:outline-none focus:ring-2 focus:ring-berkeley-blue/50 focus:border-berkeley-blue"
      />
      <div className="flex items-center justify-between mt-2">
        <span className="text-sm text-gray-500">
          {content.length}/500 characters
        </span>
        <button
          type="submit"
          disabled={!content.trim() || submitting}
          className="px-4 py-2 bg-berkeley-blue text-white rounded-lg font-medium hover:bg-berkeley-blue/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {submitting ? 'Posting...' : 'Post Comment'}
        </button>
      </div>
      {error && (
        <p className="mt-2 text-sm text-red-600">{error}</p>
      )}
    </form>
  );
}
