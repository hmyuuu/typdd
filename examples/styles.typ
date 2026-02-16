// examples/styles.typ — All 4 style presets
#import "/lib.typ": bdd

#set page(width: auto, height: auto, margin: 1em)
#set text(font: "New Computer Modern", size: 10pt)

#grid(
  columns: 4,
  column-gutter: 2em,
  row-gutter: 1em,
  align: center + horizon,
  [*classic*], [*paper*], [*presentation*], [*curved*],
  bdd("x1 & (x2 | !x3)", style: "classic"),
  bdd("x1 & (x2 | !x3)", style: "paper"),
  bdd("x1 & (x2 | !x3)", style: "presentation"),
  bdd("x1 & (x2 | !x3)", style: "curved"),
)
