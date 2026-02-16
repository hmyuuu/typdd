// typdd/src/render.typ — BDD rendering via fletcher
//
// Converts BDD data structure + layout positions into a fletcher diagram.

#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge

#import "styles.typ": get-style, merge-style

/// Render a BDD as a fletcher diagram.
#let render-bdd(
  bdd,
  positions,
  style-name: "classic",
  style-overrides: (:),
  show-complement: false,
  show-edge-labels: false,
  labels: (:),
  dia-width: auto,
) = {
  let sty = if style-overrides.len() > 0 {
    merge-style(style-name, style-overrides)
  } else {
    get-style(style-name)
  }

  // Build lookup
  let lookup = (:)
  for n in bdd.nodes {
    lookup.insert(str(n.id), n)
  }

  // Build coordinate lookup
  let coords = (:)
  for n in bdd.nodes {
    let pos = positions.at(str(n.id))
    coords.insert(str(n.id), (pos.x, pos.y))
  }

  // Collect fletcher elements
  let elements = ()

  // Render nodes
  for n in bdd.nodes {
    let coord = coords.at(str(n.id))

    if n.kind == "terminal" {
      let lbl = if n.value { [1] } else { [0] }
      elements.push(node(
        coord,
        lbl,
        stroke: sty.term-stroke-width + sty.term-stroke,
        fill: sty.term-fill,
        shape: rect,
        width: sty.term-width,
        height: sty.term-height,
      ))
    } else {
      let var-label = if n.var in labels { labels.at(n.var) } else { n.var }
      elements.push(node(
        coord,
        text(fill: sty.var-text-fill, size: sty.var-text-size, var-label),
        stroke: sty.var-stroke-width + sty.var-stroke,
        fill: sty.var-fill,
        shape: fletcher.shapes.circle,
        radius: sty.var-radius,
      ))
    }
  }

  // Render edges
  for n in bdd.nodes {
    if n.kind == "variable" {
      let from = coords.at(str(n.id))
      let low-to = coords.at(str(n.low))
      let high-to = coords.at(str(n.high))

      // Check for complement edges (from JSON import)
      let low-comp = if "low-complemented" in n { n.low-complemented } else { false }
      let high-comp = if "high-complemented" in n { n.high-complemented } else { false }

      // Low edge (dashed)
      let low-label = if type(show-edge-labels) == array { [#show-edge-labels.at(1)] } else if show-edge-labels == true { [0] } else { none }
      let low-bend = if "low-bend" in sty { sty.low-bend } else { 0deg }
      elements.push(edge(
        from,
        low-to,
        marks: (none, sty.edge-mark),
        stroke: sty.low-stroke-width + sty.low-stroke,
        dash: sty.low-dash,
        label: low-label,
        label-side: right,
        bend: low-bend,
      ))

      // High edge (solid)
      let high-label = if type(show-edge-labels) == array { [#show-edge-labels.at(0)] } else if show-edge-labels == true { [1] } else { none }
      let high-bend = if "high-bend" in sty { sty.high-bend } else { 0deg }
      elements.push(edge(
        from,
        high-to,
        marks: (none, sty.edge-mark),
        stroke: sty.high-stroke-width + sty.high-stroke,
        dash: sty.high-dash,
        label: high-label,
        label-side: left,
        bend: high-bend,
      ))
    }
  }

  // Build diagram
  let d = diagram(
    spacing: (sty.node-sep, sty.level-sep),
    ..elements,
  )

  if dia-width != auto {
    box(width: dia-width, align(center, d))
  } else {
    d
  }
}
