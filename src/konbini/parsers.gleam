import gleam/string
import konbini.{type Parser, drop, keep, satisfy, succeed}

pub fn grapheme(wanted: String) -> Parser(String, String) {
  satisfy(fn(grapheme) { grapheme == wanted })
}

pub fn string(wanted: String) -> Parser(String, String) {
  case string.to_graphemes(wanted) {
    [] -> succeed("")

    [first, ..rest] -> {
      use <- drop(grapheme(first))
      use <- drop(string(string.join(rest, "")))
      succeed(wanted)
    }
  }
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
