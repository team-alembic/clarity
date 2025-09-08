// Detect initial theme from localStorage or system preference
export const getInitialTheme = () => {
  const storedTheme = localStorage.getItem('atlas-theme');
  if (storedTheme) return storedTheme;
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
};

// Get current theme from DOM
export const getCurrentTheme = () => {
  return document.documentElement.classList.contains('dark') ? 'dark' : 'light';
};

// Theme change callback system
const themeChangeCallbacks = new Set();

export const onThemeChange = (callback) => {
  themeChangeCallbacks.add(callback);
  return () => themeChangeCallbacks.delete(callback); // return cleanup function
};

const notifyThemeChange = (theme) => {
  themeChangeCallbacks.forEach(callback => callback(theme));
};

const ThemeToggle = {
  mounted() {
    this.applyTheme(getInitialTheme());

    // Listen for system theme changes when no stored preference
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
      if (!localStorage.getItem('atlas-theme')) {
        const newTheme = e.matches ? 'dark' : 'light';
        this.applyTheme(newTheme);
        this.pushEvent("set-theme", { theme: newTheme });
      }
    });

    // Listen for click events on the toggle button
    this.el.addEventListener('click', () => {
      this.toggleTheme();
    });
  },

  toggleTheme() {
    const currentTheme = document.documentElement.classList.contains('dark') ? 'dark' : 'light';
    const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
    
    // Store the user's preference
    localStorage.setItem('atlas-theme', newTheme);
    this.applyTheme(newTheme);
    
    // Notify the LiveView of the theme change
    this.pushEvent("set-theme", { theme: newTheme });
  },

  applyTheme(theme) {
    const root = document.documentElement;
    
    // Use Tailwind's standard dark mode approach
    if (theme === 'dark') {
      root.classList.add('dark');
    } else {
      root.classList.remove('dark');
    }
    
    // Notify all theme change listeners
    notifyThemeChange(theme);
  }
};

export default ThemeToggle;