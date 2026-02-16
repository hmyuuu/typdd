// tests/render — Visual rendering tests (compile-only)
//
// Verifies all rendering pipelines don't panic. Visual correctness
// can be promoted to persistent tests later with `tt update render`.

#import "/lib.typ": bdd

#set page(width: auto, height: auto, margin: 1em)
#set text(font: "New Computer Modern")

= typdd Rendering Tests

== Simple: x1 & x2

#bdd("x1 & x2")

== Reference: x1 & (x2 | !x3)

#bdd("x1 & (x2 | !x3)")

== Classic Style (default)

#bdd("x1 & x2", style: "classic")

== Paper Style

#bdd("x1 & x2", style: "paper")

== Presentation Style

#bdd("x1 & x2", style: "presentation")

== Curved Style

#bdd("x1 & x2", style: "curved")

== Custom Labels

#bdd("x1 & x2", labels: (x1: "A", x2: "B"))

== XOR

#bdd("x1 ^ x2")

== Single Variable

#bdd("x1")

== Constant True

#bdd("1")

== Edge Labels (bool)

#bdd("x1 & x2", show-edge-labels: true)

== Edge Labels (custom array)

#bdd("x1 & (x2 | !x3)", show-edge-labels: ("T", "F"))
#bdd("x1 & x2", show-edge-labels: ("⊕", "⊖"))
#bdd("x1 ^ x2", show-edge-labels: ("+", "-"))

== Height constraint

#bdd("(x1 & x2) | (x3 & x4)", height: 3cm)
#bdd("x1 & (x2 | !x3)", height: 5em)

== Width constraint

#bdd("(x1 & x2) | (x3 & x4)", width: 8cm)

== Height + compact

#bdd("(x1 & x2) | (x3 & x4)", compact: true, height: 2cm)

== Compact mode

#bdd("(x1 & x2) | (x3 & x4)", compact: true)
#bdd("x1 & (x2 | !x3)", compact: true)

== Directions

#bdd("x1 & x2", direction: "BT")
#bdd("x1 & x2", direction: "LR")
#bdd("x1 & x2", direction: "RL")

== Scale
#bdd("x1 & x2", scale: 0.5)
#bdd("x1 & x2", scale: 1.1)



== Large BDD (20 variables, compact)

#bdd(
  "((x1 & x2) | (x3 & x4)) & ((x5 ^ x6) | (x7 & x8)) & ((x9 => x10) | (!x11 & x12)) & ((x13 | x14) & (x15 ^ x16)) & ((x17 & x18) | (x19 & x20))",

  compact: true,
  // height: 12cm,
  // style: "paper",
  style: "curved",
)

#[*All rendering tests complete.*]
