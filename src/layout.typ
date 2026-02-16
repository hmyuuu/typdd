// typdd/src/layout.typ — Layered layout engine for BDD diagrams
//
// Implements a Sugiyama-inspired layout with:
// 1. Rank assignment by variable level
// 2. Barycenter crossing minimization
// 3. Coordinate refinement (center parents over children)
// 4. Overlap resolution

/// Assign layout positions to BDD nodes.
///
/// Returns a dictionary: node-id (as string) → (x: float, y: int)
///
/// - bdd (dictionary): BDD with nodes, root, order
/// - style (dictionary): Style with level-sep, node-sep
/// - direction (str): Layout direction: "TB", "BT", "LR", "RL"
/// - center-root (bool): Center the diagram on the root node (default: true)
/// -> dictionary
#let assign-positions(bdd, style, direction: "TB", center-root: true) = {
  let nodes = bdd.nodes
  let root = bdd.root
  let order = bdd.order

  // Build lookup: id → node
  let lookup = (:)
  for node in nodes {
    lookup.insert(str(node.id), node)
  }

  // Build level map: variable name → level index
  let var-level = (:)
  for (i, v) in order.enumerate() {
    var-level.insert(v, i)
  }

  let term-level = order.len()

  // ── Step 1: Assign levels ──
  let levels = (:)  // level-key → array of node ids
  for node in nodes {
    let level = if node.kind == "terminal" { term-level }
    else { var-level.at(node.var) }
    let level-key = str(level)
    if level-key in levels {
      levels.insert(level-key, levels.at(level-key) + (node.id,))
    } else {
      levels.insert(level-key, (node.id,))
    }
  }

  // ── Step 2: Build adjacency for barycenter ──
  // parent map: child-id → array of parent ids
  let children-of = (:)  // parent-id → (low-id, high-id)
  let parents-of = (:)   // child-id → array of parent ids
  for node in nodes {
    if node.kind == "variable" {
      children-of.insert(str(node.id), (node.low, node.high))
      for child-id in (node.low, node.high) {
        let ck = str(child-id)
        if ck in parents-of {
          parents-of.insert(ck, parents-of.at(ck) + (node.id,))
        } else {
          parents-of.insert(ck, (node.id,))
        }
      }
    }
  }

  // ── Step 3: Initial x-positions ──
  let positions = (:)
  for (level-key, node-ids) in levels {
    let n = node-ids.len()
    for (i, nid) in node-ids.enumerate() {
      let x = if n == 1 { 0.0 } else { float(i) - float(n - 1) / 2.0 }
      positions.insert(str(nid), (x: x, y: int(level-key)))
    }
  }

  // ── Step 4: Barycenter crossing minimization ──
  // Multiple passes: top-down then bottom-up
  let level-keys = range(term-level + 1).map(i => str(i))

  for _pass in range(4) {
    // Top-down pass
    for lk in level-keys {
      if lk not in levels { continue }
      let node-ids = levels.at(lk)
      if node-ids.len() <= 1 { continue }

      // Compute barycenter: average x of parents
      let barycenters = (:)
      for nid in node-ids {
        let nk = str(nid)
        if nk in parents-of {
          let parent-ids = parents-of.at(nk)
          let sum = 0.0
          for pid in parent-ids {
            sum += positions.at(str(pid)).x
          }
          barycenters.insert(nk, sum / float(parent-ids.len()))
        } else {
          barycenters.insert(nk, positions.at(nk).x)
        }
      }

      // Sort by barycenter
      let sorted = node-ids.sorted(key: nid => barycenters.at(str(nid)))

      // Assign new x positions
      let n = sorted.len()
      for (i, nid) in sorted.enumerate() {
        let x = if n == 1 { 0.0 } else { float(i) - float(n - 1) / 2.0 }
        positions.insert(str(nid), (x: x, y: int(lk)))
      }
      levels.insert(lk, sorted)
    }

    // Bottom-up pass
    for lk in level-keys.rev() {
      if lk not in levels { continue }
      let node-ids = levels.at(lk)
      if node-ids.len() <= 1 { continue }

      // Compute barycenter from children
      let barycenters = (:)
      for nid in node-ids {
        let nk = str(nid)
        if nk in children-of {
          let children = children-of.at(nk)
          let sum = 0.0
          let count = 0
          for cid in children {
            sum += positions.at(str(cid)).x
            count += 1
          }
          if count > 0 {
            barycenters.insert(nk, sum / float(count))
          } else {
            barycenters.insert(nk, positions.at(nk).x)
          }
        } else {
          barycenters.insert(nk, positions.at(nk).x)
        }
      }

      let sorted = node-ids.sorted(key: nid => barycenters.at(str(nid)))
      let n = sorted.len()
      for (i, nid) in sorted.enumerate() {
        let x = if n == 1 { 0.0 } else { float(i) - float(n - 1) / 2.0 }
        positions.insert(str(nid), (x: x, y: int(lk)))
      }
      levels.insert(lk, sorted)
    }
  }

  // ── Step 5: Coordinate refinement — pull toward avg child x ──
  for _pass in range(3) {
    for node in nodes {
      if node.kind == "variable" {
        let low-pos = positions.at(str(node.low))
        let high-pos = positions.at(str(node.high))
        let avg-x = (low-pos.x + high-pos.x) / 2.0
        let my-pos = positions.at(str(node.id))
        // Blend current with ideal
        let new-x = my-pos.x * 0.3 + avg-x * 0.7
        positions.insert(str(node.id), (x: new-x, y: my-pos.y))
      }
    }

    // Resolve overlaps within each level
    for (level-key, node-ids) in levels {
      if node-ids.len() <= 1 { continue }
      let sorted = node-ids.sorted(key: nid => positions.at(str(nid)).x)
      // Terminal gap: √depth — starts small, grows sublinearly
      let min-gap = if int(level-key) == term-level {
        calc.sqrt(float(term-level/2))
      } else {
        1.0
      }
      for i in range(1, sorted.len()) {
        let prev-x = positions.at(str(sorted.at(i - 1))).x
        let cur-pos = positions.at(str(sorted.at(i)))
        if cur-pos.x - prev-x < min-gap {
          positions.insert(str(sorted.at(i)), (x: prev-x + min-gap, y: cur-pos.y))
        }
      }
      // Re-center each level around its own midpoint
      let xs = sorted.map(nid => positions.at(str(nid)).x)
      let mid = (xs.first() + xs.last()) / 2.0
      for nid in sorted {
        let p = positions.at(str(nid))
        positions.insert(str(nid), (x: p.x - mid, y: p.y))
      }
    }
  }

  // ── Step 6: Global centering ──
  // center-root: true  → shift so root (top level) is at x=0
  // center-root: false → keep as-is (each level centered on own midpoint)
  if center-root {
    let root-x = positions.at(str(root)).x
    if root-x != 0.0 {
      for (nid-key, pos) in positions {
        positions.insert(nid-key, (x: pos.x - root-x, y: pos.y))
      }
    }
  }

  // ── Step 7: Direction transformation ──
  if direction == "BT" {
    let max-y = term-level
    for (nid-key, pos) in positions {
      positions.insert(nid-key, (x: pos.x, y: max-y - pos.y))
    }
  } else if direction == "LR" {
    for (nid-key, pos) in positions {
      positions.insert(nid-key, (x: pos.y, y: pos.x))
    }
  } else if direction == "RL" {
    let max-y = term-level
    for (nid-key, pos) in positions {
      positions.insert(nid-key, (x: max-y - pos.y, y: pos.x))
    }
  }

  positions
}
