// tests/integration — Full pipeline integration tests (compile-only)
//
// Tests the entire pipeline: parse → build → layout → render.
// Rendering tests verify that the pipeline doesn't panic; visual
// correctness is checked in the render test (separate).

#import "/lib.typ": bdd, bdd-from-json
#import "/src/parse.typ": parse, collect-vars
#import "/src/bdd.typ": build-bdd, node-count, sat-paths, substitute, evaluate
#import "/src/order.typ": dfs-order, weight-order, force-order
#import "/src/styles.typ": get-style
#import "/src/layout.typ": assign-positions
#import "/src/abstract.typ": bdd-stats, collapse-subtrees
#import "/src/import.typ": import-json

// ════════════════════════════════════════════════════════════════════════
// Oracle (same as bdd test, repeated so this file is self-contained)
// ════════════════════════════════════════════════════════════════════════

#let eval-bdd(bdd, assignment) = {
  let lookup = (:)
  for n in bdd.nodes { lookup.insert(str(n.id), n) }
  let cur = bdd.root
  let node = lookup.at(str(cur))
  while node.kind != "terminal" {
    cur = if assignment.at(node.var) { node.high } else { node.low }
    node = lookup.at(str(cur))
  }
  node.value
}

// ════════════════════════════════════════════════════════════════════════
// Pipeline smoke tests — each must not panic
// ════════════════════════════════════════════════════════════════════════

#set page(width: auto, height: auto, margin: 0.5em)

// These calls exercise parse → build → layout → render end-to-end.
// If any step panics, compilation fails.
#bdd("x1 & x2")
#bdd("x1 | x2")
#bdd("x1 ^ x2")
#bdd("x1 => x2")
#bdd("!x1")
#bdd("x1 & (x2 | !x3)")
#bdd("(x1 & x2) | (x3 & x4)")
#bdd("ite(x1, x2, x3)")
#bdd("x1 ~& x2")
#bdd("x1 ~| x2")
#bdd("x1 ~^ x2")
#bdd("1")
#bdd("0")

// All 4 styles
#for style in ("classic", "paper", "presentation", "curved") {
  bdd("x1 & x2", style: style)
}

// Options
#bdd("x1 & x2", show-edge-labels: true)
#bdd("x1 & x2", labels: (x1: "A", x2: "B"))

// Custom edge labels (array)
#bdd("x1 & (x2 | !x3)", show-edge-labels: ("T", "F"))
#bdd("x1 & x2", show-edge-labels: ("⊕", "⊖"))

// Height / width constraints (adjusts spacing, not zoom)
#bdd("(x1 & x2) | (x3 & x4)", height: 3cm)
#bdd("(x1 & x2) | (x3 & x4)", width: 6cm)
#bdd("(x1 & x2) | (x3 & x4)", height: 2cm, compact: true)

// Compact mode
#bdd("(x1 & x2) | (x3 & x4)", compact: true)

// Directions
#bdd("x1 & x2", direction: "BT")
#bdd("x1 & x2", direction: "LR")
#bdd("x1 & x2", direction: "RL")

// Large BDD (~20 variables) — must not panic or timeout
#bdd(
  "((x1 & x2) | (x3 & x4)) & ((x5 ^ x6) | (x7 & x8)) & ((x9 => x10) | (!x11 & x12)) & ((x13 | x14) & (x15 ^ x16)) & ((x17 & x18) | (x19 & x20))",
  compact: true,
  height: 10cm,
)

// ════════════════════════════════════════════════════════════════════════
// Layout produces valid positions for every node
// ════════════════════════════════════════════════════════════════════════

#{
  let data = build-bdd("x1 & (x2 | !x3)")
  let sty = get-style("classic")
  let pos = assign-positions(data, sty)

  // Every node id must have a position
  for n in data.nodes {
    assert(str(n.id) in pos, message: "Missing position for node " + str(n.id))
  }
}

// ════════════════════════════════════════════════════════════════════════
// Center-root: root node pinned to x=0
// ════════════════════════════════════════════════════════════════════════

#{ // Asymmetric expression: root must end up at x=0 with center-root: true
  let data = build-bdd("x1 & (x2 | !x3)")
  let sty = get-style("classic")
  let pos = assign-positions(data, sty, center-root: true)
  let root-pos = pos.at(str(data.root))
  assert.eq(root-pos.x, 0.0, message: "Root should be centered at x=0")
}

#{ // Symmetric expression
  let data = build-bdd("(x1 & x2) | (x3 & x4)")
  let sty = get-style("classic")
  let pos = assign-positions(data, sty, center-root: true)
  let root-pos = pos.at(str(data.root))
  assert.eq(root-pos.x, 0.0, message: "Root should be centered at x=0 for symmetric expr")
}

#{ // center-root: false should NOT necessarily put root at x=0
  let data = build-bdd("x1 & (x2 | !x3)")
  let sty = get-style("classic")
  let pos-centered = assign-positions(data, sty, center-root: true)
  let pos-uncentered = assign-positions(data, sty, center-root: false)
  // Both should produce valid positions for all nodes
  for n in data.nodes {
    assert(str(n.id) in pos-centered, message: "Missing position (centered)")
    assert(str(n.id) in pos-uncentered, message: "Missing position (uncentered)")
  }
}

// ════════════════════════════════════════════════════════════════════════
// Ordering: FORCE ≤ DFS for (x1&x2)|(x3&x4)  (classic adversarial case)
// ════════════════════════════════════════════════════════════════════════

#{
  let expr = "(x1 & x2) | (x3 & x4)"
  let ast = parse(expr)
  let dfs = dfs-order(ast)
  let f = force-order(ast)

  let bd = build-bdd(expr, order: dfs)
  let bf = build-bdd(expr, order: f)

  // FORCE should be at least as good (or equal) for this expression
  assert(node-count(bf) <= node-count(bd),
    message: "FORCE should not be worse than DFS for interleaved expression")
}

// ════════════════════════════════════════════════════════════════════════
// JSON import round-trip
// ════════════════════════════════════════════════════════════════════════

#{
  let data = (
    "schema_version": 1,
    "type": "bdd",
    "variables": ("x1", "x2"),
    "order": ("x1", "x2"),
    "complement_edges": false,
    "nodes": (
      ("id": 0, "type": "terminal", "value": 0),
      ("id": 1, "type": "terminal", "value": 1),
      ("id": 2, "type": "variable", "var": "x2", "low": 0, "high": 1),
      ("id": 3, "type": "variable", "var": "x1", "low": 0, "high": 2),
    ),
    "root": 3,
  )
  let imported = import-json(data)

  // Imported BDD should represent x1 & x2
  // Verify: (0,0)→0, (0,1)→0, (1,0)→0, (1,1)→1
  assert.eq(eval-bdd(imported, (x1: false, x2: false)), false)
  assert.eq(eval-bdd(imported, (x1: false, x2: true)),  false)
  assert.eq(eval-bdd(imported, (x1: true,  x2: false)), false)
  assert.eq(eval-bdd(imported, (x1: true,  x2: true)),  true)

  // And it renders without panic
  bdd-from-json(data)
}

// ════════════════════════════════════════════════════════════════════════
// Abstraction: bdd-stats
// ════════════════════════════════════════════════════════════════════════

#{
  let data = build-bdd("x1 & (x2 | !x3)")
  let stats = bdd-stats(data)

  assert(stats.total-nodes > 0)
  assert(stats.variable-nodes > 0)
  assert.eq(stats.depth, 3) // x1, x2, x3
}
