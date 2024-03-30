import helpers.{base10_digit}
import konbini/parsers.{grapheme}
import showtime/tests/should

import konbini.{
  Message, Position, choice, drop, keep, label, one_of, some, succeed,
}

pub fn labels_test() {
  let z = label(grapheme("z"), "z")
  let x = label(grapheme("x"), "x")
  let zx = choice(z, x)

  let p = label(grapheme("p"), "p")
  let q = label(grapheme("q"), "q")
  let pq = choice(p, q)

  let parser = {
    use <- drop(some(base10_digit()))
    use token <- keep(one_of([zx, pq]))
    succeed(token)
  }

  konbini.parse("1234abd", parser)
  |> should.equal(Error(Message(Position(5), "a", ["z", "x", "p", "q"])))
}
