import gleeunit/should
import helpers.{base10_digit}
import konbini.{Message, Position, Unexpected, choice, label, succeed}
import konbini/parsers.{drop, keep, one_of, some}
import konbini/strings.{grapheme}

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

  strings.parse("1234abd", parser)
  |> should.equal(
    Error(Message(Position(5), Unexpected("a"), ["z", "x", "p", "q"])),
  )
}
