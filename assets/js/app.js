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
import ThemeToggle, { getInitialTheme } from "./theme.hook";
import Flash from "./flash.hook";
import Details from "./details.hook";
import ResizableDrawer from "./resizable-drawer.hook";

let socketPath =
  document.querySelector("html").getAttribute("phx-socket") || "/live";

const Hooks = {
  Mermaid: Mermaid,
  Viz: Viz,
  Tooltip: Tooltip,
  ThemeToggle: ThemeToggle,
  Flash: Flash,
  Details: Details,
  ResizableDrawer: ResizableDrawer,
};

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");

const VALID_ENGINES = [
  "dot", "neato", "fdp", "sfdp", "circo", "twopi", "osage"
];
const getInitialEngine = () => {
  const stored = localStorage.getItem("clarity-engine");
  return VALID_ENGINES.includes(stored) ? stored : "dot";
};

let liveSocket = new LiveView.LiveSocket(socketPath, Phoenix.Socket, {
  params: {
    _csrf_token: csrfToken,
    user_agent: window.navigator.userAgent,
    theme: getInitialTheme(),
    engine: getInitialEngine()
  },
  hooks: Hooks,
});

// connect if there are any LiveViews on the page
liveSocket.connect();

// Persist engine selection to localStorage when the server confirms a change.
window.addEventListener("phx:clarity:engine-changed", (event) => {
  const engine = event.detail && event.detail.engine;
  if (VALID_ENGINES.includes(engine)) {
    localStorage.setItem("clarity-engine", engine);
  }
});

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
      // Show brief feedback by changing button temporarily
      const button = event.target;
      const originalTitle = button.title;
      button.title = "Copied!";
      button.classList.add("text-green-500");
      setTimeout(() => {
        button.title = originalTitle;
        button.classList.remove("text-green-500");
      }, 1500);
    });
  }
});