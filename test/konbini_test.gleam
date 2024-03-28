import gleam/string
import konbini.{
  any, choice, drop, end, grapheme, keep, label, many, not_followed_by, one_of,
  parse, satisfy, some, string, succeed, try,
}
import showtime
import showtime/tests/should

pub fn main() {
  showtime.main()
}

fn ascii_lowercase() {
  satisfy(string.contains("abcdefgijklmnopqrstuvwxyz", _))
}

fn ascii_uppercase() {
  satisfy(string.contains("ABCDEFGIJKLMNOPQRSTUVWXYZ", _))
}

fn digit() {
  satisfy(string.contains("01234567890", _))
}

fn ascii_alphanumeric() {
  choice(ascii_lowercase(), choice(ascii_uppercase(), digit()))
}

fn spaces() {
  many(grapheme(" "))
}

fn surrounded_by(parser, open, close) {
  use <- drop(open)
  use <- drop(spaces())
  use token <- keep(parser)
  use <- drop(spaces())
  use <- drop(close)
  succeed(token)
}

pub fn labels_test() {
  let z = label(grapheme("z"), "z")
  let x = label(grapheme("x"), "x")
  let zx = choice(z, x)

  let p = label(grapheme("p"), "p")
  let q = label(grapheme("q"), "q")
  let pq = choice(p, q)

  let parser = {
    use <- drop(some(digit()))
    use token <- keep(one_of([zx, pq]))
    succeed(token)
  }

  parse("1234abd", parser)
  |> should.be_error()
}

pub fn ll_fail_test() {
  let parser = {
    let token = surrounded_by(_, grapheme("("), grapheme(")"))
    let digits = token(digit())
    let letters = token(ascii_lowercase())
    choice(letters, digits)
  }

  parse("(1)", parser)
  |> should.be_error()
}

pub fn ll_ok_test() {
  let parser = {
    let token = surrounded_by(_, grapheme("("), grapheme(")"))
    let digits = token(digit())
    let letters = token(ascii_lowercase())
    choice(try(letters), digits)
  }

  parse("(1)", parser)
  |> should.equal(Ok("1"))
}

pub type Part {
  Placeholder
  Reference(String)
  Static(String)
}

pub fn template_string_test() {
  let open = string("{{")
  let close = string("}}")

  let static = {
    use parts <- keep(
      some({
        use <- drop(not_followed_by(open))
        use grapheme <- keep(any())
        succeed(grapheme)
      }),
    )

    succeed(Static(string.join(parts, "")))
  }

  let reference = {
    let placeholder = {
      use <- drop(grapheme("_"))
      succeed(Placeholder)
    }

    let id = {
      let initial = ascii_lowercase()
      let symbol = choice(grapheme("-"), grapheme("_"))
      let subsequent = choice(symbol, ascii_alphanumeric())
      use first <- keep(initial)
      use rest <- keep(many(subsequent))
      succeed(Reference(string.join([first, ..rest], "")))
    }

    choice(placeholder, id)
    |> surrounded_by(open, close)
  }

  let template = {
    use parts <- keep(many(choice(reference, static)))
    use <- drop(end())
    succeed(parts)
  }

  parse("one {{ two }} three {{_}} four", template)
  |> should.equal(
    Ok([
      Static("one "),
      Reference("two"),
      Static(" three "),
      Placeholder,
      Static(" four"),
    ]),
  )
}
