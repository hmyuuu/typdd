// tests/parse — Parser unit tests (compile-only)
//
// Every test is a compile-time assert. If any fails, compilation exits non-zero.

#import "/src/parse.typ": parse, collect-vars, tokenize

// ════════════════════════════════════════════════════════════════════════
// Tokenizer
// ════════════════════════════════════════════════════════════════════════

#let check-tokens(input, expected-kinds) = {
  let kinds = tokenize(input).map(t => t.kind)
  assert.eq(kinds, expected-kinds, message: "tokenize(\"" + input + "\")")
}

#check-tokens("x1",            ("ident", "eof"))
#check-tokens("x1 & x2",       ("ident", "and", "ident", "eof"))
#check-tokens("!x1",           ("not", "ident", "eof"))
#check-tokens("x1 | x2",       ("ident", "or", "ident", "eof"))
#check-tokens("x1 ^ x2",       ("ident", "xor", "ident", "eof"))
#check-tokens("x1 => x2",      ("ident", "implies", "ident", "eof"))
#check-tokens("x1 ~& x2",      ("ident", "nand", "ident", "eof"))
#check-tokens("x1 ~| x2",      ("ident", "nor", "ident", "eof"))
#check-tokens("x1 ~^ x2",      ("ident", "xnor", "ident", "eof"))
#check-tokens("ite(a, b, c)",   ("ite-kw", "lparen", "ident", "comma", "ident", "comma", "ident", "rparen", "eof"))
#check-tokens("(x1 & x2) | x3",("lparen", "ident", "and", "ident", "rparen", "or", "ident", "eof"))
#check-tokens("0",              ("const", "eof"))
#check-tokens("1",              ("const", "eof"))
#check-tokens("true",           ("const", "eof"))
#check-tokens("false",          ("const", "eof"))

// ════════════════════════════════════════════════════════════════════════
// Parser — top-level kind
// ════════════════════════════════════════════════════════════════════════

#assert.eq(parse("x1").kind,         "var")
#assert.eq(parse("input_a").kind,    "var")
#assert.eq(parse("0").kind,          "const")
#assert.eq(parse("1").kind,          "const")
#assert.eq(parse("true").kind,       "const")
#assert.eq(parse("false").kind,      "const")
#assert.eq(parse("!x1").kind,        "not")
#assert.eq(parse("!!x1").kind,       "not")
#assert.eq(parse("x1 & x2").kind,    "binop")
#assert.eq(parse("x1 | x2").kind,    "binop")
#assert.eq(parse("x1 ^ x2").kind,    "binop")
#assert.eq(parse("x1 => x2").kind,   "binop")
#assert.eq(parse("x1 ~& x2").kind,   "binop")
#assert.eq(parse("x1 ~| x2").kind,   "binop")
#assert.eq(parse("x1 ~^ x2").kind,   "binop")
#assert.eq(parse("ite(x1, x2, x3)").kind, "ite")

// Parser — operator values
#assert.eq(parse("x1 & x2").op,  "&")
#assert.eq(parse("x1 | x2").op,  "|")
#assert.eq(parse("x1 ^ x2").op,  "^")
#assert.eq(parse("x1 => x2").op, "=>")
#assert.eq(parse("x1 ~& x2").op, "~&")
#assert.eq(parse("x1 ~| x2").op, "~|")
#assert.eq(parse("x1 ~^ x2").op, "~^")

// Parser — constant values
#assert.eq(parse("0").value, false)
#assert.eq(parse("1").value, true)
#assert.eq(parse("true").value, true)
#assert.eq(parse("false").value, false)

// ════════════════════════════════════════════════════════════════════════
// Precedence
// ════════════════════════════════════════════════════════════════════════

// & tighter than |:  "x1 | x2 & x3" → OR(x1, AND(x2, x3))
#{
  let a = parse("x1 | x2 & x3")
  assert.eq(a.op, "|")
  assert.eq(a.right.op, "&")
}

// ^ between & and |:  "x1 | x2 ^ x3 & x4" → OR(x1, XOR(x2, AND(x3,x4)))
#{
  let a = parse("x1 | x2 ^ x3 & x4")
  assert.eq(a.op, "|")
  assert.eq(a.right.op, "^")
  assert.eq(a.right.right.op, "&")
}

// => right-associative: "a => b => c" → IMPL(a, IMPL(b, c))
#{
  let a = parse("x1 => x2 => x3")
  assert.eq(a.op, "=>")
  assert.eq(a.right.op, "=>")
  assert.eq(a.right.left.name, "x2")
}

// ! tightest: "!x1 & x2" → AND(NOT(x1), x2)
#{
  let a = parse("!x1 & x2")
  assert.eq(a.op, "&")
  assert.eq(a.left.kind, "not")
}

// ════════════════════════════════════════════════════════════════════════
// collect-vars
// ════════════════════════════════════════════════════════════════════════

#assert.eq(collect-vars(parse("x1")),                  ("x1",))
#assert.eq(collect-vars(parse("x1 & x2")),             ("x1", "x2"))
#assert.eq(collect-vars(parse("x1 & x1")),             ("x1",))
#assert.eq(collect-vars(parse("x1 & (x2 | !x3)")),     ("x1", "x2", "x3"))
#assert.eq(collect-vars(parse("x3 & x1 & x2")),        ("x3", "x1", "x2"))
#assert.eq(collect-vars(parse("ite(a, b, c)")),         ("a", "b", "c"))
#assert.eq(collect-vars(parse("1")),                    ())
