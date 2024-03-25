import gleam/bool
import gleam/dict.{type Dict}
import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam/string

pub opaque type Parser(v) {
  Parser(fn(Context) -> Result(State(v), Nil))
}

pub opaque type State(v) {
  State(v, Context)
}

pub opaque type Context {
  Context(offset: Int, length: Int, graphemes: Dict(Int, String))
}

fn context(string: String) -> Context {
  Context(
    offset: 0,
    length: string.length(string),
    graphemes: dict.from_list({
      use grapheme, index <- list.index_map(string.to_graphemes(string))
      #(index, grapheme)
    }),
  )
}

pub fn parse(string: String, parser: Parser(v)) -> Result(v, Nil) {
  use State(value, _ctx) <- result.map(run(context(string), parser))
  value
}

pub fn one() -> Parser(String) {
  use ctx <- Parser
  use grapheme <- result.try(dict.get(ctx.graphemes, ctx.offset))

  case ctx.offset + 1 {
    offset if offset > ctx.length -> Error(Nil)
    offset -> Ok(State(grapheme, Context(..ctx, offset: offset)))
  }
}

pub fn return(v: v) -> Parser(v) {
  use ctx <- Parser
  Ok(State(v, ctx))
}

pub fn fail() -> Parser(v) {
  use _ctx <- Parser
  Error(Nil)
}

pub fn run(ctx: Context, parser: Parser(v)) -> Result(State(v), Nil) {
  let Parser(parse) = parser
  parse(ctx)
}

pub fn do(parser: Parser(a), then: fn(a) -> Parser(b)) -> Parser(b) {
  use ctx <- Parser
  use State(v, ctx) <- result.try(run(ctx, parser))
  run(ctx, then(v))
}

pub fn map(parser: Parser(a), with: fn(a) -> b) -> Parser(b) {
  use vs <- do(parser)
  return(with(vs))
}

pub fn drop(parser: Parser(a), then: fn() -> Parser(b)) -> Parser(b) {
  do(parser, fn(_) { then() })
}

pub fn or(first: Parser(a), second: Parser(a)) -> Parser(a) {
  use ctx <- Parser
  result.or(run(ctx, first), run(ctx, second))
}

pub fn lookahead(parser: Parser(v)) -> Parser(v) {
  use ctx <- Parser
  let offset = ctx.offset

  case run(ctx, parser) {
    Error(Nil) -> Error(Nil)
    Ok(State(v, ctx)) -> Ok(State(v, Context(..ctx, offset: offset)))
  }
}

pub fn negative_lookahead(parser: Parser(v)) -> Parser(Nil) {
  use ctx <- Parser
  let offset = ctx.offset

  case run(ctx, parser) {
    Error(Nil) -> Ok(State(Nil, Context(..ctx, offset: offset)))
    Ok(_) -> Error(Nil)
  }
}

pub fn one_of(parsers: List(Parser(v))) -> Parser(v) {
  use ctx <- Parser
  use _, parser <- list.fold_until(parsers, Error(Nil))
  let result = run(ctx, parser)
  use <- bool.guard(result == Error(Nil), list.Continue(result))
  list.Stop(result)
}

pub fn end() -> Parser(Nil) {
  use ctx <- Parser
  use <- bool.guard(ctx.offset < ctx.length, Error(Nil))
  Ok(State(Nil, ctx))
}

pub fn many(parser: Parser(v)) -> Parser(List(v)) {
  or(some(parser), return([]))
}

pub fn some(parser: Parser(v)) -> Parser(List(v)) {
  use first <- do(parser)
  use rest <- do(many(parser))
  return([first, ..rest])
}

pub fn satisfy(pred: fn(String) -> Bool) -> Parser(String) {
  use grapheme <- do(one())
  use <- bool.guard(pred(grapheme), return(grapheme))
  fail()
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
      let rest = string.join(rest, "")
      use <- drop(string(rest))
      return(want)
    }
  }
}

pub fn ascii_lowercase() -> Parser(String) {
  use v <- satisfy
  string.contains("abcdefgijklmnopqrstuvwxyz", v)
}

pub fn ascii_uppercase() -> Parser(String) {
  use v <- satisfy
  string.contains("ABCDEFGIJKLMNOPQRSTUVWXYZ", v)
}

pub fn digit() -> Parser(String) {
  use v <- satisfy
  string.contains("01234567890", v)
}

pub fn ascii_alphanumeric() -> Parser(String) {
  one_of([ascii_lowercase(), ascii_uppercase(), digit()])
}

pub fn digits() -> Parser(String) {
  use digits <- map(some(digit()))
  string.join(digits, "")
}

pub fn integer() -> Parser(Int) {
  use digits <- do(digits())

  case int.parse(digits) {
    Error(Nil) -> fail()
    Ok(integer) -> return(integer)
  }
}

pub fn float() -> Parser(Float) {
  use integer <- do(digits())
  use dot <- do(grapheme("."))
  use decimal <- do(digits())

  case float.parse(integer <> dot <> decimal) {
    Error(Nil) -> fail()
    Ok(float) -> return(float)
  }
}
