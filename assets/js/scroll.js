// A patch to another page, another vertex or another of its tabs, starts at
// the top, as following a link to a page does: the window, and the content
// beside the navigation, which scrolls on its own on wider screens. LiveView
// keeps the scroll position across patches, for patches that only change a
// page's query; on going back or forward it restores the position itself.
const CONTENT = ".layout-container > .content";

export function scrollNewPagesToTop(target = window) {
  let shownPath = target.location.pathname;

  target.addEventListener("phx:navigate", ({ detail }) => {
    const path = new URL(detail.href, target.location.href).pathname;
    if (detail.patch && !detail.pop && path !== shownPath) {
      target.scrollTo(0, 0);
      target.document?.querySelectorAll(CONTENT).forEach((content) => content.scrollTo(0, 0));
    }
    shownPath = path;
  });
}
