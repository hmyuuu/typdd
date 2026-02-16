// typdd/src/abstract.typ — Abstraction for large BDD visualization
//
// Provides subtree collapsing, level filtering, path highlighting,
// and statistics overlay.

/// Collapse subtrees below a given cut-level into summary nodes.
///
/// - bdd (dictionary): BDD with nodes, root, order
/// - cut-level (int): Level at which to cut (0-indexed from root)
/// -> dictionary: modified BDD with summary nodes
#let collapse-subtrees(bdd, cut-level) = {
  let order = bdd.order
  let nodes = bdd.nodes
  let root = bdd.root

  if cut-level >= order.len() {
    return bdd
  }

  // Build var-level map
  let var-level = (:)
  for (i, v) in order.enumerate() {
    var-level.insert(v, i)
  }

  // Build lookup
  let lookup = (:)
  for node in nodes {
    lookup.insert(str(node.id), node)
  }

  // Count subtree nodes for summary
  let _count-subtree(node-id, lookup) = {
    let node = lookup.at(str(node-id))
    if node.kind == "terminal" { 1 }
    else {
      1 + _count-subtree(node.low, lookup) + _count-subtree(node.high, lookup)
    }
  }

  // Collect nodes to keep (above cut level) and replace rest with summary nodes
  let new-nodes = ()
  let summary-id-counter = 10000
  let replaced = (:)  // old-id → new-summary-id

  for node in nodes {
    if node.kind == "terminal" {
      new-nodes += (node,)
    } else {
      let level = var-level.at(node.var)
      if level < cut-level {
        new-nodes += (node,)
      } else if level == cut-level {
        // Replace with summary node if not already replaced
        if str(node.id) not in replaced {
          let subtree-size = _count-subtree(node.id, lookup)
          let summary-node = (
            id: node.id,
            kind: "terminal",
            value: true,  // placeholder
          )
          new-nodes += (summary-node,)
          replaced.insert(str(node.id), node.id)
        }
      }
      // Nodes below cut level are dropped
    }
  }

  (nodes: new-nodes, root: root, order: order.slice(0, cut-level))
}

/// Filter BDD to show only selected variable levels.
///
/// - bdd (dictionary): BDD with nodes, root, order
/// - show-levels (array): Array of level indices to show
/// -> dictionary: filtered BDD
#let filter-levels(bdd, show-levels) = {
  let order = bdd.order
  let show-vars = show-levels.map(i => {
    if i < order.len() { order.at(i) } else { none }
  }).filter(v => v != none)

  // Keep only nodes at shown levels + terminals
  let new-nodes = bdd.nodes.filter(node => {
    if node.kind == "terminal" { true }
    else { node.var in show-vars }
  })

  (nodes: new-nodes, root: bdd.root, order: show-vars)
}

/// Generate a statistics overlay for a BDD.
///
/// - bdd (dictionary): BDD with nodes, root, order
/// -> dictionary with stats
#let bdd-stats(bdd) = {
  let var-nodes = bdd.nodes.filter(n => n.kind == "variable")
  let term-nodes = bdd.nodes.filter(n => n.kind == "terminal")

  // Count nodes per level
  let level-counts = (:)
  for node in var-nodes {
    let v = node.var
    if v in level-counts {
      level-counts.insert(v, level-counts.at(v) + 1)
    } else {
      level-counts.insert(v, 1)
    }
  }

  let max-width = 0
  for (v, count) in level-counts {
    if count > max-width { max-width = count }
  }

  (
    total-nodes: bdd.nodes.len(),
    variable-nodes: var-nodes.len(),
    terminal-nodes: term-nodes.len(),
    depth: bdd.order.len(),
    width: max-width,
    level-counts: level-counts,
    order: bdd.order,
  )
}
