import gleam/string
import konbini.{type Parser, drop, expect, keep, succeed}

pub fn grapheme(wanted: String) -> Parser(String) {
  use grapheme <- expect
  grapheme == wanted
}

pub fn string(wanted: String) -> Parser(String) {
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
  parser: Parser(v),
  open: Parser(a),
  close: Parser(b),
) -> Parser(v) {
  use <- drop(open)
  use token <- keep(parser)
  use <- drop(close)
  succeed(token)
}
