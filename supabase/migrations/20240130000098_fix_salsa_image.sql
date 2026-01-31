-- Fix Salsa at Cal image URL (old CampusLabs URL was 404)
UPDATE clubs
SET image_url = 'https://salsaatcal.com/logo.png'
WHERE name = 'Salsa at Cal';
