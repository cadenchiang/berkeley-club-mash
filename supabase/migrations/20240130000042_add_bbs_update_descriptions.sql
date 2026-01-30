-- ADD BERKELEY BUSINESS SOCIETY AND UPDATE DESCRIPTIONS

-- Add Berkeley Business Society
INSERT INTO clubs (name, description, category, image_url, elo_rating, total_votes, wins)
VALUES (
  'Berkeley Business Society',
  'for business kids who got rejected everywhere else - we definitely dont haze our pledges or make them die for the club',
  'business',
  'https://se-images.campuslabs.com/clink/images/c8f8d8e8-f8a8-4b8c-9d8e-8f8a8b8c8d8e.png',
  1500,
  0,
  0
);

-- Update Latinx Business Student Association description
UPDATE clubs SET description = 'latinx business fam since ''98 - we out here building careers and community fr fr'
WHERE name = 'Latinx Business Student Association';

-- Update BJJ at Berkeley description
UPDATE clubs SET description = 'choking people out legally since 2013 - come roll with us tuesdays and thursdays'
WHERE name = 'BJJ at Berkeley';
