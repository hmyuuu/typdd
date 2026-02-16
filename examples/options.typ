// examples/options.typ — Custom labels, edge labels, and other options
#import "/lib.typ": bdd

#set page(width: auto, height: auto, margin: 1em)
#set text(font: "New Computer Modern", size: 10pt)

#grid(
  columns: 5,
  column-gutter: 2em,
  row-gutter: 1em,
  align: center + horizon,
  [*Edge labels*], [*Custom labels*], [*Custom nodes*], [*Bottom-up*], [*Compact*],
  bdd("x1 & (x2 | !x3)", show-edge-labels: true),
  bdd("x1 & (x2 | !x3)", show-edge-labels: ("T", "F")),
  bdd("a & (b | !c)", labels: (a: "🐶", b: "🐱", c:"🐟" ), style: "presentation"),
  bdd("x1 & (x2 | !x3)", direction: "BT"),
  bdd("(x1 & x2) | (x3 & x4)", compact: true, style: "curved", height: 2cm),
)
