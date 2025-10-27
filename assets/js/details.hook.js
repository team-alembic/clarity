export default {
  mounted() {
    this.el.addEventListener('toggle', (event) => {
      if(this.el.getAttribute('phx-hook-loading')) return;

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
