// typdd/src/symbols.typ — Symbolic analysis for BDD structures
//
// Operates on reduced BDD dictionaries returned by build-bdd().
// These are structural queries on the BDD graph, not AST operations.

#import "bdd.typ": sat-paths

/// Check if a BDD represents a satisfiable function (has at least
/// one satisfying assignment).
///
/// A reduced BDD is satisfiable iff its root is not the 0-terminal.
///
/// - bdd (dictionary): BDD from build-bdd()
/// -> bool
#let is-sat(bdd) = {
  bdd.root != 0
}

/// Check if a BDD represents a tautology (all assignments satisfy).
///
/// A reduced BDD is a tautology iff its root is the 1-terminal.
///
/// - bdd (dictionary): BDD from build-bdd()
/// -> bool
#let is-tautology(bdd) = {
  bdd.root == 1
}

/// Get the functional support: the set of variables that actually
/// influence the function's output.
///
/// Unlike collect-vars (which returns syntactic variables from an
/// expression string), support returns only variables that appear
/// as decision nodes in the reduced BDD. A variable absent from
/// the reduced BDD is vacuous — its value never changes the output.
///
/// Results are returned in variable-ordering sequence.
///
/// - bdd (dictionary): Reduced BDD from build-bdd()
/// -> array of strings
#let support(bdd) = {
  let seen = (:)
  for node in bdd.nodes {
    if node.kind == "variable" {
      seen.insert(node.var, true)
    }
  }
  bdd.order.filter(v => v in seen)
}

/// Count the number of satisfying assignments for a BDD.
///
/// Each root-to-1 path of length k through a BDD with n variables
/// represents 2^(n-k) satisfying assignments (unconstrained variables
/// can take either value).
///
/// - bdd (dictionary): BDD from build-bdd()
/// -> int
#let sat-count(bdd) = {
  let n = bdd.order.len()
  let paths = sat-paths(bdd)
  let total = 0
  for path in paths {
    total += calc.pow(2, n - path.len())
  }
  total
}
