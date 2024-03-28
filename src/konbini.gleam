import gleam/iterator.{type Iterator}
import gleam/list
import gleam/option.{type Option, None, Some}

pub opaque type Parser(input, value) {
  Parser(fn(State(input)) -> Consumed(input, value))
}

type Consumed(input, value) {
  Consumed(fn() -> Reply(input, value))
  Empty(Reply(input, value))
}

type Reply(input, value) {
  Success(value, State(input), Message(input))
  Failure(Message(input))
}

type State(input) {
  State(Iterator(input), Position)
}

pub type Unexpected(input) {
  UnexpectedEnd
  Unexpected(input)
}

pub type Message(input) {
  Message(Position, message: Option(Unexpected(input)), labels: List(String))
}

pub type Position {
  Position(Int)
}

fn run(parser: Parser(_, value), state: State(_)) -> Consumed(_, value) {
  let Parser(parse) = parser
  parse(state)
}

pub fn parse(
  input: Iterator(input),
  parser: Parser(input, value),
) -> Result(value, Message(_)) {
  let state = State(input, Position(1))

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

pub fn label(parser: Parser(_, _), label: String) -> Parser(_, _) {
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

pub fn succeed(value: value) -> Parser(_, value) {
  use State(_input, position) as state <- Parser
  let message = Message(position, None, [])
  Empty(Success(value, state, message))
}

pub fn fail() -> Parser(_, _) {
  use State(_input, position) <- Parser
  let message = Message(position, None, [])
  Empty(Failure(message))
}

pub fn satisfy(check: fn(input) -> Bool) -> Parser(input, input) {
  use State(input, Position(position)) <- Parser

  case iterator.step(input) {
    iterator.Done -> {
      let position = Position(position)
      let message = Message(position, Some(UnexpectedEnd), [])
      Empty(Failure(message))
    }

    iterator.Next(token, rest) -> {
      case check(token) {
        False -> {
          let position = Position(position)
          let message = Message(position, Some(Unexpected(token)), [])
          Empty(Failure(message))
        }

        True -> {
          use <- Consumed
          let position = Position(position + 1)
          let message = Message(position, None, [])
          Success(token, State(rest, position), message)
        }
      }
    }
  }
}

pub fn keep(parser: Parser(_, a), next: fn(a) -> Parser(_, b)) -> Parser(_, b) {
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

pub fn drop(parser: Parser(_, a), then: fn() -> Parser(_, b)) -> Parser(_, b) {
  keep(parser, fn(_value) { then() })
}

pub fn choice(a: Parser(_, value), b: Parser(_, value)) -> Parser(_, value) {
  let merge_messages = fn(message1, message2) {
    let Message(_position, _message, labels) = message2
    Message(..message1, labels: list.append(message1.labels, labels))
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

pub fn one_of(parsers: List(Parser(_, v))) -> Parser(_, v) {
  use result, parser <- list.fold_right(parsers, fail())
  choice(parser, result)
}

pub fn try(parser: Parser(_, v)) -> Parser(_, v) {
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

pub fn any() -> Parser(input, input) {
  satisfy(fn(_grapheme) { True })
}

pub fn not_followed_by(parser: Parser(_, v)) -> Parser(_, Nil) {
  try(choice(drop(parser, fail), succeed(Nil)))
}

pub fn end() -> Parser(_, Nil) {
  not_followed_by(any())
}

pub fn many(parser: Parser(_, v)) -> Parser(_, List(v)) {
  choice(some(parser), succeed([]))
}

pub fn some(parser: Parser(_, v)) -> Parser(_, List(v)) {
  use first <- keep(parser)
  use rest <- keep(many(parser))
  succeed([first, ..rest])
}
