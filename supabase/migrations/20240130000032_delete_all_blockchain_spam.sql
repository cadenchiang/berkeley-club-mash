-- DELETE ALL BLOCKCHAIN SPAM COMMENTS across ALL clubs
DELETE FROM comments
WHERE content LIKE '%blockchain.studentorg.berkeley.edu%';
