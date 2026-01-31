-- Fix Free Ventures to be mid-tier (~#35)
UPDATE clubs SET elo_rating = 1510, wins = ROUND(total_votes * 0.505) WHERE name = 'Free Ventures';
