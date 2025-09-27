// Flash message hook for auto-dismissal functionality
export default {
  mounted() {
    // Auto-dismiss flash messages after 5 seconds
    this.timeout = setTimeout(() => {
      this.el.style.opacity = "0";
      setTimeout(() => {
        this.el.style.display = "none";
      }, 300); // Wait for fade transition
    }, 5000);
  },

  destroyed() {
    // Clear timeout if component is destroyed manually
    if (this.timeout) {
      clearTimeout(this.timeout);
    }
  },
};