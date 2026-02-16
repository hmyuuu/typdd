---
name: typdd-dev
description: Use when modifying typdd library source code, adding operators or styles, fixing layout or rendering, writing tests, or debugging BDD construction.
argument-hint: <what to add, fix, or change>
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

# typdd-dev

Develop the typdd Typst library — a BDD visualization package built on fletcher.

## Architecture

Pipeline: `parse → build → reduce → layout → render`

| File | Role | Key functions |
|------|------|---------------|
| `lib.typ` | Public API, adaptive spacing | `bdd()`, `bdd-from-json()` |
| `src/parse.typ` | Tokenizer + recursive descent parser | `tokenize()`, `parse()`, `collect-vars()` |
| `src/bdd.typ` | Shannon expansion, unique table, reduction | `build-bdd()`, `build()`, `reduce()`, `substitute()` |
| `src/layout.typ` | Sugiyama-inspired layered layout | `assign-positions()` |
| `src/render.typ` | Fletcher diagram generation | `render-bdd()` (uses `node()`, `edge()`) |
| `src/styles.typ` | Visual presets + shared layout constants | `get-style()`, `merge-style()`, `_shared-layout` |
| `src/order.typ` | Variable ordering heuristics | `dfs-order()`, `weight-order()`, `force-order()` |
| `src/abstract.typ` | Subtree collapsing, stats | `collapse-subtrees()`, `bdd-stats()` |
| `src/import.typ` | JSON interchange import | `import-json()` |

MCP server (`typdd-mcp/`): TypeScript mirror of parser/BDD engine with tools/prompts.

## Recipes

| Task | Files to touch |
|------|---------------|
| New operator | `src/parse.typ` (tokenizer + grammar) → `src/bdd.typ` (evaluate + substitute) → `tests/parse/test.typ` + `tests/bdd/test.typ` |
| New style | `src/styles.typ` (spread `_shared-layout`, colors/strokes only) → `get-style()` match → `examples/styles.typ` |
| Layout fix | `src/layout.typ` (barycenter, overlap resolution, centering) |
| Render change | `src/render.typ` (fletcher `node()`/`edge()`, stroke/fill/bend) |
| New API param | `lib.typ` (add to `bdd()` sig + `_render-pipeline()`) |
| JSON import | `src/import.typ` → `tests/integration/test.typ` |

## Data Structures

**AST nodes** (from parser):
```
(kind: "var", name: "x1")
(kind: "const", value: true/false)
(kind: "not", child: ast)
(kind: "binop", op: "&"|"|"|"^"|"=>"|"~&"|"~|"|"~^", left: ast, right: ast)
(kind: "ite", cond: ast, then-branch: ast, else-branch: ast)
```

**BDD structure**: `(nodes: array, root: int, order: array)` where each node is `(id: int, kind: "terminal", value: bool)` or `(id: int, kind: "variable", var: str, low: int, high: int)`.

**Unique table key**: `"var:low-id:high-id"` — ensures canonical BDD nodes.

## Test

```bash
make test       # 4 Typst (tytanic) + MCP (bun test)
make typst      # Typst tests only: tt run
make mcp        # MCP tests only: cd typdd-mcp && bun test
make examples   # Rebuild PNGs
```

Tests are compile-time asserts — if any `#assert.eq(...)` fails, compilation exits non-zero. BDD correctness is verified via truth-table oracle (enumerate all 2^n assignments).

## Rules

- **Styles**: colors/strokes only, never layout dims (those live in `_shared-layout`)
- **Typst conventions**: kebab-case, `///` doc comments, absolute imports (`/src/...`)
- **AST keys**: `then-branch`/`else-branch` (not `then`/`else`)
- **State threading**: parser and builder return `(result: ..., pos: ...)` / `(node-id: ..., nodes: ..., next-id: ..., unique-table: ...)`
- **No forward declarations**: parser uses single `_parse(tokens, pos, level)` with level parameter to select grammar rule
- **Grammar precedence** (low→high): `=>` → `|`/`~|` → `^`/`~^` → `&`/`~&` → `!`
