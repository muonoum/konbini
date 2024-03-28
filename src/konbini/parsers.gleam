import gleam/string
import konbini.{
  type Parser, choice, drop, grapheme, keep, label, many, satisfy, string,
  succeed,
}

pub fn ascii_lowercase() {
  satisfy(string.contains("abcdefgijklmnopqrstuvwxyz", _))
  |> label("ascii lower case character")
}

pub fn ascii_uppercase() {
  satisfy(string.contains("ABCDEFGIJKLMNOPQRSTUVWXYZ", _))
  |> label("ascii upper case character")
}

pub fn base10_digit() {
  satisfy(string.contains("01234567890", _))
  |> label("base 10 digit")
}

pub fn ascii_alphanumeric() {
  choice(ascii_lowercase(), choice(ascii_uppercase(), base10_digit()))
  |> label("ascii alpha numeric character")
}

pub fn spaces() {
  many(grapheme(" "))
  |> label("spaces")
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
