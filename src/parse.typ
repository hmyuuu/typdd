// typdd/src/parse.typ — Boolean expression tokenizer + recursive descent parser
//
// Grammar (lowest to highest precedence):
//   expr     → implies
//   implies  → or ("=>" or)?
//   or       → xor ("|" xor)*
//   xor      → and ("^" and)*
//   and      → unary ("&" unary)*
//   unary    → "!" unary | atom
//   atom     → "(" expr ")" | "ite" "(" expr "," expr "," expr ")" | IDENT | "0" | "1"
//
// AST nodes are dictionaries:
//   (kind: "var", name: "x1")
//   (kind: "const", value: true/false)
//   (kind: "not", child: ast)
//   (kind: "binop", op: "&"|"|"|"^"|"=>"|"~&"|"~|"|"~^", left: ast, right: ast)
//   (kind: "ite", cond: ast, then-branch: ast, else-branch: ast)
//
// State threading pattern: every parse function returns (result: ast, pos: int)

// ════════════════════════════════════════════════════════════════════════
// Tokenizer
// ════════════════════════════════════════════════════════════════════════

#let _is-alpha(c) = {
  let cp = str.to-unicode(c)
  (cp >= 97 and cp <= 122) or (cp >= 65 and cp <= 90) or cp == 95
}

#let _is-digit(c) = {
  let cp = str.to-unicode(c)
  cp >= 48 and cp <= 57
}

#let _is-alnum(c) = _is-alpha(c) or _is-digit(c)

#let _is-whitespace(c) = c == " " or c == "\t" or c == "\n" or c == "\r"

#let tokenize(input) = {
  let chars = input.clusters()
  let n = chars.len()
  let tokens = ()
  let i = 0

  while i < n {
    let c = chars.at(i)

    if _is-whitespace(c) {
      i += 1
      continue
    }

    if c == "(" {
      tokens += ((kind: "lparen", pos: i),)
      i += 1
      continue
    }
    if c == ")" {
      tokens += ((kind: "rparen", pos: i),)
      i += 1
      continue
    }
    if c == "," {
      tokens += ((kind: "comma", pos: i),)
      i += 1
      continue
    }

    if c == "!" {
      tokens += ((kind: "not", pos: i),)
      i += 1
      continue
    }

    // tilde-prefixed operators
    if c == "~" {
      if i + 1 < n {
        let next = chars.at(i + 1)
        if next == "&" {
          tokens += ((kind: "nand", pos: i),)
          i += 2
          continue
        }
        if next == "|" {
          tokens += ((kind: "nor", pos: i),)
          i += 2
          continue
        }
        if next == "^" {
          tokens += ((kind: "xnor", pos: i),)
          i += 2
          continue
        }
      }
      panic("Unexpected character '~' at position " + str(i) + " — expected ~&, ~|, or ~^")
    }

    if c == "&" {
      tokens += ((kind: "and", pos: i),)
      i += 1
      continue
    }
    if c == "|" {
      tokens += ((kind: "or", pos: i),)
      i += 1
      continue
    }
    if c == "^" {
      tokens += ((kind: "xor", pos: i),)
      i += 1
      continue
    }

    // implies =>
    if c == "=" {
      if i + 1 < n and chars.at(i + 1) == ">" {
        tokens += ((kind: "implies", pos: i),)
        i += 2
        continue
      }
      panic("Unexpected '=' at position " + str(i) + " — did you mean '=>'?")
    }

    // identifiers and keywords
    if _is-alpha(c) {
      let start = i
      let name = ""
      while i < n and _is-alnum(chars.at(i)) {
        name += chars.at(i)
        i += 1
      }
      if name == "ite" {
        tokens += ((kind: "ite-kw", pos: start),)
      } else if name == "true" or name == "TRUE" {
        tokens += ((kind: "const", value: true, pos: start),)
      } else if name == "false" or name == "FALSE" {
        tokens += ((kind: "const", value: false, pos: start),)
      } else {
        tokens += ((kind: "ident", name: name, pos: start),)
      }
      continue
    }

    // numeric constants
    if c == "0" {
      tokens += ((kind: "const", value: false, pos: i),)
      i += 1
      continue
    }
    if c == "1" {
      tokens += ((kind: "const", value: true, pos: i),)
      i += 1
      continue
    }

    panic("Unexpected character '" + c + "' at position " + str(i))
  }

  tokens += ((kind: "eof", pos: n),)
  tokens
}

// ════════════════════════════════════════════════════════════════════════
// Recursive Descent Parser
// ════════════════════════════════════════════════════════════════════════
//
// Typst does not support forward declarations, so we use a single
// recursive function `_parse` with a `level` parameter to select
// which grammar rule to apply:
//   level 0 → implies
//   level 1 → or
//   level 2 → xor
//   level 3 → and
//   level 4 → unary
//   level 5 → atom

#let _peek(tokens, pos) = {
  if pos < tokens.len() { tokens.at(pos) } else { (kind: "eof", pos: -1) }
}

#let _expect(tokens, pos, kind) = {
  let tok = _peek(tokens, pos)
  if tok.kind != kind {
    panic("Expected '" + kind + "' but got '" + tok.kind + "' at position " + str(tok.pos))
  }
  pos + 1
}

#let _parse(tokens, pos, level) = {
  if level == 5 {
    // atom
    let tok = _peek(tokens, pos)

    if tok.kind == "lparen" {
      let inner = _parse(tokens, pos + 1, 0)
      let new-pos = _expect(tokens, inner.pos, "rparen")
      (result: inner.result, pos: new-pos)
    } else if tok.kind == "ite-kw" {
      let p = _expect(tokens, pos + 1, "lparen")
      let cond = _parse(tokens, p, 0)
      let p2 = _expect(tokens, cond.pos, "comma")
      let then-br = _parse(tokens, p2, 0)
      let p3 = _expect(tokens, then-br.pos, "comma")
      let else-br = _parse(tokens, p3, 0)
      let p4 = _expect(tokens, else-br.pos, "rparen")
      (result: (kind: "ite", cond: cond.result, then-branch: then-br.result, else-branch: else-br.result), pos: p4)
    } else if tok.kind == "ident" {
      (result: (kind: "var", name: tok.name), pos: pos + 1)
    } else if tok.kind == "const" {
      (result: (kind: "const", value: tok.value), pos: pos + 1)
    } else {
      panic("Unexpected token '" + tok.kind + "' at position " + str(tok.pos))
    }
  } else if level == 4 {
    // unary: ! unary | atom
    let tok = _peek(tokens, pos)
    if tok.kind == "not" {
      let inner = _parse(tokens, pos + 1, 4)
      (result: (kind: "not", child: inner.result), pos: inner.pos)
    } else {
      _parse(tokens, pos, 5)
    }
  } else if level == 3 {
    // and: unary ("&" unary | "~&" unary)*
    let state = _parse(tokens, pos, 4)
    let tok = _peek(tokens, state.pos)
    while tok.kind == "and" or tok.kind == "nand" {
      let op = tok.kind
      let rhs = _parse(tokens, state.pos + 1, 4)
      let op-str = if op == "and" { "&" } else { "~&" }
      state = (result: (kind: "binop", op: op-str, left: state.result, right: rhs.result), pos: rhs.pos)
      tok = _peek(tokens, state.pos)
    }
    state
  } else if level == 2 {
    // xor: and ("^" and | "~^" and)*
    let state = _parse(tokens, pos, 3)
    let tok = _peek(tokens, state.pos)
    while tok.kind == "xor" or tok.kind == "xnor" {
      let op = tok.kind
      let rhs = _parse(tokens, state.pos + 1, 3)
      let op-str = if op == "xor" { "^" } else { "~^" }
      state = (result: (kind: "binop", op: op-str, left: state.result, right: rhs.result), pos: rhs.pos)
      tok = _peek(tokens, state.pos)
    }
    state
  } else if level == 1 {
    // or: xor ("|" xor | "~|" xor)*
    let state = _parse(tokens, pos, 2)
    let tok = _peek(tokens, state.pos)
    while tok.kind == "or" or tok.kind == "nor" {
      let op = tok.kind
      let rhs = _parse(tokens, state.pos + 1, 2)
      let op-str = if op == "or" { "|" } else { "~|" }
      state = (result: (kind: "binop", op: op-str, left: state.result, right: rhs.result), pos: rhs.pos)
      tok = _peek(tokens, state.pos)
    }
    state
  } else {
    // level == 0: implies (right-associative)
    let state = _parse(tokens, pos, 1)
    let tok = _peek(tokens, state.pos)
    if tok.kind == "implies" {
      let rhs = _parse(tokens, state.pos + 1, 0)
      (result: (kind: "binop", op: "=>", left: state.result, right: rhs.result), pos: rhs.pos)
    } else {
      state
    }
  }
}

// ════════════════════════════════════════════════════════════════════════
// Public API
// ════════════════════════════════════════════════════════════════════════

/// Parse a boolean expression string into an AST.
///
/// Returns a dictionary AST node. Panics on syntax errors.
///
/// - expr (str): Boolean expression (e.g., "x1 & (x2 | !x3)")
/// -> dictionary
#let parse(expr) = {
  assert(type(expr) == str, message: "parse() expects a string argument")
  assert(expr.len() <= 1000, message: "Expression too long (max 1000 characters)")

  let tokens = tokenize(expr)
  let state = _parse(tokens, 0, 0)

  // Ensure we consumed all input
  let remaining = _peek(tokens, state.pos)
  if remaining.kind != "eof" {
    panic("Unexpected token '" + remaining.kind + "' at position " + str(remaining.pos) + " after parsing complete expression")
  }

  state.result
}

/// Collect all variable names from an AST in depth-first order.
///
/// - ast (dictionary): AST node from parse()
/// -> array of strings
#let collect-vars(ast) = {
  if ast.kind == "var" {
    (ast.name,)
  } else if ast.kind == "const" {
    ()
  } else if ast.kind == "not" {
    collect-vars(ast.child)
  } else if ast.kind == "binop" {
    let left-vars = collect-vars(ast.left)
    let right-vars = collect-vars(ast.right)
    let seen = (:)
    let result = ()
    for v in left-vars + right-vars {
      if v not in seen {
        seen.insert(v, true)
        result += (v,)
      }
    }
    result
  } else if ast.kind == "ite" {
    let c = collect-vars(ast.cond)
    let t = collect-vars(ast.then-branch)
    let e = collect-vars(ast.else-branch)
    let seen = (:)
    let result = ()
    for v in c + t + e {
      if v not in seen {
        seen.insert(v, true)
        result += (v,)
      }
    }
    result
  } else {
    ()
  }
}
