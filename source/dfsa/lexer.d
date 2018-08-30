module dfsa.lexer;

/** Lexing Rules

    core syntax
    -----------
    A|B     set of string A or B.
    AB 	    concat string A and B.
    A*      repeated string of A. e.g., AA* => AA, AAA
    (A)     stronger match.
    \       escaped symbol. e.g., \(

    practical syntax
    ----------------
    a+      aa*
    a?      a|
    a{1,2}  a|aa
    [abc]   (a|b|c)

    position syntax
    ---------------
    ^       head of line.
    $       tail of line.
    \b      word boundary.

    back reference
    --------------
    \1      reference of 1st matched string
*/

// @nogc
extern (C):

enum Syntax {
    or = "|",
    repeat = "*",
    lpar = "(",
    rpar = ")",
    escape = "\\"
}

enum TokenKind {
    character = 0,
    opUnion = 1,
    opStar = 2,
    leftParen = 3,
    rightParen = 4,
    eof = 5
}

struct Token {
    dchar symbol;
    TokenKind kind;
}

struct Lexer {
    import std.range;
    // import std.string;
    string data;

    alias data this;

    pure front() const {
        if (this.empty) {
            import dfsa.automata : epsilon;
            return Token(epsilon!dchar, TokenKind.eof);
        }

        auto c = this.data.front;
        switch (c) {
        case '(':  return Token(c, TokenKind.leftParen);
        case ')':  return Token(c, TokenKind.rightParen);
        case '|':  return Token(c, TokenKind.opUnion);
        case '*':  return Token(c, TokenKind.opStar);
        case '\\':
            auto c2 = this.data.take(2);
            c2.popFront();
            return Token(c2.front, TokenKind.character);
        default:   return Token(c, TokenKind.character);
        }
    }

    void popFront() {
        if (!this.empty) {
            // "ab" -> "a"
            // "\\|a" -> "a"
            this.data.popFrontN(data.front == '\\' ? 2 : 1);
        }
    }
}

unittest {
    auto l0 = Lexer("a\\|\\(|b(*)");
    assert(l0.front == Token('a', TokenKind.character));
    l0.popFront();
    assert(l0.front == Token('|', TokenKind.character));
    assert(l0.front == Token('|', TokenKind.character));
    l0.popFront();
    assert(l0.front == Token('(', TokenKind.character));
    assert(l0.front == Token('(', TokenKind.character));
    l0.popFront();
    assert(l0.front == Token('|', TokenKind.opUnion));
    l0.popFront();
    assert(l0.front == Token('b', TokenKind.character));
    l0.popFront();
    assert(l0.front == Token('(', TokenKind.leftParen));
    l0.popFront();
    assert(l0.front == Token('*', TokenKind.opStar));
    l0.popFront();
    assert(l0.front == Token(')', TokenKind.rightParen));
}
