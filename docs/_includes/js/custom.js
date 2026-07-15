// // Function to apply theme based on system settings
// function applySystemTheme() {
//   if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
//     jtd.setTheme('dark');
//   } else {
//     jtd.setTheme('light');
//   }
// }

// // Run immediately when script loads to prevent heavy flashing
// applySystemTheme();

// // Listen for system theme changes while the user is on the page
// window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', event => {
//   applySystemTheme();
// });






(function () {
  const toggleBtn = document.getElementById('theme-toggle');

  // Helper to determine the theme state to apply
  function getPreferredTheme() {
    const savedTheme = localStorage.getItem('theme');
    if (savedTheme) {
      return savedTheme;
    }
    // Fallback to system query if no explicit user choice is stored
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }

  // Applies the theme and adjusts button icon
  function applyTheme(theme) {
    if (theme === 'dark') {
      jtd.setTheme('dark');
      if (toggleBtn) toggleBtn.innerHTML = '☀️'; // Sun icon means "switch to light"
    } else {
      jtd.setTheme('light');
      if (toggleBtn) toggleBtn.innerHTML = '🌙'; // Moon icon means "switch to dark"
    }
  }

  // 1. Run immediately on load using calculated preferences
  const currentTheme = getPreferredTheme();
  applyTheme(currentTheme);

  // 2. Set up interactive toggle and system change listeners once DOM is ready
  window.addEventListener('DOMContentLoaded', () => {
    const activeToggleBtn = document.getElementById('theme-toggle');

    // Refresh button visual state to match current theme
    applyTheme(getPreferredTheme());

    if (activeToggleBtn) {
      jtd.addEvent(activeToggleBtn, 'click', function () {
        const currentActive = jtd.getTheme();
        const newTheme = currentActive === 'dark' ? 'light' : 'dark';

        localStorage.setItem('theme', newTheme);
        applyTheme(newTheme);
      });
    }

    // Continuously listen for system changes (only overrides if user hasn't explicitly chosen one)
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', event => {
      if (!localStorage.getItem('theme')) {
        applyTheme(event.matches ? 'dark' : 'light');
      }
    });
  });
})();
