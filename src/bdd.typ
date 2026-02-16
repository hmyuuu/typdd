// typdd/src/bdd.typ — BDD construction engine
//
// BDD data structure: (nodes: array, root: int, order: array, vars: array)
//   nodes[i] = (id: int, kind: "terminal", value: bool)
//            | (id: int, kind: "variable", var: str, low: int, high: int)
//
// State threading:  (nodes: .., next-id: .., unique-table: ..)
//
// unique-table key format: "var:low:high" → node-id

#import "parse.typ": parse, collect-vars

// ════════════════════════════════════════════════════════════════════════
// AST evaluation helpers
// ════════════════════════════════════════════════════════════════════════

/// Substitute a variable in an AST with a constant value.
/// Returns a simplified AST.
#let substitute(ast, var, value) = {
  if ast.kind == "var" {
    if ast.name == var {
      (kind: "const", value: value)
    } else {
      ast
    }
  } else if ast.kind == "const" {
    ast
  } else if ast.kind == "not" {
    let child = substitute(ast.child, var, value)
    if child.kind == "const" {
      (kind: "const", value: not child.value)
    } else {
      (kind: "not", child: child)
    }
  } else if ast.kind == "binop" {
    let left = substitute(ast.left, var, value)
    let right = substitute(ast.right, var, value)

    // constant propagation
    if ast.op == "&" {
      if left.kind == "const" and left.value == false { (kind: "const", value: false) }
      else if left.kind == "const" and left.value == true { right }
      else if right.kind == "const" and right.value == false { (kind: "const", value: false) }
      else if right.kind == "const" and right.value == true { left }
      else { (kind: "binop", op: ast.op, left: left, right: right) }
    } else if ast.op == "|" {
      if left.kind == "const" and left.value == true { (kind: "const", value: true) }
      else if left.kind == "const" and left.value == false { right }
      else if right.kind == "const" and right.value == true { (kind: "const", value: true) }
      else if right.kind == "const" and right.value == false { left }
      else { (kind: "binop", op: ast.op, left: left, right: right) }
    } else if ast.op == "^" {
      if left.kind == "const" and right.kind == "const" {
        (kind: "const", value: left.value != right.value)
      } else if left.kind == "const" and left.value == false { right }
      else if right.kind == "const" and right.value == false { left }
      else if left.kind == "const" and left.value == true { (kind: "not", child: right) }
      else if right.kind == "const" and right.value == true { (kind: "not", child: left) }
      else { (kind: "binop", op: ast.op, left: left, right: right) }
    } else if ast.op == "=>" {
      // a => b ≡ !a | b
      if left.kind == "const" and left.value == false { (kind: "const", value: true) }
      else if left.kind == "const" and left.value == true { right }
      else if right.kind == "const" and right.value == true { (kind: "const", value: true) }
      else if right.kind == "const" and right.value == false { (kind: "not", child: left) }
      else { (kind: "binop", op: ast.op, left: left, right: right) }
    } else if ast.op == "~&" {
      // NAND = !(a & b)
      if left.kind == "const" and left.value == false { (kind: "const", value: true) }
      else if left.kind == "const" and left.value == true { (kind: "not", child: right) }
      else if right.kind == "const" and right.value == false { (kind: "const", value: true) }
      else if right.kind == "const" and right.value == true { (kind: "not", child: left) }
      else { (kind: "binop", op: ast.op, left: left, right: right) }
    } else if ast.op == "~|" {
      // NOR = !(a | b)
      if left.kind == "const" and left.value == true { (kind: "const", value: false) }
      else if left.kind == "const" and left.value == false { (kind: "not", child: right) }
      else if right.kind == "const" and right.value == true { (kind: "const", value: false) }
      else if right.kind == "const" and right.value == false { (kind: "not", child: left) }
      else { (kind: "binop", op: ast.op, left: left, right: right) }
    } else if ast.op == "~^" {
      // XNOR = !(a ^ b) = a == b
      if left.kind == "const" and right.kind == "const" {
        (kind: "const", value: left.value == right.value)
      } else if left.kind == "const" and left.value == true { right }
      else if right.kind == "const" and right.value == true { left }
      else if left.kind == "const" and left.value == false { (kind: "not", child: right) }
      else if right.kind == "const" and right.value == false { (kind: "not", child: left) }
      else { (kind: "binop", op: ast.op, left: left, right: right) }
    } else {
      (kind: "binop", op: ast.op, left: left, right: right)
    }
  } else if ast.kind == "ite" {
    let cond = substitute(ast.cond, var, value)
    let then-br = substitute(ast.then-branch, var, value)
    let else-br = substitute(ast.else-branch, var, value)

    if cond.kind == "const" {
      if cond.value { then-br } else { else-br }
    } else {
      (kind: "ite", cond: cond, then-branch: then-br, else-branch: else-br)
    }
  } else {
    ast
  }
}

/// Evaluate an AST with all variables substituted to constants.
/// Returns true or false. Panics if variables remain.
#let evaluate(ast) = {
  if ast.kind == "const" {
    ast.value
  } else if ast.kind == "var" {
    panic("Cannot evaluate: variable '" + ast.name + "' has no value")
  } else if ast.kind == "not" {
    not evaluate(ast.child)
  } else if ast.kind == "binop" {
    let l = evaluate(ast.left)
    let r = evaluate(ast.right)
    if ast.op == "&" { l and r }
    else if ast.op == "|" { l or r }
    else if ast.op == "^" { l != r }
    else if ast.op == "=>" { (not l) or r }
    else if ast.op == "~&" { not (l and r) }
    else if ast.op == "~|" { not (l or r) }
    else if ast.op == "~^" { l == r }
    else { panic("Unknown operator: " + ast.op) }
  } else if ast.kind == "ite" {
    let c = evaluate(ast.cond)
    if c { evaluate(ast.then-branch) } else { evaluate(ast.else-branch) }
  } else {
    panic("Unknown AST kind: " + ast.kind)
  }
}

// ════════════════════════════════════════════════════════════════════════
// BDD Construction — Shannon expansion with unique table
// ════════════════════════════════════════════════════════════════════════

/// Build a BDD from an AST using Shannon expansion.
///
/// - ast (dictionary): AST from parse()
/// - order (array): Variable ordering (list of variable name strings)
/// -> dictionary: (nodes: array, root: int, order: array)
#let build(ast, order) = {
  // Terminal nodes: 0 (false) at id=0, 1 (true) at id=1
  let nodes = (
    (id: 0, kind: "terminal", value: false),
    (id: 1, kind: "terminal", value: true),
  )
  let next-id = 2
  let unique-table = (:)

  // Shannon expansion: recursively split on each variable
  // Returns: (node-id: int, nodes: array, next-id: int, unique-table: dict)
  let _build-rec(ast, var-idx, order, state) = {
    // If we've exhausted all variables, evaluate the constant
    if var-idx >= order.len() {
      // All variables should be substituted; evaluate
      let val = evaluate(ast)
      let id = if val { 1 } else { 0 }
      (node-id: id, nodes: state.nodes, next-id: state.next-id, unique-table: state.unique-table)
    } else {
      let var = order.at(var-idx)

      // Cofactor: substitute var=false and var=true
      let low-ast = substitute(ast, var, false)
      let high-ast = substitute(ast, var, true)

      // Recurse on next variable
      let low-state = _build-rec(low-ast, var-idx + 1, order, state)
      let high-state = _build-rec(high-ast, var-idx + 1, order, (
        nodes: low-state.nodes,
        next-id: low-state.next-id,
        unique-table: low-state.unique-table,
      ))

      let low-id = low-state.node-id
      let high-id = high-state.node-id

      // Skip redundant node: if low == high, no decision needed
      if low-id == high-id {
        (node-id: low-id, nodes: high-state.nodes, next-id: high-state.next-id, unique-table: high-state.unique-table)
      } else {
        // Check unique table for existing node
        let key = var + ":" + str(low-id) + ":" + str(high-id)
        if key in high-state.unique-table {
          let existing-id = high-state.unique-table.at(key)
          (node-id: existing-id, nodes: high-state.nodes, next-id: high-state.next-id, unique-table: high-state.unique-table)
        } else {
          // Create new node
          let new-node = (id: high-state.next-id, kind: "variable", var: var, low: low-id, high: high-id)
          let new-nodes = high-state.nodes + (new-node,)
          let new-table = high-state.unique-table
          new-table.insert(key, high-state.next-id)
          (node-id: high-state.next-id, nodes: new-nodes, next-id: high-state.next-id + 1, unique-table: new-table)
        }
      }
    }
  }

  let init-state = (nodes: nodes, next-id: next-id, unique-table: unique-table)
  let result = _build-rec(ast, 0, order, init-state)

  (nodes: result.nodes, root: result.node-id, order: order)
}

// ════════════════════════════════════════════════════════════════════════
// BDD Reduction — merge isomorphic subtrees, remove redundant nodes
// ════════════════════════════════════════════════════════════════════════

/// Reduce a BDD by merging isomorphic subtrees and removing redundant nodes.
///
/// - bdd (dictionary): BDD from build()
/// -> dictionary: reduced BDD
#let reduce(bdd) = {
  let nodes = bdd.nodes
  let root = bdd.root

  // Build a lookup table: id → node
  let lookup = (:)
  for node in nodes {
    lookup.insert(str(node.id), node)
  }

  // Bottom-up reduction using signature-based merging
  // signature = "T:value" for terminals, "V:var:low-sig-id:high-sig-id" for variables
  let sig-map = (:)       // signature → new-id
  let id-remap = (:)      // old-id → new-id
  let new-nodes = ()
  let new-next-id = 0

  // Process terminals first
  for node in nodes {
    if node.kind == "terminal" {
      let sig = "T:" + if node.value { "1" } else { "0" }
      if sig not in sig-map {
        let new-node = (id: new-next-id, kind: "terminal", value: node.value)
        new-nodes += (new-node,)
        sig-map.insert(sig, new-next-id)
        id-remap.insert(str(node.id), new-next-id)
        new-next-id += 1
      } else {
        id-remap.insert(str(node.id), sig-map.at(sig))
      }
    }
  }

  // Process variable nodes in order of their level (deepest first)
  // Sort by variable ordering depth (reverse order for bottom-up)
  let order = bdd.order
  let var-level = (:)
  for (i, v) in order.enumerate() {
    var-level.insert(v, i)
  }

  // Collect variable nodes and sort by level (deepest first)
  let var-nodes = nodes.filter(n => n.kind == "variable")
  let sorted-var-nodes = var-nodes.sorted(key: n => {
    let level = if n.var in var-level { var-level.at(n.var) } else { 999 }
    -level  // negative for reverse sort (deepest first)
  })

  for node in sorted-var-nodes {
    let low-new = id-remap.at(str(node.low))
    let high-new = id-remap.at(str(node.high))

    // Skip redundant: low == high means this variable doesn't matter
    if low-new == high-new {
      id-remap.insert(str(node.id), low-new)
    } else {
      let sig = "V:" + node.var + ":" + str(low-new) + ":" + str(high-new)
      if sig not in sig-map {
        let new-node = (id: new-next-id, kind: "variable", var: node.var, low: low-new, high: high-new)
        new-nodes += (new-node,)
        sig-map.insert(sig, new-next-id)
        id-remap.insert(str(node.id), new-next-id)
        new-next-id += 1
      } else {
        id-remap.insert(str(node.id), sig-map.at(sig))
      }
    }
  }

  let new-root = id-remap.at(str(root))
  (nodes: new-nodes, root: new-root, order: bdd.order)
}

// ════════════════════════════════════════════════════════════════════════
// Public API
// ════════════════════════════════════════════════════════════════════════

/// Build a BDD from a boolean expression string.
///
/// - expr (str): Boolean expression
/// - order (array, none): Variable ordering. Default: DFS order from AST.
/// - do-reduce (bool): Apply reduction (default: true)
/// -> dictionary: (nodes: array, root: int, order: array)
#let build-bdd(expr, order: none, do-reduce: true) = {
  let ast = parse(expr)
  let vars = collect-vars(ast)
  let var-order = if order != none { order } else { vars }

  // Validate: order must contain all variables
  for v in vars {
    if v not in var-order {
      panic("Variable '" + v + "' appears in expression but not in ordering")
    }
  }

  assert(var-order.len() <= 20, message: "Too many variables (max 20, got " + str(var-order.len()) + ")")

  let bdd = build(ast, var-order)
  if do-reduce { reduce(bdd) } else { bdd }
}

/// Get the number of non-terminal nodes in a BDD.
#let node-count(bdd) = {
  bdd.nodes.filter(n => n.kind == "variable").len()
}

/// Get all paths from root to terminal-1 in a BDD.
#let sat-paths(bdd) = {
  let lookup = (:)
  for node in bdd.nodes {
    lookup.insert(str(node.id), node)
  }

  let _collect(node-id, path, lookup) = {
    let node = lookup.at(str(node-id))
    if node.kind == "terminal" {
      if node.value { (path,) } else { () }
    } else {
      let low-paths = _collect(node.low, path + ((var: node.var, value: false),), lookup)
      let high-paths = _collect(node.high, path + ((var: node.var, value: true),), lookup)
      low-paths + high-paths
    }
  }

  _collect(bdd.root, (), lookup)
}
