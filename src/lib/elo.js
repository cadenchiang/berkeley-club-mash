/**
 * ELO rating calculation utilities.
 * Standard ELO system with K-factor of 32.
 */

const K_FACTOR = 32;

/**
 * Calculate expected score for a player.
 * @param {number} playerRating - The player's current ELO rating.
 * @param {number} opponentRating - The opponent's current ELO rating.
 * @returns {number} Expected score between 0 and 1.
 */
export function getExpectedScore(playerRating, opponentRating) {
  return 1 / (1 + Math.pow(10, (opponentRating - playerRating) / 400));
}

/**
 * Calculate new ELO ratings after a match.
 * @param {number} winnerRating - Current ELO rating of the winner.
 * @param {number} loserRating - Current ELO rating of the loser.
 * @returns {{ newWinnerRating: number, newLoserRating: number }} New ratings for both clubs.
 */
export function calculateEloChange(winnerRating, loserRating) {
  const expectedWinner = getExpectedScore(winnerRating, loserRating);
  const expectedLoser = getExpectedScore(loserRating, winnerRating);

  const newWinnerRating = Math.round(winnerRating + K_FACTOR * (1 - expectedWinner));
  const newLoserRating = Math.round(loserRating + K_FACTOR * (0 - expectedLoser));

  return {
    newWinnerRating,
    newLoserRating,
    winnerChange: newWinnerRating - winnerRating,
    loserChange: newLoserRating - loserRating,
  };
}
