import gleam/iterator
import gleam/string
import konbini.{type Message, type Parser}

pub fn parse(
  string: String,
  parser: Parser(_, value),
) -> Result(value, Message(_)) {
  let input = {
    use state <- iterator.unfold(string)

    case string.pop_grapheme(state) {
      Error(Nil) -> iterator.Done
      Ok(#(grapheme, state)) -> iterator.Next(grapheme, state)
    }
  }

  konbini.parse(input, parser)
}
