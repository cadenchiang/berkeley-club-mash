import { useState, useEffect } from 'react';

const SESSION_KEY = 'clubmash_session_id';

/**
 * Generate a random UUID for anonymous session tracking.
 * @returns {string} A UUID v4 string.
 */
function generateSessionId() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

/**
 * Hook for managing anonymous user sessions.
 * Creates a persistent session ID stored in localStorage.
 * @returns {{ sessionId: string }} The current session ID.
 */
export function useSession() {
  const [sessionId, setSessionId] = useState('');

  useEffect(() => {
    let id = localStorage.getItem(SESSION_KEY);
    if (!id) {
      id = generateSessionId();
      localStorage.setItem(SESSION_KEY, id);
    }
    setSessionId(id);
  }, []);

  return { sessionId };
}
