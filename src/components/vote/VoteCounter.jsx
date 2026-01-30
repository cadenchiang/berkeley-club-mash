/**
 * Vote counter component.
 * Displays the number of votes cast today.
 * @param {{ count: number }} props - Today's vote count.
 */
export function VoteCounter({ count }) {
  return (
    <div className="text-center text-gray-600">
      <span className="font-semibold text-berkeley-blue">{count.toLocaleString()}</span>
      {' '}
      vote{count !== 1 ? 's' : ''} cast today
    </div>
  );
}
