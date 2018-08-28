module dfsa.parser;

import dfsa.lexer : Lexer, Token, TokenKind;
import dfsa.automata;

struct Context {
    @disable this(this);
    @disable new(size_t);

    int stateCount = 0;

    auto newState() {
        ++this.stateCount;
        return this.stateCount;
    }
}

struct NFAFragment(State, Input){
    @disable this(this);
    @disable new(size_t);

    struct Key {
        immutable State state;
        immutable Input input;
    }

    immutable State start;
    immutable Set!State acceptSet;
    MutableSet!State[Key] map;

    auto build() {
        auto trans(State s, Input i) {
            return this.map.get(Key(s, i), MutableSet!State([]));
        }
        return NFA!(State, Input, trans)(this.start, this.acceptSet);
    }

    void connect(State src, Input input, State dst) {
        this.map[Key(src, input)] ~= dst;
    }

    auto compose(scope const ref typeof(this) other) {
        auto ret = this.skelton();
        // TODO find much better way to compose assoc
        foreach (k, v; other.map) {
            ret.map[k] = v.dup;
        }
        return ret;
    }

    auto skelton() {
        NFAFragment nfr;
        nfr.map = this.map.dup;
        return nfr;
    }
}

/**
   AST nodes

   Example:

   a|(bc)* => Union(Char('a'), Star(Concat(Char('b'), Char('c'))))
*/
interface AST {
    alias Fragment = NFAFragment!(int, dchar);

    Fragment assemble(scope ref Context ctx) const;
}

class Character : AST {
    dchar data;
    this(dchar d) {
        this.data = d;
    }

    override Fragment assemble(scope ref Context ctx) const {
        auto s1 = ctx.newState();
        auto s2 = ctx.newState();
        Fragment ret = {start: s1, acceptSet: Set!int([s2])};
        ret.connect(s1, this.data, s2);
        return ret;
    }
}
class Star : AST {
    AST node;
    this(AST node) {
        this.node = node;
    }

    override Fragment assemble(scope ref Context ctx) const {
        auto orig = this.node.assemble(ctx);
        auto s = ctx.newState();
        // FIXME
        immutable a = cast(immutable(int[]))(orig.acceptSet ~ [s]);
        Fragment ret = {map: orig.map.dup, start: s, acceptSet: Set!int(a)};
        ret.connect(s, dchar.init, orig.start);

        foreach (state; orig.acceptSet) {
            ret.connect(state, dchar.init, orig.start);
        }
        return ret;
    }
}
class Union : AST {
    AST left, right;
    this(AST left, AST right) {
        this.left = left;
        this.right = right;
    }

    override Fragment assemble(scope ref Context ctx) const {
        auto l = this.left.assemble(ctx);
        auto r = this.right.assemble(ctx);
        auto m = l.compose(r).map;
        auto a = l.acceptSet ~ r.acceptSet;
        auto s = ctx.newState();
        Fragment ret = {start:s, map: m, acceptSet: Set!int(a)};
        ret.connect(s, dchar.init, l.start);
        ret.connect(s, dchar.init, r.start);
        return ret;
    }
}
class Concat : AST {
    AST left, right;
    this(AST left, AST right) {
        this.left = left;
        this.right = right;
    }

    override Fragment assemble(scope ref Context ctx) const {
        auto l = this.left.assemble(ctx);
        auto r = this.right.assemble(ctx);
        auto m = l.compose(r).map;
        Fragment ret = {start:l.start, map: m, acceptSet: r.acceptSet};
        foreach (state; l.acceptSet) {
            ret.connect(state, dchar.init, r.start);
        }
        return ret;
    }
}

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
        this.popFront();
    }

    void match(TokenKind kind) {
        assert(this.look.kind == kind);
        this.popFront();
    }

    void popFront() {
        this.look = this.lexer.front;
        this.lexer.popFront();
    }

    /// expr := subexpr EOF
    auto expr() {
        AST node = this.subexpr();
        this.match(TokenKind.eof);
        Context c;
        auto fragment = node.assemble(c);
        return fragment.build();
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
            return new Character(dchar.init);
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
            AST node = new Character(this.look.symbol);
            this.match(TokenKind.character);
            return node;
        }
    }
}

unittest {
    import std.stdio;
    auto p = Parser(Lexer("a|(bc)*"));
    writeln(p);
}
