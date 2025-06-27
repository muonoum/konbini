import gleam/list
import gleam/yielder.{type Yielder}

pub opaque type Parser(i, v) {
  Parser(fn(State(i)) -> Consumed(i, v))
}

type State(i) {
  State(Yielder(i), Position)
}

pub type Position {
  Position(Int)
}

type Consumed(i, v) {
  Consumed(fn() -> Reply(i, v))
  Empty(fn() -> Reply(i, v))
}

type Reply(i, v) {
  Success(v, State(i), Message(i))
  Failure(Message(i))
}

pub type Message(i) {
  Message(Position, message: Unexpected(i), labels: List(String))
}

pub type Unexpected(i) {
  Nothing
  UnexpectedEnd
  Unexpected(i)
}

fn run(parser: Parser(i, v), state: State(i)) -> Consumed(i, v) {
  let Parser(parse) = parser
  parse(state)
}

pub fn parse(input: Yielder(i), parser: Parser(i, v)) -> Result(v, Message(i)) {
  let state = State(input, Position(1))

  case run(parser, state) {
    Empty(reply) ->
      case reply() {
        Failure(message) -> Error(message)
        Success(_value, _state, message) -> Error(message)
      }

    Consumed(reply) ->
      case reply() {
        Success(value, _state, _message) -> Ok(value)
        Failure(message) -> Error(message)
      }
  }
}

pub fn expect(check: fn(i) -> Bool) -> Parser(i, i) {
  use State(input, position) <- Parser

  case yielder.step(input) {
    yielder.Done ->
      Empty(fn() { Failure(Message(position, UnexpectedEnd, [])) })

    yielder.Next(token, rest) -> {
      case check(token) {
        False ->
          Empty(fn() { Failure(Message(position, Unexpected(token), [])) })

        True -> {
          Consumed(fn() {
            let Position(position) = position
            let position = Position(position + 1)
            let message = Message(position, Nothing, [])
            Success(token, State(rest, position), message)
          })
        }
      }
    }
  }
}

pub fn label(parser: Parser(i, v), label: String) -> Parser(i, v) {
  use state <- Parser

  case run(parser, state) {
    Consumed(reply) -> Consumed(reply)

    Empty(reply) ->
      case reply() {
        Failure(message) -> Empty(fn() { Failure(put_label(message, label)) })

        Success(value, state, message) ->
          Empty(fn() { Success(value, state, put_label(message, label)) })
      }
  }
}

fn put_label(message, label) {
  let Message(position, input, _labels) = message
  Message(position, input, [label])
}

pub fn succeed(value: v) -> Parser(i, v) {
  use State(_input, position) as state <- Parser
  let message = Message(position, Nothing, [])
  Empty(fn() { Success(value, state, message) })
}

pub fn fail() -> Parser(i, v) {
  use State(_input, position) <- Parser
  let message = Message(position, Nothing, [])
  Empty(fn() { Failure(message) })
}

pub fn do(parser: Parser(i, a), next: fn(a) -> Parser(i, b)) -> Parser(i, b) {
  use state <- Parser

  case run(parser, state) {
    Empty(reply) ->
      case reply() {
        Success(value, state, _message) -> run(next(value), state)
        Failure(message) -> Empty(fn() { Failure(message) })
      }

    Consumed(reply) ->
      Consumed(fn() {
        case reply() {
          Failure(message) -> Failure(message)

          Success(value, state, _message) ->
            case run(next(value), state) {
              Consumed(reply) -> reply()
              Empty(reply) -> reply()
            }
        }
      })
  }
}

pub fn choice(a: Parser(i, v), b: Parser(i, v)) -> Parser(i, v) {
  use state <- Parser

  case run(a, state) {
    Consumed(reply) -> Consumed(reply)

    Empty(reply1) ->
      case run(b, state) {
        Empty(reply2) -> Empty(fn() { merge_replies(reply1(), reply2()) })
        Consumed(reply) -> Consumed(reply)
      }
  }
}

fn merge_messages(message1: Message(i), message2: Message(i)) {
  let Message(position, message, labels1) = message1
  let Message(_, _, labels2) = message2
  Message(position, message:, labels: list.append(labels1, labels2))
}

fn merge_replies(reply1, reply2) {
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

pub fn try(parser: Parser(i, v)) -> Parser(i, v) {
  use state <- Parser

  case run(parser, state) {
    Empty(reply) -> Empty(reply)

    Consumed(reply) ->
      case reply() {
        Failure(message) -> Empty(fn() { Failure(message) })
        _success -> Consumed(reply)
      }
  }
}
