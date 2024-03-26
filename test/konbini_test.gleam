import gleam/string
import gleeunit
import gleeunit/should
import konbini.{
  any, ascii_alphanumeric, ascii_lowercase, choice, do, drop, end, grapheme,
  many, not_followed_by, one_of, parse, return, some, string,
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
  let spaces = many(grapheme(" "))
  let open = string("{{")
  let close = string("}}")

  let static = {
    use parts <- do(
      some({
        use <- drop(not_followed_by(open))
        use grapheme <- do(any())
        return(grapheme)
      }),
    )

    return(Static(string.join(parts, "")))
  }

  let reference = {
    let initial = ascii_lowercase()
    let subsequent =
      one_of([grapheme("-"), grapheme("_"), ascii_alphanumeric()])

    use <- drop(open)
    use <- drop(spaces)
    use first <- do(initial)
    use rest <- do(many(subsequent))
    use <- drop(spaces)
    use <- drop(close)

    return(Reference(string.join([first, ..rest], "")))
  }

  let placeholder = {
    use <- drop(open)
    use <- drop(spaces)
    use <- drop(grapheme("_"))
    use <- drop(spaces)
    use <- drop(close)

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
  let spaces = many(grapheme(" "))
  let open = string("{{")
  let close = string("}}")

  let static = {
    use parts <- do(
      some({
        use <- drop(not_followed_by(open))
        use grapheme <- do(any())
        return(grapheme)
      }),
    )

    return(Static(string.join(parts, "")))
  }

  let reference = {
    let initial = ascii_lowercase()
    let subsequent =
      one_of([grapheme("-"), grapheme("_"), ascii_alphanumeric()])

    let placeholder = {
      use <- drop(grapheme("_"))
      return(Placeholder)
    }

    let id = {
      use first <- do(initial)
      use rest <- do(many(subsequent))
      return(Reference(string.join([first, ..rest], "")))
    }

    use <- drop(open)
    use <- drop(spaces)
    use part <- do(choice(id, placeholder))
    use <- drop(spaces)
    use <- drop(close)

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
