import { useState, useEffect } from 'react';

const SESSION_KEY = 'clubmash_session_id';
const FINGERPRINT_KEY = 'clubmash_fingerprint';

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
 * Generate a browser fingerprint that persists across sessions.
 * Based on device/browser properties that don't change.
 * @returns {string} A hash of browser properties.
 */
function generateFingerprint() {
  const components = [
    navigator.userAgent,
    navigator.language,
    screen.width + 'x' + screen.height,
    screen.colorDepth,
    new Date().getTimezoneOffset(),
    navigator.hardwareConcurrency || 'unknown',
    navigator.platform,
    // Canvas fingerprint
    (() => {
      try {
        const canvas = document.createElement('canvas');
        const ctx = canvas.getContext('2d');
        ctx.textBaseline = 'top';
        ctx.font = '14px Arial';
        ctx.fillText('ClubMash', 2, 2);
        return canvas.toDataURL().slice(-50);
      } catch {
        return 'no-canvas';
      }
    })(),
  ];

  // Simple hash function
  const str = components.join('|');
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    const char = str.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash;
  }
  return 'fp_' + Math.abs(hash).toString(36);
}

/**
 * Hook for managing anonymous user sessions.
 * Creates a persistent session ID and browser fingerprint.
 * @returns {{ sessionId: string, fingerprint: string }} Session identifiers.
 */
export function useSession() {
  const [sessionId, setSessionId] = useState('');
  const [fingerprint, setFingerprint] = useState('');

  useEffect(() => {
    // Session ID (can be cleared by user)
    let id = localStorage.getItem(SESSION_KEY);
    if (!id) {
      id = generateSessionId();
      localStorage.setItem(SESSION_KEY, id);
    }
    setSessionId(id);

    // Fingerprint (regenerated from browser properties)
    const fp = generateFingerprint();
    localStorage.setItem(FINGERPRINT_KEY, fp);
    setFingerprint(fp);
  }, []);

  return { sessionId, fingerprint };
}
