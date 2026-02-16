# typdd — BDD Visualization for Typst
#
# Targets:
#   make          — run all tests
#   make test     — run all tests (Typst + MCP)
#   make typst    — run Typst tests only (tytanic)
#   make mcp      — run MCP tests only (bun test)
#   make examples — compile example documents to PNG
#   make install  — install dependencies
#   make clean    — remove build artifacts
#   make help     — show this help

.PHONY: all test typst mcp examples install clean help

EXAMPLES_DIR = examples
SOURCES = $(wildcard $(EXAMPLES_DIR)/*.typ)
OUTPUTS = $(SOURCES:.typ=.png)

all: test

# ──────────────────────────────────────────────
# Testing
# ──────────────────────────────────────────────

test: typst mcp
	@printf "\n\033[32m✓ All tests passed\033[0m\n"

typst:
	@echo "═══ Typst tests (tytanic) ═══"
	tt run

mcp:
	@echo "═══ MCP tests (bun) ═══"
	cd typdd-mcp && bun test

# ──────────────────────────────────────────────
# Examples (compile to PNG for README)
# ──────────────────────────────────────────────

examples: $(OUTPUTS)

$(EXAMPLES_DIR)/%.png: $(EXAMPLES_DIR)/%.typ lib.typ src/*.typ
	typst compile $< --root=. --format=png

# ──────────────────────────────────────────────
# Setup
# ──────────────────────────────────────────────

install:
	@echo "Installing MCP dependencies..."
	cd typdd-mcp && bun install
	@echo "Checking tytanic..."
	@command -v tt >/dev/null 2>&1 || { echo "Installing tytanic..."; cargo install tytanic; }
	@echo "Done."

# ──────────────────────────────────────────────
# Clean
# ──────────────────────────────────────────────

clean:
	rm -rf tests/*/out tests/*/diff
	rm -f examples/*.png
	rm -rf typdd-mcp/node_modules

# ──────────────────────────────────────────────
# Help
# ──────────────────────────────────────────────

help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  test      Run all tests (default)"
	@echo "  typst     Run Typst tests only (tytanic)"
	@echo "  mcp       Run MCP tests only (bun test)"
	@echo "  examples  Compile example documents to PNG"
	@echo "  install   Install dependencies (bun + tytanic)"
	@echo "  clean     Remove build artifacts"
	@echo "  help      Show this help"
