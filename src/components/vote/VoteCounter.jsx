/**
 * Vote counter component.
 * Displays the total number of wins recorded.
 * @param {{ count: number }} props - Total win count.
 */
export function VoteCounter({ count }) {
  return (
    <div className="text-center text-gray-600">
      <span className="font-semibold text-berkeley-blue">{count.toLocaleString()}</span>
      {' '}
      total win{count !== 1 ? 's' : ''} recorded
    </div>
  );
}
