import gleam/iterator
import gleam/option.{Some}
import konbini.{Message, Position, Unexpected, drop, keep, satisfy, succeed}
import showtime/tests/should

pub type Token {
  Ichi
  Ni
  San
}

pub fn tokens_test() {
  let parser = {
    use <- drop(satisfy(fn(token) { token == Ichi }))
    use token <- keep(satisfy(fn(token) { token == Ni }))
    use <- drop(satisfy(fn(token) { token == San }))
    succeed(token)
  }

  iterator.from_list([Ichi, Ni, San])
  |> konbini.parse(parser)
  |> should.equal(Ok(Ni))

  iterator.from_list([Ichi, San, Ni])
  |> konbini.parse(parser)
  |> should.equal(Error(Message(Position(2), Some(Unexpected(San)), [])))
}
