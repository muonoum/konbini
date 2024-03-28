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
  Success(v, State, Message)
  Failure(Message)
}

pub opaque type State {
  State(String, Location)
}

pub type Message {
  Message(Location, String, List(String))
}

pub type Location {
  Location(Int)
}

fn run(parser: Parser(v), state: State) -> Consumed(v) {
  let Parser(parse) = parser
  parse(state)
}

pub fn parse(string: String, parser: Parser(v)) -> Result(v, Message) {
  let state = State(string, Location(1))

  case run(parser, state) {
    Empty(Failure(message)) -> Error(message)
    Empty(Success(_value, _state, message)) -> Error(message)

    Consumed(reply) ->
      case reply() {
        Success(value, _state, _message) -> Ok(value)
        Failure(message) -> Error(message)
      }
  }
}

pub fn label(parser: Parser(v), label: String) -> Parser(v) {
  let add_label = fn(message) {
    let Message(location, input, _labels) = message
    Message(location, input, [label])
  }

  use state <- Parser

  case run(parser, state) {
    Consumed(reply) -> Consumed(reply)
    Empty(Failure(message)) -> Empty(Failure(add_label(message)))

    Empty(Success(value, state, message)) ->
      Empty(Success(value, state, add_label(message)))
  }
}

pub fn succeed(value: v) -> Parser(v) {
  use State(_input, location) as state <- Parser
  let message = Message(location, "", [])
  Empty(Success(value, state, message))
}

pub fn fail() -> Parser(v) {
  use State(_input, location) <- Parser
  let message = Message(location, "", [])
  Empty(Failure(message))
}

pub fn satisfy(pred: fn(String) -> Bool) -> Parser(String) {
  use State(input, Location(location)) <- Parser

  case string.pop_grapheme(input) {
    Error(Nil) -> {
      let location = Location(location)
      let message = Message(location, "end of input", [])
      Empty(Failure(message))
    }

    Ok(#(grapheme, rest)) -> {
      case pred(grapheme) {
        False -> {
          let location = Location(location)
          let message = Message(location, grapheme, [])
          Empty(Failure(message))
        }

        True -> {
          use <- Consumed
          let location = Location(location + 1)
          let message = Message(location, "", [])
          Success(grapheme, State(rest, location), message)
        }
      }
    }
  }
}

pub fn keep(parser: Parser(a), next: fn(a) -> Parser(b)) -> Parser(b) {
  use state <- Parser

  case run(parser, state) {
    Empty(Failure(message)) -> Empty(Failure(message))
    Empty(Success(value, state, _message)) -> run(next(value), state)

    Consumed(reply) ->
      Consumed(fn() {
        case reply() {
          Failure(message) -> Failure(message)

          Success(value, state, _message) ->
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
  let merge = fn(message1, message2) {
    let Message(location, input, labels1) = message1
    let Message(_, _, labels2) = message2
    Message(location, input, list.append(labels1, labels2))
  }

  use state <- Parser

  case run(a, state) {
    Consumed(reply) -> Consumed(reply)

    Empty(Failure(message1)) ->
      case run(b, state) {
        Consumed(reply) -> Consumed(reply)
        Empty(Failure(message2)) -> Empty(Failure(merge(message1, message2)))

        Empty(Success(value, state, message2)) ->
          Empty(Success(value, state, merge(message1, message2)))
      }

    Empty(Success(value, state, message1)) ->
      case run(b, state) {
        Consumed(reply) -> Consumed(reply)

        Empty(Failure(message2)) ->
          Empty(Success(value, state, merge(message1, message2)))

        Empty(Success(value, state, message2)) ->
          Empty(Success(value, state, merge(message1, message2)))
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
        Failure(message) -> Empty(Failure(message))
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
