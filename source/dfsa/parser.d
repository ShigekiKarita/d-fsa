module dfsa.parser;

import dfsa.lexer : Lexer, Token, TokenKind;
import dfsa.automata;
import dfsa.builder;
import dfsa.ast;


/**
   expression := subexpr EOF
   subexpr    := seq '|' subexpr | seq
   seq        := subseq | ''
   subseq     := star subseq | star
   star       := factor '*' | factor
   factor     := '(' subexpr ')' | CHARACTER
*/
struct Parser {
    Lexer lexer;
    Token look;

    this(Lexer lex) {
        this.lexer = lex;
        this.look = this.lexer.front;
        this.move();
    }

    void move() {
        this.look = this.lexer.front;
        this.lexer.popFront();
    }

    void match(TokenKind kind) {
        assert(this.look.kind == kind);
        this.move();
    }

    // void popFront() {
    //     this.look = this.lexer.front;
    //     this.lexer.popFront();
    // }

    /// expr := subexpr EOF
    auto expr() {
        AST node = this.subexpr();
        this.match(TokenKind.eof);
        return node;
    }

    /// subexpr := seq '|' subexpr '|' seq
    AST subexpr() {
        AST node = this.seq();
        if (this.look.kind == TokenKind.opUnion) {
            this.match(TokenKind.opUnion);
            AST n = this.subexpr();
            node = new Union(node, n);
        }
        return node;
    }

    /// seq := subseq | ''
    AST seq() {
        switch (this.look.kind) {
        case TokenKind.leftParen:
        case TokenKind.character:
            // TODO: do not hard code here. infer: subseq -> star -> factor => '(' or CHARACTER
            return this.subseq();
        default:
            // TODO: use final switch
            return new Char(dchar.init);
        }
    }

    /// subseq := star subseq | star
    AST subseq() {
        AST node = this.star();
        // same to seq
        switch (this.look.kind) {
        case TokenKind.leftParen:
        case TokenKind.character:
            return new Concat(node, this.subseq());
        default:
            return node;
        }
    }

    /// star := factor '*' | factor
    AST star() {
        AST node = this.factor();
        if (this.look.kind == TokenKind.opStar) {
            this.match(TokenKind.opStar);
            node = new Star(node);
        }
        return node;
    }

    /// factor := '(' subexpr ')' | CHARACTER
    AST factor() {
        if (this.look.kind == TokenKind.leftParen) {
            // factor -> '(' subexpr ')'
            this.match(TokenKind.leftParen);
            AST node = this.subexpr();
            this.match(TokenKind.rightParen);
            return node;
        } else {
            // factor -> CHARACTER
            AST node = new Char(this.look.symbol);
            this.match(TokenKind.character);
            return node;
        }
    }
}

unittest {
    import std.stdio;
    enum p = Parser(Lexer("a|(bc)*"));
    static const ast = p.expr();
    static const ast0 = new Union(new Char('a'), new Star(new Concat(new Char('b'), new Char('c'))));
    writeln(ast0);
    static assert(ast0.toString == "Union('a', Star(Concat('b', 'c')))");
    static assert(ast == ast0);

    // TODO CTFE
    Context c;
    auto fragment = ast.assemble(c);
    writeln(fragment.build());
}
