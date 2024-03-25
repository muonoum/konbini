import gleam/string
import gleeunit
import gleeunit/should
import konbini.{
  ascii_alphanumeric, ascii_lowercase, do, drop, end, grapheme, many, map,
  negative_lookahead, one, one_of, parse, return, some, string,
}

type Part {
  Placeholder
  Reference(String)
  Static(String)
}

pub fn main() {
  gleeunit.main()
}

pub fn interpolated_string_test() {
  let spaces = many(grapheme(" "))
  let open = string("{{")
  let close = string("}}")

  let static = {
    use parts <- do(
      some({
        use <- drop(negative_lookahead(open))
        use grapheme <- do(one())
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
    let part = many(one_of([static, reference, placeholder]))
    use parts <- do(part)
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
