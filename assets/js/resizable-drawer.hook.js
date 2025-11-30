const ResizableDrawer = {
  mounted() {
    this.drawer = this.el;
    this.handle = this.el.querySelector("#raw-content-drawer-resize-handle");
    this.minWidth = parseInt(this.el.dataset.minWidth) || 400;
    this.maxWidth = parseInt(this.el.dataset.maxWidth) || 1200;
    this.defaultWidth = parseInt(this.el.dataset.defaultWidth) || 700;

    // Restore saved width or use default
    const savedWidth = localStorage.getItem("clarity:drawer-width");
    if (savedWidth) {
      const width = Math.min(Math.max(parseInt(savedWidth), this.minWidth), this.maxWidth);
      this.drawer.style.width = `${width}px`;
    }

    this.isResizing = false;
    this.startX = 0;
    this.startWidth = 0;

    this.handleMouseDown = this.handleMouseDown.bind(this);
    this.handleMouseMove = this.handleMouseMove.bind(this);
    this.handleMouseUp = this.handleMouseUp.bind(this);
    this.handleKeyDown = this.handleKeyDown.bind(this);

    this.handle.addEventListener("mousedown", this.handleMouseDown);
    document.addEventListener("keydown", this.handleKeyDown);
  },

  destroyed() {
    this.handle.removeEventListener("mousedown", this.handleMouseDown);
    document.removeEventListener("mousemove", this.handleMouseMove);
    document.removeEventListener("mouseup", this.handleMouseUp);
    document.removeEventListener("keydown", this.handleKeyDown);
  },

  handleKeyDown(e) {
    if (e.key === "Escape") {
      this.pushEvent("close_raw_drawer");
    }
  },

  handleMouseDown(e) {
    e.preventDefault();
    this.isResizing = true;
    this.startX = e.clientX;
    this.startWidth = this.drawer.offsetWidth;

    // Disable transition during resize for smooth dragging
    this.drawer.style.transition = "none";

    // Add a class to body to prevent text selection during drag
    document.body.classList.add("select-none");

    document.addEventListener("mousemove", this.handleMouseMove);
    document.addEventListener("mouseup", this.handleMouseUp);
  },

  handleMouseMove(e) {
    if (!this.isResizing) return;

    // Calculate new width (dragging left increases width since drawer is on right)
    const deltaX = this.startX - e.clientX;
    let newWidth = this.startWidth + deltaX;

    // Clamp to min/max
    newWidth = Math.min(Math.max(newWidth, this.minWidth), this.maxWidth);

    // Also clamp to viewport width minus some padding
    const maxViewportWidth = window.innerWidth - 100;
    newWidth = Math.min(newWidth, maxViewportWidth);

    this.drawer.style.width = `${newWidth}px`;
  },

  handleMouseUp() {
    if (!this.isResizing) return;

    this.isResizing = false;

    // Re-enable transition
    this.drawer.style.transition = "transform 0.3s ease-in-out";

    // Remove selection prevention
    document.body.classList.remove("select-none");

    // Save width preference
    localStorage.setItem("clarity:drawer-width", this.drawer.offsetWidth);

    document.removeEventListener("mousemove", this.handleMouseMove);
    document.removeEventListener("mouseup", this.handleMouseUp);
  }
};

export default ResizableDrawer;
