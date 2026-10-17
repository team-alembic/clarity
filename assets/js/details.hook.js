// Expands and collapses a group's <details> in the navigation tree.
//
// The server owns each group's open state, so the hook reports the state the
// user asked for rather than a bare "toggle". It acts on clicks, not on the
// `toggle` event, because `toggle` also fires when a LiveView patch opens or
// closes the group, and echoing those back would act on groups nobody clicked.
// (A vertex's node toggles from a button beside its link instead: a link
// can't sit in a <summary>.)
export default {
  mounted() {
    this.el.addEventListener("click", (event) => {
      // Nested groups sit inside this element; their clicks are theirs.
      const summary = event.target.closest("summary");
      if (summary?.parentElement !== this.el) return;

      event.preventDefault();
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
