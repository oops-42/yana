// Function to apply theme based on system settings
function applySystemTheme() {
  if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
    jtd.setTheme('dark');
  } else {
    jtd.setTheme('light');
  }
}

// Run immediately when script loads to prevent heavy flashing
applySystemTheme();

// Listen for system theme changes while the user is on the page
window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', event => {
  applySystemTheme();
});
