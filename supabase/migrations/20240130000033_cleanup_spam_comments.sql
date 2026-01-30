-- CLEANUP SPAM COMMENTS
-- Delete all "great cub" spam (keep none - it's spam)
DELETE FROM comments WHERE content = 'great cub';

-- Delete duplicate "best club" comments (keep one)
DELETE FROM comments
WHERE content = 'best club'
AND id != (SELECT id FROM comments WHERE content = 'best club' ORDER BY created_at LIMIT 1);

-- Delete test comment
DELETE FROM comments WHERE content LIKE '%Security test%';
