-- Just delete Blockchain matchups
DELETE FROM matchups
WHERE club_a_id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97'
   OR club_b_id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97'
   OR winner_id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97';
