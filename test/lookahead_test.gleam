import konbini.{choice, parse, try}
import konbini/parsers.{ascii_lowercase, base10_digit, grapheme, surrounded_by}
import showtime/tests/should

pub fn ll_fail_test() {
  let parser = {
    let token = surrounded_by(_, grapheme("("), grapheme(")"))
    let digits = token(base10_digit())
    let letters = token(ascii_lowercase())
    choice(letters, digits)
  }

  parse("(1)", parser)
  |> should.be_error()
}

pub fn ll_ok_test() {
  let parser = {
    let token = surrounded_by(_, grapheme("("), grapheme(")"))
    let digits = token(base10_digit())
    let letters = token(ascii_lowercase())
    choice(try(letters), digits)
  }

  parse("(1)", parser)
  |> should.equal(Ok("1"))
}
