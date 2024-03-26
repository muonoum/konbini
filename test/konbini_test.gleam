import gleam/string
import gleeunit
import gleeunit/should
import konbini.{
  any, choice, do, drop, end, grapheme, many, not_followed_by, one_of, parse,
  return, satisfy, some, string,
}

fn ascii_lowercase() {
  use grapheme <- satisfy
  string.contains("abcdefgijklmnopqrstuvwxyz", grapheme)
}

fn ascii_uppercase() {
  use grapheme <- satisfy
  string.contains("ABCDEFGIJKLMNOPQRSTUVWXYZ", grapheme)
}

fn digit() {
  use grapheme <- satisfy
  string.contains("01234567890", grapheme)
}

fn ascii_alphanumeric() {
  choice(ascii_lowercase(), choice(ascii_uppercase(), digit()))
}

fn spaces() {
  many(grapheme(" "))
}

type Part {
  Placeholder
  Reference(String)
  Static(String)
}

pub fn main() {
  gleeunit.main()
}

pub fn interpolate1_test() {
  let static = {
    use parts <- do(
      some({
        use <- drop(not_followed_by(string("{{")))
        use grapheme <- do(any())
        return(grapheme)
      }),
    )

    return(Static(string.join(parts, "")))
  }

  let reference = {
    let initial = ascii_lowercase()
    let symbol = choice(grapheme("-"), grapheme("_"))
    let subsequent = choice(symbol, ascii_alphanumeric())

    use <- drop(string("{{"))
    use <- drop(spaces())
    use first <- do(initial)
    use rest <- do(many(subsequent))
    use <- drop(spaces())
    use <- drop(string("}}"))

    return(Reference(string.join([first, ..rest], "")))
  }

  let placeholder = {
    use <- drop(string("{{"))
    use <- drop(spaces())
    use <- drop(grapheme("_"))
    use <- drop(spaces())
    use <- drop(string("}}"))

    return(Placeholder)
  }

  let text = {
    use parts <- do(many(one_of([static, reference, placeholder])))
    use <- drop(end())
    return(parts)
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
  let static = {
    use parts <- do(
      some({
        use <- drop(not_followed_by(string("{{")))
        use grapheme <- do(any())
        return(grapheme)
      }),
    )

    return(Static(string.join(parts, "")))
  }

  let reference = {
    let initial = ascii_lowercase()
    let symbol = choice(grapheme("-"), grapheme("_"))
    let subsequent = choice(symbol, ascii_alphanumeric())

    let placeholder = {
      use <- drop(grapheme("_"))
      return(Placeholder)
    }

    let id = {
      use first <- do(initial)
      use rest <- do(many(subsequent))
      return(Reference(string.join([first, ..rest], "")))
    }

    use <- drop(string("{{"))
    use <- drop(spaces())
    use part <- do(choice(id, placeholder))
    use <- drop(spaces())
    use <- drop(string("}}"))

    return(part)
  }

  let text = {
    use parts <- do(many(one_of([static, reference])))
    use <- drop(end())
    return(parts)
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
