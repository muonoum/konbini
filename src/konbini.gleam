import gleam/list
import gleam/string

pub opaque type Parser(v) {
  Parser(fn(State) -> Consumed(v))
}

type State {
  State(String, Position)
}

pub type Position {
  Position(Int)
}

type Consumed(v) {
  Consumed(fn() -> Reply(v))
  Empty(fn() -> Reply(v))
}

type Reply(v) {
  Success(v, State, Message)
  Failure(Message)
}

pub type Message {
  Message(Position, message: String, labels: List(String))
}

fn run(parser: Parser(v), state: State) -> Consumed(v) {
  let Parser(parse) = parser
  parse(state)
}

pub fn parse(input: String, parser: Parser(v)) -> Result(v, Message) {
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

pub fn expect(check: fn(String) -> Bool) -> Parser(String) {
  use State(input, position) <- Parser

  case string.pop_grapheme(input) {
    Error(Nil) -> Empty(fn() { Failure(Message(position, "end of input", [])) })

    Ok(#(grapheme, rest)) -> {
      case check(grapheme) {
        False -> Empty(fn() { Failure(Message(position, grapheme, [])) })

        True -> {
          Consumed(fn() {
            let Position(position) = position
            let position = Position(position + 1)
            let message = Message(position, "", [])
            Success(grapheme, State(rest, position), message)
          })
        }
      }
    }
  }
}

pub fn label(parser: Parser(v), label: String) -> Parser(v) {
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

pub fn succeed(value: v) -> Parser(v) {
  use State(_input, position) as state <- Parser
  let message = Message(position, "", [])
  Empty(fn() { Success(value, state, message) })
}

pub fn fail() -> Parser(v) {
  use State(_input, position) <- Parser
  let message = Message(position, "", [])
  Empty(fn() { Failure(message) })
}

pub fn keep(parser: Parser(a), next: fn(a) -> Parser(b)) -> Parser(b) {
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

pub fn drop(parser: Parser(a), then: fn() -> Parser(b)) -> Parser(b) {
  use _value <- keep(parser)
  then()
}

pub fn choice(a: Parser(v), b: Parser(v)) -> Parser(v) {
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

fn merge_messages(message1, message2) {
  let Message(_position, _message, labels) = message2
  Message(..message1, labels: list.append(message1.labels, labels))
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
        Failure(message) -> Empty(fn() { Failure(message) })
        _success -> Consumed(reply)
      }
  }
}

pub fn any() -> Parser(String) {
  use _grapheme <- expect
  True
}

pub fn not_followed_by(parser: Parser(v)) -> Parser(Nil) {
  drop(parser, fail)
  |> choice(succeed(Nil))
  |> try
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

pub fn grapheme(wanted: String) -> Parser(String) {
  use grapheme <- expect
  grapheme == wanted
}

pub fn string(wanted: String) -> Parser(String) {
  case string.to_graphemes(wanted) {
    [] -> succeed("")

    [first, ..rest] -> {
      use <- drop(grapheme(first))
      use <- drop(string(string.join(rest, "")))
      succeed(wanted)
    }
  }
}

pub fn surrounded_by(
  parser: Parser(v),
  open: Parser(a),
  close: Parser(b),
) -> Parser(v) {
  use <- drop(open)
  use token <- keep(parser)
  use <- drop(close)
  succeed(token)
}
