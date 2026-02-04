-- Reduce every club's total_votes by 100 and wins proportionally to maintain win rate.
UPDATE clubs SET
  wins = wins - ROUND(100.0 * wins / NULLIF(total_votes, 0))::INTEGER,
  total_votes = total_votes - 100
WHERE total_votes > 100;
