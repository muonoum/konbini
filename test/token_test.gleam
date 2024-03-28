import gleam/iterator
import gleam/option.{Some}
import showtime/tests/should

import konbini.{
  type Parser, Message, Position, Unexpected, drop, keep, satisfy, succeed,
}

pub type Token {
  Ichi
  Ni
  San
}

pub type Number {
  Number(Token)
}

pub fn expect(wanted: Token) -> Parser(Token, Token) {
  use token <- satisfy
  token == wanted
}

pub fn parser() -> Parser(Token, Number) {
  use <- drop(expect(Ichi))
  use token <- keep(expect(Ni))
  use <- drop(expect(San))
  succeed(Number(token))
}

pub fn tokens_test() {
  iterator.from_list([Ichi, Ni, San])
  |> konbini.parse(parser())
  |> should.equal(Ok(Number(Ni)))

  iterator.from_list([Ichi, San, Ni])
  |> konbini.parse(parser())
  |> should.equal(Error(Message(Position(2), Some(Unexpected(San)), [])))
}
