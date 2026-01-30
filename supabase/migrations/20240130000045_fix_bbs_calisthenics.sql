-- FIX BBS DUPLICATE AND UPDATE DESCRIPTIONS

-- Delete duplicate BBS entries (keep only one)
DELETE FROM clubs
WHERE name = 'Berkeley Business Society'
AND id NOT IN (
  SELECT id FROM clubs WHERE name = 'Berkeley Business Society' ORDER BY created_at ASC LIMIT 1
);

-- Update BBS image to working URL format
UPDATE clubs SET image_url = 'https://se-images.campuslabs.com/clink/images/ead63fec-afa4-4e65-91db-ac93706e0cc9f1d65f38-6104-4943-874d-123695040e87.png'
WHERE name = 'Berkeley Business Society';

-- Update Calisthenics Club description to Gen Z style
UPDATE clubs SET description = 'getting absolutely shredded at CK Track every friday 5pm - no gym membership needed just pull up'
WHERE name = 'Calisthenics Club';
