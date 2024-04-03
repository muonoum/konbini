import gleam/list
import konbini.{type Parser, choice, do, expect, fail, succeed, try}

pub const keep = do

pub fn drop(parser: Parser(i, a), then: fn() -> Parser(i, b)) -> Parser(i, b) {
  use _value <- do(parser)
  then()
}

pub fn one_of(parsers: List(Parser(i, v))) -> Parser(i, v) {
  use result, parser <- list.fold_right(parsers, fail())
  choice(parser, result)
}

pub fn any() -> Parser(i, i) {
  use _grapheme <- expect
  True
}

pub fn not_followed_by(parser: Parser(i, v)) -> Parser(i, Nil) {
  drop(parser, fail)
  |> choice(succeed(Nil))
  |> try
}

pub fn end() -> Parser(i, Nil) {
  not_followed_by(any())
}

pub fn many(parser: Parser(i, v)) -> Parser(i, List(v)) {
  choice(some(parser), succeed([]))
}

pub fn some(parser: Parser(i, v)) -> Parser(i, List(v)) {
  use first <- keep(parser)
  use rest <- keep(many(parser))
  succeed([first, ..rest])
}

pub fn surrounded_by(
  parser: Parser(i, v),
  open: Parser(i, a),
  close: Parser(i, b),
) -> Parser(i, v) {
  use <- drop(open)
  use token <- keep(parser)
  use <- drop(close)
  succeed(token)
}
