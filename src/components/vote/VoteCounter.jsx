/**
 * Formats a number with k suffix for thousands.
 * @param {number} num - Number to format.
 * @returns {string} Formatted string (e.g., "1.2k").
 */
function formatNumber(num) {
  if (num >= 1000) {
    return (num / 1000).toFixed(1).replace(/\.0$/, '') + 'k';
  }
  return num.toString();
}

/**
 * Vote counter component.
 * Displays the total number of votes recorded.
 * @param {{ count: number }} props - Total vote count.
 */
export function VoteCounter({ count }) {
  return (
    <div className="text-center text-gray-600">
      <span className="font-semibold text-berkeley-blue">{formatNumber(count)}</span>
      {' '}
      total vote{count !== 1 ? 's' : ''} recorded
    </div>
  );
}
