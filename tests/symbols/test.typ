// tests/symbols — Symbol engine unit tests (compile-only)
//
// Tests the symbolic analysis operations: is-sat, is-tautology,
// support, and sat-count.

#import "/src/bdd.typ": build-bdd
#import "/src/symbols.typ": is-sat, is-tautology, support, sat-count

// ════════════════════════════════════════════════════════════════════════
// is-sat: satisfiability check
// ════════════════════════════════════════════════════════════════════════

#assert.eq(is-sat(build-bdd("x1 & x2")), true)
#assert.eq(is-sat(build-bdd("x1 | x2")), true)
#assert.eq(is-sat(build-bdd("x1")), true)
#assert.eq(is-sat(build-bdd("1")), true)
#assert.eq(is-sat(build-bdd("0")), false)               // contradiction
#assert.eq(is-sat(build-bdd("x1 & !x1")), false)        // contradiction
#assert.eq(is-sat(build-bdd("x1 | !x1")), true)         // tautology is also sat

// ════════════════════════════════════════════════════════════════════════
// is-tautology: always-true check
// ════════════════════════════════════════════════════════════════════════

#assert.eq(is-tautology(build-bdd("x1 | !x1")), true)   // excluded middle
#assert.eq(is-tautology(build-bdd("1")), true)
#assert.eq(is-tautology(build-bdd("0")), false)
#assert.eq(is-tautology(build-bdd("x1 & x2")), false)
#assert.eq(is-tautology(build-bdd("x1 | x2")), false)
#assert.eq(is-tautology(build-bdd("x1 & !x1")), false)

// Implication tautology: (a & (a => b)) => b
#assert.eq(is-tautology(build-bdd("(x1 & (x1 => x2)) => x2")), true)

// ════════════════════════════════════════════════════════════════════════
// support: functional variable support
// ════════════════════════════════════════════════════════════════════════

#assert.eq(support(build-bdd("x1 & x2")), ("x1", "x2"))
#assert.eq(support(build-bdd("x1")), ("x1",))
#assert.eq(support(build-bdd("1")), ())
#assert.eq(support(build-bdd("0")), ())

// x1 & (x2 | !x2) simplifies to x1 — x2 is NOT in support
#assert.eq(support(build-bdd("x1 & (x2 | !x2)")), ("x1",))

// x1 & !x1 = 0 — neither variable is in support
#assert.eq(support(build-bdd("x1 & !x1")), ())

// All variables are essential
#assert.eq(support(build-bdd("x1 & (x2 | !x3)")), ("x1", "x2", "x3"))

// ════════════════════════════════════════════════════════════════════════
// sat-count: count satisfying assignments
// ════════════════════════════════════════════════════════════════════════

#assert.eq(sat-count(build-bdd("x1 & x2")), 1)          // only (1,1)
#assert.eq(sat-count(build-bdd("x1 | x2")), 3)          // (0,1), (1,0), (1,1)
#assert.eq(sat-count(build-bdd("x1 ^ x2")), 2)          // (0,1), (1,0)
#assert.eq(sat-count(build-bdd("x1 | !x1")), 2)         // tautology: 2^1 = 2
#assert.eq(sat-count(build-bdd("x1 & !x1")), 0)         // contradiction
#assert.eq(sat-count(build-bdd("1")), 1)                 // 2^0 = 1 (no vars)
#assert.eq(sat-count(build-bdd("0")), 0)
#assert.eq(sat-count(build-bdd("x1")), 1)                // only x1=true
#assert.eq(sat-count(build-bdd("x1 => x2")), 3)         // all except (1,0)

// 3-variable expression: x1 & x2 & x3 has 1 of 8 assignments
#assert.eq(sat-count(build-bdd("x1 & x2 & x3")), 1)

// 3-variable expression: x1 | x2 | x3 has 7 of 8 assignments
#assert.eq(sat-count(build-bdd("x1 | x2 | x3")), 7)
