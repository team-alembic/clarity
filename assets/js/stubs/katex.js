// Stands in for KaTeX, which Mermaid imports only to render `$$…$$` maths in
// labels. Clarity draws no maths, so it ships without KaTeX: a label's maths
// shows as its source text.
const escape = (text) =>
  String(text).replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);

export default {
  renderToString: (tex) => escape(tex),
};
