-- Move Entrepreneurs @ Berkeley to position #5
UPDATE clubs SET elo_rating = 1655, wins = round(total_votes * 0.535) WHERE name = 'Entrepreneurs @ Berkeley';
