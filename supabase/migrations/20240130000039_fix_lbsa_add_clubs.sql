-- FIX LBSA IMAGE and ADD NEW CLUBS

-- Fix LBSA image
UPDATE clubs SET image_url = 'https://images.squarespace-cdn.com/content/v1/6434baae9d3bd92ee92dca48/ba0e2b95-dda1-4dd6-8353-2ff08e620349/LSBA+Logo+%28Navy+Blue%29.png'
WHERE name = 'Latinx Business Student Association';

-- Add Calisthenics Club
INSERT INTO clubs (name, description, category, image_url, elo_rating, total_votes, wins)
VALUES (
  'Calisthenics Club',
  'the one and only calisthenics club at UC Berkeley - meets Fridays 5pm at CK Track',
  'sports',
  'https://se-images.campuslabs.com/clink/images/17152c88-1b3f-4327-9ab1-383b0de64c7b0dad992f-7cfd-4cab-a696-086724c39878.png',
  1500,
  0,
  0
);

-- Add BJJ@Berkeley (Grappling/Brazilian Jiu-Jitsu)
INSERT INTO clubs (name, description, category, image_url, elo_rating, total_votes, wins)
VALUES (
  'BJJ at Berkeley',
  'Brazilian Jiu-Jitsu grappling club - the fastest growing martial art in the world',
  'sports',
  'https://se-images.campuslabs.com/clink/images/a9f8b8c9-d8e8-4f8a-b8c9-d8e8f8a8b8c8.png',
  1500,
  0,
  0
);
