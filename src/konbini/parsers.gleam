import konbini.{type Parser, drop, keep, succeed}

pub fn surrounded_by(
  parser: Parser(i, v),
  open: Parser(i, a),
  close: Parser(i, b),
) -> Parser(i, v) {
  use <- drop(open)
  use token <- keep(parser)
  use <- drop(close)
  succeed(token)
}
