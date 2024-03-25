import gleam/list
import gleam/string

// https://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/parsec-paper-letter.pdf

pub opaque type Parser(v) {
  Parser(fn(State) -> Consumed(v))
}

pub opaque type Consumed(v) {
  Consumed(fn() -> Reply(v))
  Empty(Reply(v))
}

pub opaque type Reply(v) {
  Success(v, State)
  Failure
}

pub opaque type State {
  State(String)
}

fn run(parser: Parser(v), state: State) -> Consumed(v) {
  let Parser(parse) = parser
  parse(state)
}

pub fn parse(string: String, parser: Parser(v)) -> Result(v, Nil) {
  let state = State(string)

  case run(parser, state) {
    Empty(_reply) -> Error(Nil)

    Consumed(reply) ->
      case reply() {
        Success(value, _state) -> Ok(value)
        Failure -> Error(Nil)
      }
  }
}

pub fn succeed(value: v) -> Parser(v) {
  Parser(fn(state) { Empty(Success(value, state)) })
}

pub fn fail() -> Parser(v) {
  Parser(fn(_state) { Empty(Failure) })
}

pub fn satisfy(pred: fn(String) -> Bool) -> Parser(String) {
  use State(input) <- Parser

  case string.pop_grapheme(input) {
    Error(Nil) -> Empty(Failure)

    Ok(#(first, rest)) -> {
      case pred(first) {
        False -> Empty(Failure)
        True -> Consumed(fn() { Success(first, State(rest)) })
      }
    }
  }
}

pub fn keep(parser: Parser(a), next: fn(a) -> Parser(b)) -> Parser(b) {
  use state <- Parser

  case run(parser, state) {
    Empty(Failure) -> Empty(Failure)
    Empty(Success(value, state)) -> run(next(value), state)

    Consumed(reply) ->
      Consumed(fn() {
        case reply() {
          Failure -> Failure

          Success(value, state) ->
            case run(next(value), state) {
              Consumed(reply) -> reply()
              Empty(reply) -> reply
            }
        }
      })
  }
}

pub fn drop(parser: Parser(a), then: fn() -> Parser(b)) -> Parser(b) {
  keep(parser, fn(_value) { then() })
}

pub fn choice(a: Parser(v), b: Parser(v)) -> Parser(v) {
  use state <- Parser

  case run(a, state) {
    Consumed(reply) -> Consumed(reply)
    Empty(Failure) -> run(b, state)

    Empty(success) ->
      case run(b, state) {
        Empty(_reply) -> Empty(success)
        Consumed(reply) -> Consumed(reply)
      }
  }
}

pub fn one_of(parsers: List(Parser(v))) -> Parser(v) {
  use result, parser <- list.fold_right(parsers, fail())
  choice(parser, result)
}

pub fn try(parser: Parser(v)) -> Parser(v) {
  use state <- Parser

  case run(parser, state) {
    Empty(reply) -> Empty(reply)

    Consumed(reply) ->
      case reply() {
        Failure -> Empty(Failure)
        _success -> Consumed(reply)
      }
  }
}

pub fn any() -> Parser(String) {
  satisfy(fn(_grapheme) { True })
}

pub fn not_followed_by(parser: Parser(v)) -> Parser(Nil) {
  try(choice(drop(parser, fail), succeed(Nil)))
}

pub fn end() -> Parser(Nil) {
  not_followed_by(any())
}

pub fn many(parser: Parser(v)) -> Parser(List(v)) {
  choice(some(parser), succeed([]))
}

pub fn some(parser: Parser(v)) -> Parser(List(v)) {
  use first <- keep(parser)
  use rest <- keep(many(parser))
  succeed([first, ..rest])
}

pub fn grapheme(want: String) -> Parser(String) {
  satisfy(fn(grapheme) { grapheme == want })
}

pub fn string(want: String) -> Parser(String) {
  case string.to_graphemes(want) {
    [] -> succeed("")

    [first, ..rest] -> {
      use <- drop(grapheme(first))
      use <- drop(string(string.join(rest, "")))
      succeed(want)
    }
  }
}
