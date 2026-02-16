// tests/bdd — BDD engine unit tests (compile-only)
//
// Key idea: verify BDD correctness via truth-table oracle — enumerate all
// 2^n assignments, evaluate both the AST and BDD, and assert they agree.

#import "/src/parse.typ": parse, collect-vars
#import "/src/bdd.typ": build-bdd, build, reduce, substitute, evaluate, node-count, sat-paths
#import "/src/order.typ": dfs-order, weight-order, force-order

// ════════════════════════════════════════════════════════════════════════
// Truth-table oracle: brute-force correctness check
// ════════════════════════════════════════════════════════════════════════

/// Evaluate a BDD for a specific variable assignment.
/// assignment: dictionary (var-name → bool)
#let eval-bdd(bdd, assignment) = {
  let lookup = (:)
  for n in bdd.nodes { lookup.insert(str(n.id), n) }

  let cur = bdd.root
  let node = lookup.at(str(cur))
  while node.kind != "terminal" {
    let val = assignment.at(node.var)
    cur = if val { node.high } else { node.low }
    node = lookup.at(str(cur))
  }
  node.value
}

/// Cross-validate: for every row in the truth table, the BDD and
/// the direct AST evaluator must agree.
#let verify-bdd(expr, order: none) = {
  let ast = parse(expr)
  let vars = collect-vars(ast)
  let var-order = if order != none { order } else { vars }
  let bdd = build-bdd(expr, order: var-order)
  let n = vars.len()
  let total = calc.pow(2, n)

  for i in range(total) {
    // Build assignment from bit pattern
    let assignment = (:)
    for (j, v) in vars.enumerate() {
      // bit (n-1-j) of i
      let bit = calc.rem(calc.quo(i, calc.pow(2, n - 1 - j)), 2) == 1
      assignment.insert(v, bit)
    }

    let ast-result = evaluate(
      vars.fold(ast, (a, v) => substitute(a, v, assignment.at(v)))
    )
    let bdd-result = eval-bdd(bdd, assignment)

    assert.eq(
      bdd-result, ast-result,
      message: "Mismatch for " + expr + " with " + repr(assignment),
    )
  }
}

// ════════════════════════════════════════════════════════════════════════
// Substitute
// ════════════════════════════════════════════════════════════════════════

#{
  let ast = parse("x1 & x2")
  assert.eq(substitute(ast, "x1", true).kind,  "var")   // simplifies to x2
  assert.eq(substitute(ast, "x1", true).name,  "x2")
  assert.eq(substitute(ast, "x1", false).kind, "const") // simplifies to false
  assert.eq(substitute(ast, "x1", false).value, false)
}

#{
  let ast = parse("x1 | x2")
  assert.eq(substitute(ast, "x1", true).value, true)    // short-circuits to true
  assert.eq(substitute(ast, "x1", false).kind, "var")   // simplifies to x2
}

#assert.eq(substitute(parse("!x1"), "x1", true).value, false)
#assert.eq(substitute(parse("!x1"), "x1", false).value, true)

// ════════════════════════════════════════════════════════════════════════
// Build — structural properties
// ════════════════════════════════════════════════════════════════════════

// Single variable: 2 terminals + 1 variable = 3 nodes
#assert.eq(build-bdd("x1").nodes.len(), 3)
#assert.eq(node-count(build-bdd("x1")), 1)

// x1 & x1 ≡ x1  →  same variable-node count
#assert.eq(node-count(build-bdd("x1 & x1")), node-count(build-bdd("x1")))

// x1 & x2: 2 terminals + 2 variable nodes
#assert.eq(build-bdd("x1 & x2").nodes.len(), 4)
#assert.eq(sat-paths(build-bdd("x1 & x2")).len(), 1)    // only (1,1)

// x1 ^ x2: 2 satisfying BDD-paths
#assert.eq(sat-paths(build-bdd("x1 ^ x2")).len(), 2)

// Constants fold to a single terminal
#assert.eq(build-bdd("1").nodes.len(), 2)  // just two terminals
#assert.eq(build-bdd("0").nodes.len(), 2)

// Reduction is idempotent
#{
  let b = build-bdd("x1 & (x2 | !x3)")
  assert.eq(reduce(b).nodes.len(), b.nodes.len())
}

// ════════════════════════════════════════════════════════════════════════
// Truth-table oracle — every expression below is exhaustively verified
// ════════════════════════════════════════════════════════════════════════

#verify-bdd("x1")
#verify-bdd("!x1")
#verify-bdd("x1 & x2")
#verify-bdd("x1 | x2")
#verify-bdd("x1 ^ x2")
#verify-bdd("x1 => x2")
#verify-bdd("x1 ~& x2")
#verify-bdd("x1 ~| x2")
#verify-bdd("x1 ~^ x2")
#verify-bdd("x1 & (x2 | !x3)")
#verify-bdd("(x1 & x2) | (x3 & x4)")
#verify-bdd("ite(x1, x2, x3)")
#verify-bdd("x1 & x2 & x3")
#verify-bdd("x1 | x2 | x3")
#verify-bdd("!x1 & !x2")
#verify-bdd("x1 ^ x2 ^ x3")
#verify-bdd("(x1 => x2) & (x2 => x3)")

// Also verify with non-default orderings
#verify-bdd("x1 & (x2 | !x3)", order: ("x3", "x2", "x1"))
#verify-bdd("x1 & (x2 | !x3)", order: ("x2", "x3", "x1"))
#verify-bdd("(x1 & x2) | (x3 & x4)", order: ("x4", "x3", "x2", "x1"))

// ════════════════════════════════════════════════════════════════════════
// Ordering
// ════════════════════════════════════════════════════════════════════════

#assert.eq(dfs-order(parse("x3 & x1 & x2")), ("x3", "x1", "x2"))
#assert.eq(dfs-order(parse("x1")), ("x1",))
#assert.eq(dfs-order(parse("1")), ())

// weight-order should place most-frequent first
#{
  let w = weight-order(parse("x1 & x2 & x1 & x3 & x1"))
  assert.eq(w.first(), "x1")
}

// FORCE should return all variables
#{
  let f = force-order(parse("x1 & (x2 | x3) & x4"))
  assert.eq(f.sorted(), ("x1", "x2", "x3", "x4").sorted())
}
