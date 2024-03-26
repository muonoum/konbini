import gleam/io
import gleam/list
import gleam/string

// http://www.cs.nott.ac.uk/~pszgmh/pearl.pdf
// https://www.cs.nott.ac.uk/~pszgmh/monparsing.pdf
// https://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/parsec-paper-letter.pdf

pub opaque type Parser(v) {
  Parser(fn(State) -> Consumed(v))
}

pub opaque type State {
  State(List(String), Position)
}

pub type Position =
  Int

pub opaque type Consumed(v) {
  // fn() -- se do-funksjonen lenger ned
  Consumed(fn() -> Reply(v))
  Empty(Reply(v))
}

pub opaque type Reply(v) {
  Success(v, State)
  Failure
}

fn run(state: State, parser: Parser(v)) -> Consumed(v) {
  let Parser(parse) = parser
  parse(state)
}

pub fn parse(string: String, parser: Parser(v)) -> Result(v, Nil) {
  let state = State(string.to_graphemes(string), 0)
  let consumed = run(state, parser)

  case consumed {
    Empty(_) -> Error(Nil)

    Consumed(reply) ->
      case reply() {
        Success(v, _) -> Ok(v)
        Failure -> Error(Nil)
      }
  }
}

pub fn return(v: v) -> Parser(v) {
  use state <- Parser
  Empty(Success(v, state))
}

pub fn fail() {
  use _state <- Parser
  Empty(Failure)
}

pub fn satisfy(pred: fn(String) -> Bool) -> Parser(String) {
  use State(input, position) <- Parser

  case input {
    [] -> Empty(Failure)

    [v, ..vs] ->
      case pred(v) {
        True -> Consumed(fn() { Success(v, State(vs, position + 1)) })
        False -> Empty(Failure)
      }
  }
}

pub fn do(parser: Parser(a), then: fn(a) -> Parser(b)) -> Parser(b) {
  use state <- Parser

  case run(state, parser) {
    Empty(Failure) -> Empty(Failure)
    Empty(Success(v, vs)) -> run(vs, then(v))

    Consumed(reply) ->
      // Paper mener lazyness er essensielt her så vi prøver å simulere det ved å
      // la Consumed inneholde en funksjon. Trenger å teste dette vs. ikke lazy.
      Consumed(fn() {
        case reply() {
          Failure -> Failure

          Success(v, vs) ->
            case run(vs, then(v)) {
              Consumed(reply) -> reply()
              Empty(reply) -> reply
            }
        }
      })
  }
}

pub fn choice(a: Parser(a), b: Parser(a)) -> Parser(a) {
  use state <- Parser

  case run(state, a) {
    Empty(Failure) -> run(state, b)
    Consumed(reply) -> Consumed(reply)

    Empty(success) ->
      case run(state, b) {
        Empty(_) -> Empty(success)
        Consumed(reply) -> Consumed(reply)
      }
  }
}

pub fn try(parser: Parser(v)) -> Parser(v) {
  use state <- Parser

  case run(state, parser) {
    Empty(reply) -> Empty(reply)

    Consumed(reply) ->
      case reply() {
        Failure -> Empty(Failure)
        _success -> Consumed(reply)
      }
  }
}

pub fn drop(parser: Parser(a), then: fn() -> Parser(b)) -> Parser(b) {
  use _ <- do(parser)
  then()
}

pub fn option(parser: Parser(v), default: v) -> Parser(v) {
  choice(parser, return(default))
}

// Denne brekker en av testene -- på grunn av ikke-lazy?
// pub fn one_of(parsers: List(Parser(v))) -> Parser(v) {
//   list.fold_right(parsers, fail(), choice)
// }

pub fn one_of(parsers: List(Parser(v))) -> Parser(v) {
  use state <- Parser
  use _, parser <- list.fold_until(parsers, Empty(Failure))

  case run(state, parser) {
    Empty(reply) -> list.Continue(Empty(reply))

    Consumed(reply) ->
      case reply() {
        Success(..) -> list.Stop(Consumed(reply))
        Failure -> list.Continue(Consumed(reply))
      }
  }
}

pub fn not_followed_by(parser: Parser(v)) -> Parser(Nil) {
  let attempt = {
    use <- drop(try(parser))
    fail()
  }

  try(choice(attempt, return(Nil)))
}

pub fn map(parser: Parser(a), with: fn(a) -> b) -> Parser(b) {
  use vs <- do(parser)
  return(with(vs))
}

pub fn any() -> Parser(String) {
  use _grapheme <- satisfy
  True
}

pub fn end() -> Parser(Nil) {
  not_followed_by(any())
}

pub fn grapheme(want: String) -> Parser(String) {
  use grapheme <- satisfy
  grapheme == want
}

pub fn string(want: String) -> Parser(String) {
  case string.to_graphemes(want) {
    [] -> return("")

    [first, ..rest] -> {
      use <- drop(grapheme(first))
      use <- drop(string(string.join(rest, "")))
      return(want)
    }
  }
}

pub fn many(parser: Parser(v)) -> Parser(List(v)) {
  choice(some(parser), return([]))
}

pub fn some(parser: Parser(v)) -> Parser(List(v)) {
  use first <- do(parser)
  use rest <- do(choice(some(parser), return([])))
  return([first, ..rest])
}

pub fn ascii_lowercase() -> Parser(String) {
  use grapheme <- satisfy
  string.contains("abcdefgijklmnopqrstuvwxyz", grapheme)
}

pub fn ascii_uppercase() -> Parser(String) {
  use grapheme <- satisfy
  string.contains("ABCDEFGIJKLMNOPQRSTUVWXYZ", grapheme)
}

pub fn digit() -> Parser(String) {
  use grapheme <- satisfy
  string.contains("01234567890", grapheme)
}

pub fn ascii_alphanumeric() -> Parser(String) {
  one_of([ascii_lowercase(), ascii_uppercase(), digit()])
}

pub fn main() {
  string.to_graphemes("alex")
  |> State(0)
  |> run({
    use a <- do(grapheme("a"))
    use b <- do(grapheme("l"))
    return(a <> b)
  })
  |> to_result
  |> io.debug
}

fn to_result(consumed: Consumed(v)) -> Result(#(v, State), Nil) {
  case consumed {
    Empty(reply) -> reply_to_result(reply)
    Consumed(reply) -> reply_to_result(reply())
  }
}

fn reply_to_result(reply: Reply(v)) -> Result(#(v, State), Nil) {
  case reply {
    Success(v, vs) -> Ok(#(v, vs))
    Failure -> Error(Nil)
  }
}
