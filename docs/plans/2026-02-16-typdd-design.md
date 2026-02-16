# typdd — Decision Diagram Visualization Toolchain

**Date:** 2026-02-16
**Status:** Reviewed & Finalized

## 1. Overview

A three-component toolchain for visualizing Binary Decision Diagrams (BDDs) and future ADD variants:

1. **Typst Library (`typdd`)** — Standalone Typst package for rendering BDDs in academic documents
2. **MCP Server (`typdd-mcp`)** — Interactive DD builder for AI-assisted workflows
3. **Agent Skill (`typdd`)** — Full DD assistant skill (orchestration + theory)

**Architecture:** Typst-Native with MCP Augmentation. Typst handles BDD construction + rendering for small diagrams (≤8 variables). MCP handles computation for larger diagrams. Typst always handles rendering via `fletcher`.

### 1.1 Performance Boundaries

| Scale | Engine | Rendering |
|-------|--------|-----------|
| ≤8 variables | Pure Typst (parse + build + reduce) | Typst/fletcher |
| 9-20 variables | MCP server (build) → JSON → Typst (render) | Typst/fletcher |
| >20 variables | Rejected (MAX_VARIABLES = 20). Suggest abstraction or decomposition. | — |

### 1.2 Safety Limits

```
MAX_VARIABLES = 20          # Hard limit for BDD construction
MAX_EXPRESSION_LENGTH = 1000
MAX_NODES = 100,000
BUILD_TIMEOUT_MS = 5000
MAX_STORED_BDDS = 50        # Per MCP session, LRU eviction
```

## 2. Typst Library (`typdd`)

### 2.1 Module Structure

```
typdd/
├── typst.toml              # Package manifest
├── lib.typ                 # Public API entry point
├── src/
│   ├── parse.typ           # Boolean expression parser (tokenizer + recursive descent)
│   ├── bdd.typ             # BDD construction (Shannon expansion, apply, reduce)
│   ├── order.typ           # Variable ordering heuristics (DFS, weight-based, FORCE)
│   ├── layout.typ          # Layered layout engine (Sugiyama-inspired, rank by variable level)
│   ├── render.typ          # Drawing via fletcher (nodes, edges, labels, styling)
│   ├── abstract.typ        # Abstraction for large BDDs (collapse subtrees, cut-levels)
│   ├── styles.typ          # Theme presets + customization API
│   └── import.typ          # JSON import for interop with CUDD/BuDDy (DOT parsing handled by MCP)
```

### 2.2 Rendering Foundation

**Built on `fletcher`** (not raw CeTZ), because:
- `fletcher` provides `node()` / `edge()` DAG primitives — BDDs are DAGs, not trees
- Supports absolute coordinates, named nodes, multiple edges to same node
- Supports custom node shapes, edge marks, bending, labels
- Built on CeTZ, so we get full drawing power underneath

### 2.3 Public API

```typst
#import "@preview/typdd:0.1.0": bdd, bdd-from-json

// Simple: one-liner from boolean expression
#bdd("x1 & (x2 | !x3)")

// With options
#bdd(
  "x1 & (x2 | !x3)",
  order: ("x3", "x1", "x2"),       // override variable order
  style: "paper",                    // preset theme
  show-complement: true,             // show complement edges (CUDD-style bubble notation)
  reduced: true,                     // apply BDD reduction (default: true)
  width: 60%,                        // diagram width
  labels: (x1: "input_A"),           // rename variable labels
)

// From pre-computed structure (MCP output or external tool)
#bdd-from-json(json("my-bdd.json"))

// DOT import: use MCP server's import_dot tool to convert DOT → JSON first,
// then render via bdd-from-json. DOT parsing is too complex for pure Typst.
```

### 2.4 Expression Syntax

| Operator | Symbol | Example |
|----------|--------|---------|
| AND      | `&`    | `x1 & x2` |
| OR       | `\|`   | `x1 \| x2` |
| NOT      | `!`    | `!x1` |
| XOR      | `^`    | `x1 ^ x2` |
| IMPLIES  | `=>`   | `x1 => x2` |
| NAND     | `~&`   | `x1 ~& x2` |
| NOR      | `~\|`  | `x1 ~\| x2` |
| XNOR     | `~^`   | `x1 ~^ x2` |
| ITE      | `ite(c,t,f)` | `ite(x1, x2, x3)` |

Variables: alphanumeric identifiers (`x1`, `a`, `input_valid`)
Parentheses for grouping. Standard precedence: NOT > AND > XOR > OR > IMPLIES.

### 2.5 Visual Conventions (TikZ-compatible defaults)

Following established academic conventions from LaTeX/TikZ BDD drawings:

| Element | Default Style | Customizable |
|---------|---------------|-------------|
| Variable nodes | Circle, draw, solid border | fill, stroke, radius, label-font |
| Terminal nodes | Square/rectangle, draw, solid border | shape (square/circle), labels ("0"/"1" or "⊥"/"⊤") |
| High edge (1) | Solid line, stealth arrow | color, stroke-width, arrow-mark |
| Low edge (0) | Dashed line, stealth arrow | color, stroke-width, dash-pattern |
| Complement edge | Bubble marker (○) on the edge (CUDD convention). Solid/dashed distinction preserved — bubble is additive. | color, bubble-size, bubble-position |
| Layout | Top-to-bottom, one variable per level | direction (TB/BT/LR/RL), level-sep, node-sep |
| Edge labels | Optional "0"/"1" labels | position, font-size |

### 2.6 Layout Engine

Custom layered layout (Sugiyama-inspired):
1. **Rank assignment**: Each variable gets a level/rank (determined by variable ordering)
2. **Crossing minimization**: Barycenter heuristic to reduce edge crossings
3. **Coordinate assignment**: Position nodes within each rank to minimize edge length
4. **Edge routing**: Straight lines for short edges, bezier curves for long-span edges
5. **Shared node handling**: Reduced BDD nodes shared across branches are positioned once and connected from multiple parents

Note: Implemented iteratively (not recursively) where possible to avoid Typst stack depth limits.

### 2.7 Abstraction for Large BDDs

- **Subtree collapsing**: Replace subtrees below a cut-level with a summary node (e.g., "⋯ 12 nodes")
- **Level filtering**: Show only selected variable levels, collapsing intermediate levels
- **Highlight paths**: Emphasize specific input→output paths through the BDD
- **Statistics overlay**: Show node count, path count, variable influence
- **Cone of influence**: Show only the subgraph relevant to selected output variables

### 2.8 Built-in Style Presets

- `"classic"` — Standard textbook BDD (black/white, circle/square)
- `"paper"` — Optimized for academic papers (compact, thin lines, small fonts)
- `"presentation"` — Bold colors and large nodes for slides
- `"colorful"` — Color-coded by variable level

## 3. MCP Server (`typdd-mcp`)

### 3.1 Technology

- **Runtime**: Bun (per user preference)
- **Protocol**: MCP (Model Context Protocol) over stdio
- **Language**: TypeScript
- **SDK**: `@modelcontextprotocol/sdk` (use `McpServer` high-level API)

### 3.2 Tools

All tools that operate on a BDD take an explicit `bdd_id` parameter. No "current BDD" concept.

| Tool | Description | Input | Output |
|------|-------------|-------|--------|
| `validate_expression` | Parse and validate boolean expression | `{ expr: string }` | `{ valid, ast, variables, errors?, suggestions? }` |
| `build_bdd` | Build reduced BDD from expression | `{ expr: string, order?: string[], id?: string }` | `{ bdd_id, structure, root, stats }` |
| `set_ordering` | Reorder variables of a BDD | `{ bdd_id: string, order: string[] }` | `{ bdd_id, structure, stats }` |
| `get_stats` | Get BDD statistics | `{ bdd_id: string }` | `{ nodes, paths, width, depth }` |
| `suggest_ordering` | Suggest optimal variable ordering | `{ expr: string }` | `{ suggested: string[], size: number }` |
| `render_typst` | Generate Typst source code | `{ bdd_id: string, style?: string, options?: object }` | Typst source string |
| `compare_orderings` | Compare multiple orderings | `{ expr: string, orderings: string[][] }` | Comparison table |
| `apply_op` | Apply binary operation to two BDDs | `{ op: string, bdd1_id: string, bdd2_id: string, result_id?: string }` | `{ bdd_id, structure, stats }` |
| `export_dot` | Export BDD to DOT format | `{ bdd_id: string }` | DOT string |
| `highlight_path` | Highlight a specific input path | `{ bdd_id: string, assignment: object }` | Highlighted BDD |
| `quick_render` | Expression → Typst in one call | `{ expr: string, order?: string[], style?: string, format: "typst"\|"dot"\|"both" }` | `{ typst?, dot?, bdd_id, stats }` |
| `evaluate_bdd` | Evaluate BDD for an assignment | `{ bdd_id: string, assignment: object }` | `{ result: 0\|1, path: node[] }` |
| `truth_table` | Generate truth table | `{ bdd_id: string }` | `{ table: row[], variables: string[] }` |
| `list_bdds` | List all stored BDDs | `{}` | `{ bdds: [{ id, expression, node_count, variables }] }` |
| `delete_bdd` | Delete a stored BDD | `{ bdd_id: string }` | `{ deleted: boolean }` |
| `restrict_bdd` | Cofactor (restrict variable) | `{ bdd_id: string, var: string, value: 0\|1 }` | `{ bdd_id, structure, stats }` |
| `is_equivalent` | Check if two BDDs are equivalent | `{ bdd1_id: string, bdd2_id: string }` | `{ equivalent: boolean, distinguishing_input?: object }` |
| `satisfying_count` | Count satisfying assignments | `{ bdd_id: string }` | `{ count: number, total: number, ratio: number }` |
| `import_dot` | Parse DOT format into BDD | `{ dot: string, id?: string }` | `{ bdd_id, structure, stats }` |

### 3.3 Resources

| Resource | Description |
|----------|-------------|
| `bdd://list` | List of all BDD IDs with brief metadata |
| `bdd://{id}/structure` | BDD structure as JSON |
| `bdd://{id}/typst` | BDD as Typst source |
| `bdd://{id}/dot` | BDD as DOT format |
| `bdd://{id}/stats` | BDD statistics |
| `bdd://{id}/info` | Metadata (expression, variable count, creation time) |

Resource subscriptions: Emit `notifications/resources/updated` when `set_ordering` or `apply_op` mutates a BDD.

### 3.4 Session State

The MCP server maintains session state:
- Multiple named BDDs in memory (`Map<string, BDD>`)
- LRU eviction at MAX_STORED_BDDS (50)
- Style passed as parameters per-call (no stored preferences)

### 3.5 Prompt Templates

```typescript
"visualize-bdd"     // Expression → build → stats → render
"compare-orderings" // Expression → suggest orderings → compare sizes → explain best
"explain-bdd"       // Expression → build → step-by-step Shannon expansion → truth table → reduced BDD
```

### 3.6 Error Handling

All errors use `isError: true` with structured JSON:

```json
{
  "error": "PARSE_ERROR",
  "message": "Unexpected token ')' at position 12",
  "position": 12,
  "context": "x1 & (x2 |)",
  "suggestion": "Did you mean 'x1 & (x2 | x3)'?"
}
```

Error categories: `PARSE_ERROR`, `UNKNOWN_VARIABLE`, `BDD_NOT_FOUND`, `ORDERING_MISMATCH`, `SIZE_LIMIT_EXCEEDED`, `TIMEOUT`, `INVALID_OPERATION`.

## 4. Agent Skill (`typdd`)

### 4.1 Skill Type

**Flexible with rigid checkpoints** — adapts DD theory to user's research context, but enforces validation at key points.

Rigid checkpoints (never skip):
1. Validate expression syntax before building
2. Validate variable ordering completeness
3. Verify Typst output compiles (if typst CLI available)
4. Confirm before overwriting user's existing content

### 4.2 Capabilities

**Orchestration:**
- Detect when user wants a DD visualization (natural language → MCP tool calls)
- Chain MCP tools: validate → build → optimize ordering → render
- Embed generated Typst code in documents
- Track conversation context (named BDDs, last shown, user preferences)

**DD Theory Advisor:**
- Explain BDD properties (canonicity, reduction rules, Shannon expansion)
- Suggest variable orderings based on function structure
- Analyze BDD complexity and suggest simplifications
- Compare different DD representations (BDD vs ADD vs ZDD)
- Explain equivalence checking, functional composition

### 4.3 Trigger Patterns

```
Explicit:     "BDD", "decision diagram", "ROBDD", "ZDD", "ADD", "EVBDD", "MDD"
Expression:   Boolean expressions with operators (&, |, !, ^, =>) when context suggests visualization
Task:         "variable ordering", "Shannon expansion", "reduce", "node count", "satisfiable"
Workflow:     "truth table to diagram", "import DOT", "export to Typst"
Comparative:  "compare orderings", "which ordering", "side by side"
```

Negative triggers (NOT this skill): "binary decision" in project management, "decision tree" for ML classifiers.

### 4.4 Workflow

```
User request → Parse intent →
  If visualization: validate → build → render → verify compile → present
  If theory question: reason about DD properties → explain
  If optimization: suggest orderings → compare → present best
  If multi-step: orchestrate sequence (see 4.6)
```

### 4.5 Output Presentation

1. If user is editing a `.typ` file → insert Typst source at cursor; add import if missing
2. If user is exploring → compile to PNG (if typst CLI available) + show source
3. If comparing multiple BDDs → grid layout with side-by-side rendering
4. Always include stats summary (nodes, levels, width) and expression used

### 4.6 Multi-Step Workflow Templates

**Ordering exploration:**
1. Build with default ordering → show stats
2. Try `suggest_ordering` → build with suggested → show stats
3. Side-by-side comparison
4. User picks winner → render final

**Function composition:**
1. Build BDD for each sub-function
2. Apply operation → show intermediate and final
3. Optionally render all in single figure with subfigures

**Equivalence checking:**
1. Build BDDs for both expressions
2. Compare (canonical form comparison)
3. If not equivalent, show distinguishing input

### 4.7 Educational Depth Levels

- **Terse**: Diagram + stats only (default for experienced users)
- **Normal**: Diagram + stats + brief explanation
- **Detailed**: Step-by-step construction + reduction walkthrough + diagram
- **Teaching**: Full theory explanation with examples before building

Auto-detect from cues: "just show me" → Terse; "explain" / "how" / "why" → Detailed; "I'm learning" → Teaching.

### 4.8 Error Recovery

| Error | Response |
|-------|----------|
| Parse error | Show position, suggest corrections, offer operator syntax table |
| Ordering error | List valid variables, suggest fix |
| Size limit | Warn about blowup, suggest abstraction or different ordering |
| Typst compile failure | Parse error, suggest fix or fall back to source-only |
| MCP not available | Fall back to Typst-only mode (≤8 variables) |

### 4.9 Skill Interactions

- **Composable with**: `/brainstorm` (visualize candidates), `/write-plan` (execute visualization steps), `/tdd` (visual verification)
- **Boundary**: typdd handles ONLY DD-related tasks; yields to other skills for non-DD work

## 5. Data Flow

```
Boolean Expression (string)
    │
    ▼
┌─────────────┐
│ Validator    │ ← validate_expression (MCP) or parse.typ
│ (syntax +    │
│  var check)  │
└─────┬───────┘
      │ Validated AST
      ▼
┌─────────────┐
│ BDD Builder  │ ← bdd.typ (≤8 vars) or MCP build_bdd (>8 vars)
│ (Shannon exp, │
│  apply, reduce)│
└─────┬───────┘
      │ BDD structure (nodes + edges + bdd_id)
      ▼
┌─────────────┐
│ Layout       │ ← layout.typ
│ (Sugiyama    │
│  layered)    │
└─────┬───────┘
      │ Positioned nodes + routed edges
      ▼
┌─────────────┐
│ Renderer     │ ← render.typ (uses fletcher)
│ (nodes,edges,│
│  labels,style)│
└─────┬───────┘
      │
      ▼
┌─────────────┐
│ Verify       │ ← typst compile --check (if available)
└─────┬───────┘
      │
      ▼
  Typst diagram output
```

## 6. JSON Interchange Format

BDD structure exchanged between Typst lib and MCP:

```json
{
  "schema_version": 1,
  "type": "bdd",
  "variables": ["x1", "x2", "x3"],
  "order": ["x1", "x2", "x3"],
  "complement_edges": true,
  "nodes": [
    { "id": 0, "type": "terminal", "value": 0 },
    { "id": 1, "type": "terminal", "value": 1 },
    { "id": 2, "type": "variable", "var": "x3", "low": 0, "high": 1 },
    { "id": 3, "type": "variable", "var": "x2", "low": 0, "high": 2 },
    { "id": 4, "type": "variable", "var": "x1", "low": 3, "high": 2 }
  ],
  "root": 4
}
```

**Complement edge encoding (CUDD convention):** When `complement_edges` is `true`, negative node references indicate complemented edges. For example, `"high": -2` means "follow edge to node 2, but invert the result." This matches CUDD's pointer-based complement encoding. The renderer draws a bubble marker (○) on complemented edges.

### 6.1 ADD Extension Format

For ADD (Algebraic Decision Diagrams), terminals hold real values:

```json
{
  "schema_version": 1,
  "type": "add",
  "nodes": [
    { "id": 0, "type": "terminal", "value": 3.14 },
    { "id": 1, "type": "terminal", "value": 0.0 },
    { "id": 2, "type": "variable", "var": "x1", "low": 1, "high": 0 }
  ]
}
```

### 6.2 EVBDD Extension Format

For EVBDD (Edge-Valued BDDs), edges carry weights:

```json
{
  "schema_version": 1,
  "type": "evbdd",
  "nodes": [
    { "id": 0, "type": "terminal", "value": 0.0 },
    { "id": 1, "type": "variable", "var": "x1",
      "low": { "to": 0, "weight": 1.0 },
      "high": { "to": 0, "weight": 2.5 } }
  ]
}
```

- BDD: terminal `value` is `0 | 1`; edges may be complemented (negative node refs)
- ADD: terminal `value` is `number` (any real); no complement edges
- EVBDD: edges are objects `{ to, weight }` instead of plain node IDs
- ZDD: same format as BDD, different `type` field + reduction semantics
- MDD: variable nodes include `children: number[]` instead of `low/high`

## 7. Future Extensions (ADD Variants)

The architecture supports extension to:
- **ADD (Algebraic Decision Diagrams)**: Terminal nodes hold real values instead of {0,1}
- **EVBDD (Edge-Valued BDDs)**: Edges carry weights
- **ZDD (Zero-suppressed DDs)**: Different reduction rule
- **MDD (Multi-valued DDs)**: Nodes have >2 children

Extension points:
- `bdd.typ` → generalize to `dd.typ` with pluggable reduction rules
- JSON format: `type` field distinguishes variants; `value` accepts any type
- MCP tools: same interface, parameterized by DD type
- Renderer: `draw-node` / `draw-edge` callbacks handle variant-specific styling

## 8. Dependencies

| Component | Dependencies |
|-----------|-------------|
| Typst lib | `fletcher` (rendering), Typst ≥ 0.12 |
| MCP server | Bun, `@modelcontextprotocol/sdk` |
| Agent skill | Claude Code superpowers plugin system |

## 9. Success Criteria

1. `#bdd("x1 & (x2 | !x3)")` produces a correct, publication-quality ROBDD diagram
2. Variable ordering can be overridden and auto-optimized
3. MCP server allows interactive BDD construction and exploration via explicit `bdd_id`
4. Agent skill correctly orchestrates MCP tools from natural language with 5 trigger categories
5. Large BDDs (>15 variables) can be visualized with abstraction
6. Output matches academic conventions (circle/square/solid/dashed)
7. Structured error handling with actionable suggestions at every failure point
8. Educational depth adapts to user experience level
