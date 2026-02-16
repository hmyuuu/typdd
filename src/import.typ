// typdd/src/import.typ — JSON import for BDD interchange format
//
// Converts JSON data (conforming to typdd interchange format) into
// the internal BDD representation used by the rendering pipeline.

/// Validate and convert a JSON BDD structure to internal format.
///
/// - data (dictionary): Parsed JSON object with schema_version, type, nodes, root, etc.
/// -> dictionary: (nodes: array, root: int, order: array)
#let import-json(data) = {
  // Validate schema version
  assert("schema_version" in data, message: "Missing 'schema_version' in JSON")
  assert(data.schema_version == 1, message: "Unsupported schema version: " + str(data.schema_version))

  // Validate type
  assert("type" in data, message: "Missing 'type' in JSON")
  assert(data.type == "bdd", message: "Only BDD type is currently supported, got: " + data.type)

  // Validate required fields
  assert("nodes" in data, message: "Missing 'nodes' in JSON")
  assert("root" in data, message: "Missing 'root' in JSON")

  let order = if "order" in data { data.order } else {
    if "variables" in data { data.variables } else { () }
  }

  let complement-edges = if "complement_edges" in data { data.complement_edges } else { false }

  // Build node id set for validation
  let node-ids = (:)
  for node in data.nodes {
    node-ids.insert(str(node.id), true)
  }

  // Convert nodes
  let internal-nodes = ()
  for node in data.nodes {
    if node.type == "terminal" {
      let value = if node.value == 1 { true } else { false }
      internal-nodes += ((id: node.id, kind: "terminal", value: value),)
    } else if node.type == "variable" {
      let low = node.low
      let high = node.high

      // Handle complement edges (negative refs)
      let low-complemented = false
      let high-complemented = false

      if complement-edges {
        if type(low) == int and low < 0 {
          low = -low
          low-complemented = true
        }
        if type(high) == int and high < 0 {
          high = -high
          high-complemented = true
        }
      }

      // Validate references
      assert(str(low) in node-ids, message: "Node " + str(node.id) + " references non-existent low child " + str(low))
      assert(str(high) in node-ids, message: "Node " + str(node.id) + " references non-existent high child " + str(high))

      let n = (id: node.id, kind: "variable", var: node.var, low: low, high: high)
      if low-complemented or high-complemented {
        // Add complement info for rendering
        let n = (
          id: node.id,
          kind: "variable",
          var: node.var,
          low: low,
          high: high,
          low-complemented: low-complemented,
          high-complemented: high-complemented,
        )
        internal-nodes += (n,)
      } else {
        internal-nodes += (n,)
      }
    } else {
      panic("Unknown node type: " + node.type)
    }
  }

  // Validate root reference
  assert(str(data.root) in node-ids, message: "Root references non-existent node " + str(data.root))

  (nodes: internal-nodes, root: data.root, order: order)
}
