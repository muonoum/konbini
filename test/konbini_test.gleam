import gleam/string
import gleeunit
import gleeunit/should
import konbini.{
  any, choice, drop, end, grapheme, keep, many, not_followed_by, one_of, parse,
  satisfy, some, string, succeed, try,
}

type Part {
  Placeholder
  Reference(String)
  Static(String)
}

pub fn main() {
  gleeunit.main()
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

pub fn interpolate1_test() {
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
    let initial = ascii_lowercase()
    let symbol = choice(grapheme("-"), grapheme("_"))
    let subsequent = choice(symbol, ascii_alphanumeric())

    use <- drop(open)
    use <- drop(spaces())
    use first <- keep(initial)
    use rest <- keep(many(subsequent))
    use <- drop(spaces())
    use <- drop(close)
    succeed(Reference(string.join([first, ..rest], "")))
  }

  let placeholder = {
    use <- drop(open)
    use <- drop(spaces())
    use <- drop(grapheme("_"))
    use <- drop(spaces())
    use <- drop(close)
    succeed(Placeholder)
  }

  let text = {
    let part = one_of([try(static), try(reference), placeholder])
    use parts <- keep(many(part))
    use <- drop(end())
    succeed(parts)
  }

  parse("ja {{ ref }} nei {{_}} kanskje", text)
  |> should.equal(
    Ok([
      Static("ja "),
      Reference("ref"),
      Static(" nei "),
      Placeholder,
      Static(" kanskje"),
    ]),
  )
}

pub fn interpolate2_test() {
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

    use <- drop(open)
    use <- drop(spaces())
    use part <- keep(choice(placeholder, id))
    use <- drop(spaces())
    use <- drop(close)
    succeed(part)
  }

  let text = {
    use parts <- keep(many(choice(reference, static)))
    use <- drop(end())
    succeed(parts)
  }

  parse("ja {{ ref }} nei {{_}} kanskje", text)
  |> should.equal(
    Ok([
      Static("ja "),
      Reference("ref"),
      Static(" nei "),
      Placeholder,
      Static(" kanskje"),
    ]),
  )
}
