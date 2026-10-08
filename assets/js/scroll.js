// A patch to another page, another vertex or another of its tabs, starts at
// the top, as following a link to a page does. LiveView keeps the scroll
// position across patches, for patches that only change a page's query; on
// going back or forward it restores the position itself.
export function scrollNewPagesToTop(target = window) {
  let shownPath = target.location.pathname;

  target.addEventListener("phx:navigate", ({ detail }) => {
    const path = new URL(detail.href, target.location.href).pathname;
    if (detail.patch && !detail.pop && path !== shownPath) target.scrollTo(0, 0);
    shownPath = path;
  });
}
