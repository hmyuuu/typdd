# AGENTS.md

## Skills

This project is a Claude Code plugin with two skills:

- **`/typdd`** — Create and customize BDD diagrams. Use this skill when working with the library as a user.
- **`/typdd-dev`** — Develop the typdd library itself. Use this skill when modifying source code, adding features, or fixing bugs.

Always invoke the appropriate skill before starting work.

<details>
<summary>Skill installation</summary>

```bash
# Add the marketplace (first time only)
/plugin marketplace add https://github.com/hmyuuu/typdd

# Install skills
/plugin install typdd
/plugin install typdd-dev
```

</details>

## Workflow

1. **Invoke the skill** — `/typdd` for usage, `/typdd-dev` for development
2. **Edit** — modify source in `src/`, examples in `examples/`, or tests in `tests/`
3. **Test** — `make test` (or `make typst` / `make mcp` individually)
4. **Rebuild examples** — `make examples` to update PNGs for README
5. **Commit** — include updated PNGs if examples changed

## Quick Commands

```bash
make test       # Run all tests (4 Typst + MCP)
make typst      # Typst tests only (tytanic: tt run)
make mcp        # MCP tests only (cd typdd-mcp && bun test)
make examples   # Rebuild example PNGs
make install    # Install dependencies (bun + tytanic)
make clean      # Remove build artifacts
```

## Architecture

Pipeline: `parse → build → reduce → layout → render`

```
lib.typ              # Public API: bdd(), bdd-from-json()
src/
  parse.typ          # Tokenizer + recursive descent parser
  bdd.typ            # Shannon expansion, unique table, reduction
  layout.typ         # Sugiyama-inspired layered layout
  render.typ         # Fletcher diagram generation
  styles.typ         # Visual presets + shared layout constants
  order.typ          # Variable ordering heuristics
  abstract.typ       # Subtree collapsing, stats
  import.typ         # JSON interchange import
tests/
  parse/test.typ     # Parser unit tests
  bdd/test.typ       # BDD construction + truth-table oracle
  render/test.typ    # Visual rendering (compile-only, incl. 20-var stress test)
  integration/test.typ  # Full pipeline + JSON import + ordering
typdd-mcp/           # MCP server (TypeScript mirror)
```
