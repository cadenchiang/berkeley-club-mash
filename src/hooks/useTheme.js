import { useState, useEffect } from 'react';

/**
 * Hook for managing theme based on system preference and time of day.
 * Automatically switches to dark mode at night (8pm-6am) or if system prefers dark.
 * @returns {{ isDark: boolean, theme: 'light' | 'dark' }}
 */
export function useTheme() {
  const [isDark, setIsDark] = useState(() => {
    // Check initial state
    return shouldBeDark();
  });

  useEffect(() => {
    // Apply theme to document
    if (isDark) {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
  }, [isDark]);

  useEffect(() => {
    // Listen for system preference changes
    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
    const handleChange = () => setIsDark(shouldBeDark());

    mediaQuery.addEventListener('change', handleChange);

    // Check time every minute for time-based switching
    const interval = setInterval(() => {
      setIsDark(shouldBeDark());
    }, 60000);

    return () => {
      mediaQuery.removeEventListener('change', handleChange);
      clearInterval(interval);
    };
  }, []);

  return { isDark, theme: isDark ? 'dark' : 'light' };
}

/**
 * Determines if dark mode should be active.
 * Returns true if system prefers dark OR if current time is between 8pm-6am.
 * @returns {boolean}
 */
function shouldBeDark() {
  // Check system preference
  const systemPrefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;

  // Check time of day (8pm to 6am = night)
  const hour = new Date().getHours();
  const isNightTime = hour >= 20 || hour < 6;

  return systemPrefersDark || isNightTime;
}
