-- Boost everyone's wins by 300 (and total_votes proportionally to maintain win rates)
UPDATE clubs SET
  total_votes = total_votes + ROUND(300.0 * total_votes / wins),
  wins = wins + 300;
