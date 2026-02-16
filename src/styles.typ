// typdd/src/styles.typ — Style presets for BDD rendering
//
// Styles control visual appearance (colors, strokes, fills) only.
// Layout dimensions (node sizes, spacing) are shared across all styles
// and can be overridden via the `node-sep` / `level-sep` parameters.

// ════════════════════════════════════════════════════════════════════════
// Shared layout constants (same for all styles)
// ════════════════════════════════════════════════════════════════════════

#let _shared-layout = (
  var-shape: "circle",
  var-radius: 1.2em,
  var-text-size: 0.9em,
  term-shape: "rect",
  term-width: 1.6em,
  term-height: 1.2em,
  term-text-size: 0.9em,
  level-sep: 2.5em,
  node-sep: 2.5em,
  edge-mark: "stealth",
  complement-radius: 2.5pt,
  low-bend: 0deg,
  high-bend: 0deg,
)

// ════════════════════════════════════════════════════════════════════════
// Style presets (colors, strokes, fills only)
// ════════════════════════════════════════════════════════════════════════

/// Classic style: black & white, clean lines
#let classic-style = (
  .._shared-layout,
  var-fill: white,
  var-stroke: black,
  var-stroke-width: 0.8pt,
  var-text-fill: black,
  term-fill: white,
  term-stroke: black,
  term-stroke-width: 0.8pt,
  term-text-fill: black,
  high-stroke: black,
  high-stroke-width: 0.8pt,
  high-dash: "solid",
  low-stroke: black,
  low-stroke-width: 0.8pt,
  low-dash: "dashed",
  complement-fill: white,
  complement-stroke: black,
)

/// Paper style: thin lines, serif-friendly, grayscale
#let paper-style = (
  .._shared-layout,
  var-fill: white,
  var-stroke: luma(40),
  var-stroke-width: 0.5pt,
  var-text-fill: black,
  term-fill: luma(240),
  term-stroke: luma(40),
  term-stroke-width: 0.5pt,
  term-text-fill: black,
  high-stroke: luma(40),
  high-stroke-width: 0.5pt,
  high-dash: "solid",
  low-stroke: luma(120),
  low-stroke-width: 0.5pt,
  low-dash: "dashed",
  complement-fill: white,
  complement-stroke: luma(40),
)

/// Presentation style: academic colors, blue variables, green terminals
#let presentation-style = (
  .._shared-layout,
  var-fill: rgb("#e3f2fd"),
  var-stroke: rgb("#1565c0"),
  var-stroke-width: 0.8pt,
  var-text-fill: rgb("#0d47a1"),
  term-fill: white,
  term-stroke: black,
  term-stroke-width: 0.8pt,
  term-text-fill: black,
  high-stroke: rgb("#2e7d32"),
  high-stroke-width: 0.8pt,
  high-dash: "solid",
  low-stroke: rgb("#c62828"),
  low-stroke-width: 0.8pt,
  low-dash: "dashed",
  complement-fill: white,
  complement-stroke: rgb("#c62828"),
)

/// Curved style: curved edges, black lines, suitable for theses and textbooks
#let curved-style = (
  .._shared-layout,
  var-fill: white,
  var-stroke: black,
  var-stroke-width: 0.8pt,
  var-text-fill: black,
  term-fill: white,
  term-stroke: black,
  term-stroke-width: 0.8pt,
  term-text-fill: black,
  high-stroke: black,
  high-stroke-width: 0.8pt,
  high-dash: "solid",
  low-stroke: black,
  low-stroke-width: 0.8pt,
  low-dash: "dashed",
  low-bend: -15deg,
  high-bend: 15deg,
  complement-fill: white,
  complement-stroke: black,
)

/// Look up a style preset by name.
#let get-style(name) = {
  if name == "classic" { classic-style }
  else if name == "paper" { paper-style }
  else if name == "presentation" { presentation-style }
  else if name == "curved" { curved-style }
  else { panic("Unknown style preset: " + name + ". Use classic, paper, presentation, or curved.") }
}

/// Merge a custom style dictionary over a preset.
#let merge-style(preset-name, overrides) = {
  let base = get-style(preset-name)
  let result = base
  for (k, v) in overrides {
    result.insert(k, v)
  }
  result
}
