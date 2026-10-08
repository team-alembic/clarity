// Keeps the current vertex's row in view in the navigation tree.
//
// When the current vertex or the lens changes (on switching lens, or following
// a breadcrumb), the navigation scrolls the row into view, once the tree for
// them has loaded: until then the previous tree is still shown. Other updates,
// such as opening a node, leave the scroll position alone.

// Unless `row` is already in view below `scroller`'s sticky heading, scrolls
// it to the middle of that space, among its neighbours.
function reveal(scroller, row) {
  const heading = scroller.querySelector(".nav-heading")?.offsetHeight ?? 0;
  const view = scroller.getBoundingClientRect();
  const box = row.getBoundingClientRect();

  const above = box.top - (view.top + heading);
  if (above >= 0 && box.bottom <= view.bottom) return;

  const space = view.height - heading;
  scroller.scrollTop += above - (space - box.height) / 2;
}

export default {
  mounted() {
    this.revealCurrent();
  },
  updated() {
    this.revealCurrent();
  },
  revealCurrent() {
    const current = this.el.dataset.current;
    if (current === this.revealed || "loading" in this.el.dataset) return;

    const row = this.el.querySelector('a[aria-current="page"]');
    const scroller = this.el.closest(".navigation");
    if (!row || !scroller) return;

    this.revealed = current;
    reveal(scroller, row);
  },
};
