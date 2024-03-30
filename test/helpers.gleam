import gleam/string
import konbini.{type Parser, choice, expect, label, many}
import konbini/parsers.{grapheme}

pub fn ascii_lowercase() -> Parser(String) {
  expect(string.contains("abcdefgijklmnopqrstuvwxyz", _))
  |> label("ascii lower case character")
}

pub fn ascii_uppercase() -> Parser(String) {
  expect(string.contains("ABCDEFGIJKLMNOPQRSTUVWXYZ", _))
  |> label("ascii upper case character")
}

pub fn base10_digit() -> Parser(String) {
  expect(string.contains("01234567890", _))
  |> label("base 10 digit")
}

pub fn ascii_alphanumeric() -> Parser(String) {
  choice(ascii_lowercase(), choice(ascii_uppercase(), base10_digit()))
  |> label("ascii alpha numeric character")
}

pub fn spaces() -> Parser(List(String)) {
  many(grapheme(" "))
}
