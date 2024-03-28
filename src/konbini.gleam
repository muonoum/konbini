import gleam/list
import gleam/string

// https://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/parsec-paper-letter.pdf

pub opaque type Parser(v) {
  Parser(fn(State) -> Consumed(v))
}

type Consumed(v) {
  Consumed(fn() -> Reply(v))
  Empty(Reply(v))
}

type Reply(v) {
  Success(v, State, Message)
  Failure(Message)
}

type State {
  State(String, Position)
}

pub type Message {
  Message(Position, String, List(String))
}

pub type Position {
  Position(Int)
}

fn run(parser: Parser(v), state: State) -> Consumed(v) {
  let Parser(parse) = parser
  parse(state)
}

pub fn parse(string: String, parser: Parser(v)) -> Result(v, Message) {
  let state = State(string, Position(1))

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
    let Message(position, input, _labels) = message
    Message(position, input, [label])
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
  use State(_input, position) as state <- Parser
  let message = Message(position, "", [])
  Empty(Success(value, state, message))
}

pub fn fail() -> Parser(v) {
  use State(_input, position) <- Parser
  let message = Message(position, "", [])
  Empty(Failure(message))
}

pub fn satisfy(check: fn(String) -> Bool) -> Parser(String) {
  use State(input, Position(position)) <- Parser

  case string.pop_grapheme(input) {
    Error(Nil) -> {
      let position = Position(position)
      let message = Message(position, "end of input", [])
      Empty(Failure(message))
    }

    Ok(#(grapheme, rest)) -> {
      case check(grapheme) {
        False -> {
          let position = Position(position)
          let message = Message(position, grapheme, [])
          Empty(Failure(message))
        }

        True -> {
          use <- Consumed
          let position = Position(position + 1)
          let message = Message(position, "", [])
          Success(grapheme, State(rest, position), message)
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
  let merge_messages = fn(message1, message2) {
    let Message(position, input, labels1) = message1
    let Message(_, _, labels2) = message2
    Message(position, input, list.append(labels1, labels2))
  }

  let merge_replies = fn(reply1, reply2) {
    case reply1, reply2 {
      Failure(msg1), Failure(msg2) -> Failure(merge_messages(msg1, msg2))

      Failure(msg1), Success(value, state, msg2) ->
        Success(value, state, merge_messages(msg1, msg2))

      Success(value, state, msg1), Failure(msg2) ->
        Success(value, state, merge_messages(msg1, msg2))

      Success(_value, _state, msg1), Success(value, state, msg2) ->
        Success(value, state, merge_messages(msg1, msg2))
    }
  }

  use state <- Parser

  case run(a, state) {
    Consumed(reply) -> Consumed(reply)

    Empty(reply1) ->
      case run(b, state) {
        Consumed(reply) -> Consumed(reply)
        Empty(reply2) -> Empty(merge_replies(reply1, reply2))
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
