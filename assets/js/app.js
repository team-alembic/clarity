// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"

import Mermaid from "./mermaid.hook";
import Viz from "./viz.hook";
import Tooltip from "./tooltip.hook";
import Settings, { getLinking, getNameStyle } from "./settings.hook";
import { applyTheme, getInitialTheme } from "./theme";
import Flash from "./flash.hook";
import Details from "./details.hook";
import ResizableDrawer from "./resizable-drawer.hook";
import LocalTime from "./local_time.hook";
import NavPanel, { applyNavState } from "./nav-panel.hook";
import Tabs from "./tabs.hook";
import Tree from "./tree.hook";

applyNavState();
applyTheme(getInitialTheme());

let socketPath =
  document.querySelector("html").getAttribute("phx-socket") || "/live";

const Hooks = {
  Mermaid: Mermaid,
  Viz: Viz,
  Tooltip: Tooltip,
  Settings: Settings,
  Flash: Flash,
  Details: Details,
  ResizableDrawer: ResizableDrawer,
  LocalTime: LocalTime,
  NavPanel: NavPanel,
  Tabs: Tabs,
  Tree: Tree,
};

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");
let liveSocket = new LiveView.LiveSocket(socketPath, Phoenix.Socket, {
  // A function, so each LiveView joins with the viewer's current settings.
  params: () => ({
    _csrf_token: csrfToken,
    user_agent: window.navigator.userAgent,
    theme: getInitialTheme(),
    linking: getLinking(),
    name_style: getNameStyle(),
  }),
  hooks: Hooks,
});

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
liveSocket.disableDebug();
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

// Copy to clipboard handler
window.addEventListener("clarity:copy-to-clipboard", (event) => {
  const content = event.detail.content;
  if (content) {
    navigator.clipboard.writeText(content).then(() => {
      // Show brief feedback through the button's hover hint
      const button = event.target;
      const originalHint = button.dataset.tooltipText;
      button.dataset.tooltipText = "Copied!";
      button.classList.add("text-green-500");
      setTimeout(() => {
        button.dataset.tooltipText = originalHint;
        button.classList.remove("text-green-500");
      }, 1500);
    });
  }
});