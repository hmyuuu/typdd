// typdd — Decision Diagram Visualization for Typst
//
// Public API:
//   #import "@preview/typdd:0.1.0": bdd, bdd-from-json

#import "src/parse.typ": parse, collect-vars, tokenize
#import "src/bdd.typ": build-bdd, build, reduce, substitute, node-count, sat-paths
#import "src/order.typ": dfs-order, weight-order
#import "src/layout.typ": assign-positions
#import "src/styles.typ": get-style, merge-style
#import "src/render.typ": render-bdd
#import "src/import.typ": import-json
#import "src/symbols.typ": is-sat, is-tautology, support, sat-count

// Alias built-in scale before parameter shadowing
#let _typst-scale = scale

// ════════════════════════════════════════════════════════════════════════
// Internal: adaptive spacing
// ════════════════════════════════════════════════════════════════════════

/// Compute adaptive level-sep based on BDD depth.
/// Deeper BDDs get tighter vertical spacing to stay compact.
#let _auto-level-sep(depth, base-sep, compact) = {
  if compact {
    // Compact mode: aggressively tight
    if depth <= 2 { base-sep * 0.45 }
    else if depth <= 4 { base-sep * 0.35 }
    else { base-sep * 0.25 }
  } else {
    // Normal mode: gradually tighten for deeper BDDs
    if depth <= 2 { base-sep }
    else if depth <= 4 { base-sep * 0.8 }
    else if depth <= 6 { base-sep * 0.65 }
    else { base-sep * 0.55 }
  }
}

#let _auto-node-sep(depth, base-sep, compact) = {
  if compact {
    if depth <= 2 { base-sep * 0.45 }
    else if depth <= 4 { base-sep * 0.35 }
    else { base-sep * 0.3 }
  } else {
    if depth <= 3 { base-sep }
    else if depth <= 5 { base-sep * 0.85 }
    else { base-sep * 0.7 }
  }
}

// ════════════════════════════════════════════════════════════════════════
// Internal: shared render pipeline
// ════════════════════════════════════════════════════════════════════════

#let _render-pipeline(
  bdd-data,
  style-name,
  show-complement,
  show-edge-labels,
  labels,
  width,
  height,
  direction,
  user-scale,
  user-node-sep,
  user-level-sep,
  compact,
  center-root,
) = {
  let sty = get-style(style-name)
  let depth = bdd-data.order.len()

  // Compute effective spacing
  let effective-level-sep = if user-level-sep != auto {
    user-level-sep
  } else {
    _auto-level-sep(depth, sty.level-sep, compact)
  }
  let effective-node-sep = if user-node-sep != auto {
    user-node-sep
  } else {
    _auto-node-sep(depth, sty.node-sep, compact)
  }

  // Smart height: back-calculate level-sep to hit target height
  // Total height ≈ depth * level-sep + top_half + bottom_half
  // where top_half = var-radius, bottom_half = term-height / 2
  if height != auto and depth > 0 {
    let node-overhead = sty.var-radius + sty.term-height / 2
    effective-level-sep = (height - node-overhead) / depth
  }

  // Smart width: back-calculate node-sep to hit target width
  // First we need the x-span from layout, but layout needs node-sep...
  // So we do a preliminary layout to find the x-span, then adjust node-sep.
  if width != auto and depth > 0 {
    let prelim-overrides = (:)
    prelim-overrides.insert("level-sep", effective-level-sep)
    prelim-overrides.insert("node-sep", 1em)  // unit spacing for measurement
    let prelim-sty = merge-style(style-name, prelim-overrides)
    let prelim-pos = assign-positions(bdd-data, prelim-sty, direction: direction, center-root: center-root)
    // Find x-span in abstract coordinates
    let xs = prelim-pos.values().map(p => p.x)
    let x-span = calc.max(..xs) - calc.min(..xs)
    if x-span > 0 {
      let node-overhead = sty.var-radius * 2
      effective-node-sep = (width - node-overhead) / x-span
    }
  }

  let overrides = (:)
  overrides.insert("level-sep", effective-level-sep)
  overrides.insert("node-sep", effective-node-sep)
  let final-sty = merge-style(style-name, overrides)
  let positions = assign-positions(bdd-data, final-sty, direction: direction, center-root: center-root)

  let dia = render-bdd(
    bdd-data,
    positions,
    style-name: style-name,
    style-overrides: overrides,
    show-complement: show-complement,
    show-edge-labels: show-edge-labels,
    labels: labels,
    dia-width: auto,
  )

  if user-scale != 1.0 {
    _typst-scale(dia, x: user-scale * 100%, y: user-scale * 100%, origin: top)
  } else {
    dia
  }
}

// ════════════════════════════════════════════════════════════════════════
// Public API
// ════════════════════════════════════════════════════════════════════════

/// Parse and build a BDD from a boolean expression, then render it as a diagram.
///
/// - expr (str): Boolean expression (e.g., "x1 & (x2 | !x3)")
/// - order (array, none): Variable ordering override. Default: DFS order from AST.
/// - style (str): Style preset name ("classic", "paper", "presentation", "curved")
/// - show-complement (bool): Show complement edge bubbles (CUDD-style)
/// - show-edge-labels (bool, array): Show edge labels. `true` for 0/1, or array `(high-label, low-label)` e.g. `("+", "-")`
/// - reduced (bool): Apply BDD reduction (default: true)
/// - width (auto, length): Target diagram width — adjusts node-sep to fit
/// - height (auto, length): Target diagram height — adjusts level-sep to fit
/// - labels (dictionary): Variable label overrides (e.g., (x1: "input_A"))
/// - direction (str): Layout direction: "TB", "BT", "LR", "RL"
/// - scale (float): Uniform scale factor for the diagram (default: 1.0)
/// - node-sep (auto, length): Override horizontal spacing between nodes
/// - level-sep (auto, length): Override vertical spacing between levels
/// - compact (bool): Use compact layout with tighter spacing (default: false)
/// - center-root (bool): Center diagram on root node (default: true)
/// -> content
#let bdd(
  expr,
  order: none,
  style: "classic",
  show-complement: false,
  show-edge-labels: false,
  reduced: true,
  width: auto,
  height: auto,
  labels: (:),
  direction: "TB",
  scale: 1.0,
  node-sep: auto,
  level-sep: auto,
  compact: false,
  center-root: true,
) = {
  let bdd-data = build-bdd(expr, order: order, do-reduce: reduced)
  _render-pipeline(
    bdd-data,
    style,
    show-complement,
    show-edge-labels,
    labels,
    width,
    height,
    direction,
    scale,
    node-sep,
    level-sep,
    compact,
    center-root,
  )
}

/// Import a BDD from a JSON structure and render it.
///
/// - data (dictionary): Parsed JSON object conforming to typdd interchange format
/// - style (str): Style preset name
/// - scale (float): Uniform scale factor for the diagram (default: 1.0)
/// - node-sep (auto, length): Override horizontal spacing between nodes
/// - level-sep (auto, length): Override vertical spacing between levels
/// - compact (bool): Use compact layout with tighter spacing (default: false)
/// - center-root (bool): Center diagram on root node (default: true)
/// -> content
#let bdd-from-json(
  data,
  style: "classic",
  show-complement: false,
  show-edge-labels: false,
  width: auto,
  height: auto,
  labels: (:),
  direction: "TB",
  scale: 1.0,
  node-sep: auto,
  level-sep: auto,
  compact: false,
  center-root: true,
) = {
  let bdd-data = import-json(data)
  _render-pipeline(
    bdd-data,
    style,
    show-complement,
    show-edge-labels,
    labels,
    width,
    height,
    direction,
    scale,
    node-sep,
    level-sep,
    compact,
    center-root,
  )
}
