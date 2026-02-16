// examples/expressions.typ — Multiple expressions in a grid
#import "/lib.typ": bdd

#set page(width: auto, height: auto, margin: 1em)
#set text(font: "New Computer Modern", size: 10pt)

#grid(
  columns: 4,
  column-gutter: 2em,
  row-gutter: 1em,
  align: center + horizon,
  [$ x_1 and x_2 $], [$ x_1 xor x_2 $], [$ x_1 arrow.r.double x_2 $], [$ (x_1 and x_2) or (x_3 and x_4) $],
  bdd("x1 & x2"),
  bdd("x1 ^ x2"),
  bdd("x1 => x2"),
  bdd("(x1 & x2) | (x3 & x4)",compact:true, style: "curved"),
)
