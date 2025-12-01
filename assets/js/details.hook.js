export default {
  mounted() {
    // Track user interaction to distinguish from DOM patches
    this.userInteracted = false;

    this.el.addEventListener('click', (event) => {
      // Only count clicks on summary as user interaction
      if (event.target.closest('summary')) {
        this.userInteracted = true;
      }
    }, { capture: true });

    this.el.addEventListener('toggle', (event) => {
      if(this.el.getAttribute('phx-hook-loading')) return;

      // Only send event for user-initiated toggles, not DOM patches
      if (!this.userInteracted) return;
      this.userInteracted = false;

      const eventName = this.el.getAttribute('phx-toggle');
      if (!eventName) return;

      // Extract all phx-value-* attributes
      const values = {};
      for (const attr of this.el.attributes) {
        if (attr.name.startsWith('phx-value-')) {
          const key = attr.name.replace('phx-value-', '').replace(/-/g, '_');
          values[key] = attr.value;
        }
      }

      this.pushEventTo(this.el, eventName, values);
    });
  }
};
