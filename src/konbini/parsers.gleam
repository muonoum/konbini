import gleam/string
import konbini.{type Parser, choice, drop, keep, label, many, satisfy, succeed}

pub fn grapheme(want: String) -> Parser(String) {
  satisfy(fn(grapheme) { grapheme == want })
}

pub fn string(want: String) -> Parser(String) {
  case string.to_graphemes(want) {
    [] -> succeed("")

    [first, ..rest] -> {
      use <- drop(grapheme(first))
      use <- drop(string(string.join(rest, "")))
      succeed(want)
    }
  }
}

pub fn ascii_lowercase() -> Parser(String) {
  satisfy(string.contains("abcdefgijklmnopqrstuvwxyz", _))
  |> label("ascii lower case character")
}

pub fn ascii_uppercase() -> Parser(String) {
  satisfy(string.contains("ABCDEFGIJKLMNOPQRSTUVWXYZ", _))
  |> label("ascii upper case character")
}

pub fn base10_digit() -> Parser(String) {
  satisfy(string.contains("01234567890", _))
  |> label("base 10 digit")
}

pub fn ascii_alphanumeric() -> Parser(String) {
  choice(ascii_lowercase(), choice(ascii_uppercase(), base10_digit()))
  |> label("ascii alpha numeric character")
}

pub fn spaces() -> Parser(List(String)) {
  many(grapheme(" "))
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
