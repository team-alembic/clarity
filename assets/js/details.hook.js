// Expands and collapses a <details> node in the navigation tree.
//
// The server owns each node's open state, so the hook reports the state the
// user asked for rather than a bare "toggle". It acts on clicks, not on the
// `toggle` event, because `toggle` also fires when a LiveView patch opens or
// closes the node, and echoing those back would act on nodes nobody clicked.
export default {
  mounted() {
    this.el.addEventListener("click", (event) => {
      // Nested nodes sit inside this element; their clicks are theirs.
      const summary = event.target.closest("summary");
      if (summary?.parentElement !== this.el) return;

      // A label link navigates, and the server opens the node it lands on.
      // The current node's label has nowhere to go, so it toggles in place
      // like the chevron.
      const link = event.target.closest("a");
      if (link && link.getAttribute("aria-current") !== "page") return;

      event.preventDefault();
      if (link) event.stopPropagation();
      this.el.open = !this.el.open;

      const eventName = this.el.getAttribute("phx-toggle");
      if (!eventName) return;

      const values = { open: this.el.open };
      for (const attr of this.el.attributes) {
        if (attr.name.startsWith("phx-value-")) {
          const key = attr.name.replace("phx-value-", "").replace(/-/g, "_");
          values[key] = attr.value;
        }
      }

      this.pushEventTo(this.el, eventName, values);
    });
  },
};
