// typdd/src/order.typ — Variable ordering heuristics
//
// Provides default and heuristic-based variable orderings.

#import "parse.typ": collect-vars

/// Default DFS ordering: variables in the order they appear during
/// a depth-first traversal of the AST.
///
/// - ast (dictionary): AST node from parse()
/// -> array of strings
#let dfs-order(ast) = {
  collect-vars(ast)
}

/// Weight-based ordering: variables are ordered by frequency of occurrence
/// in the AST (most frequent first, as they likely benefit from being
/// closer to the root).
///
/// - ast (dictionary): AST node from parse()
/// -> array of strings
#let weight-order(ast) = {
  // Count occurrences
  let _count(ast) = {
    if ast.kind == "var" {
      let d = (:)
      d.insert(ast.name, 1)
      d
    } else if ast.kind == "const" {
      (:)
    } else if ast.kind == "not" {
      _count(ast.child)
    } else if ast.kind == "binop" {
      let l = _count(ast.left)
      let r = _count(ast.right)
      let merged = l
      for (k, v) in r {
        if k in merged {
          merged.insert(k, merged.at(k) + v)
        } else {
          merged.insert(k, v)
        }
      }
      merged
    } else if ast.kind == "ite" {
      let c = _count(ast.cond)
      let t = _count(ast.then-branch)
      let e = _count(ast.else-branch)
      let merged = c
      for (k, v) in t {
        if k in merged { merged.insert(k, merged.at(k) + v) }
        else { merged.insert(k, v) }
      }
      for (k, v) in e {
        if k in merged { merged.insert(k, merged.at(k) + v) }
        else { merged.insert(k, v) }
      }
      merged
    } else {
      (:)
    }
  }

  let counts = _count(ast)
  let vars = collect-vars(ast)

  // Sort by count (descending), tie-break by DFS order
  vars.sorted(key: v => {
    let count = if v in counts { counts.at(v) } else { 0 }
    -count
  })
}

/// FORCE algorithm: iterative variable ordering optimization.
///
/// FORCE uses hyperedge-based attraction to cluster related variables.
/// It iteratively moves variables toward the center-of-gravity of their
/// connected variables.
///
/// - ast (dictionary): AST node from parse()
/// - iterations (int): Number of FORCE iterations (default: 10)
/// -> array of strings
#let force-order(ast, iterations: 10) = {
  let vars = collect-vars(ast)
  if vars.len() <= 2 { return vars }

  // Build hyperedges: groups of variables that appear together in subexpressions
  let _collect-edges(ast) = {
    if ast.kind == "var" {
      ()
    } else if ast.kind == "const" {
      ()
    } else if ast.kind == "not" {
      _collect-edges(ast.child)
    } else if ast.kind == "binop" {
      let left-vars = collect-vars(ast.left)
      let right-vars = collect-vars(ast.right)
      // Hyperedge connecting left and right vars
      let edge-vars = ()
      let seen = (:)
      for v in left-vars + right-vars {
        if v not in seen {
          seen.insert(v, true)
          edge-vars += (v,)
        }
      }
      let sub-edges = _collect-edges(ast.left) + _collect-edges(ast.right)
      if edge-vars.len() >= 2 {
        sub-edges + (edge-vars,)
      } else {
        sub-edges
      }
    } else if ast.kind == "ite" {
      _collect-edges(ast.cond) + _collect-edges(ast.then-branch) + _collect-edges(ast.else-branch)
    } else {
      ()
    }
  }

  let edges = _collect-edges(ast)
  if edges.len() == 0 { return vars }

  // Initialize positions: equal spacing
  let positions = (:)
  for (i, v) in vars.enumerate() {
    positions.insert(v, float(i))
  }

  // FORCE iterations
  for _iter in range(iterations) {
    // Compute center of gravity for each edge
    let cogs = ()
    for edge in edges {
      let sum = 0.0
      for v in edge {
        sum += positions.at(v)
      }
      cogs += (sum / float(edge.len()),)
    }

    // For each variable, compute average COG of edges containing it
    let new-positions = (:)
    for v in vars {
      let total = 0.0
      let count = 0
      for (i, edge) in edges.enumerate() {
        if v in edge {
          total += cogs.at(i)
          count += 1
        }
      }
      if count > 0 {
        new-positions.insert(v, total / float(count))
      } else {
        new-positions.insert(v, positions.at(v))
      }
    }
    positions = new-positions
  }

  // Sort by final position
  vars.sorted(key: v => positions.at(v))
}
