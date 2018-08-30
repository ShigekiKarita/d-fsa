module dfsa.ast;

import dfsa.set;
import std.format : format;

import dfsa.automata;
import dfsa.builder;

/**
   AST nodes

   Example:

   a|(bc)* => Union(Char('a'), Star(Concat(Char('b'), Char('c'))))
*/
interface AST {
    alias Fragment = NFAFragment!(int, dchar);

    Fragment assemble(scope ref Context ctx) const;

    bool opEquals(Object that) const;

    string toString() const;
}

class Char : AST {
    dchar data;
    this(dchar d) {
        this.data = d;
    }

    override Fragment assemble(scope ref Context ctx) const {
        auto s1 = ctx.newState();
        auto s2 = ctx.newState();
        Fragment ret = {start: s1, acceptSet: set(s2)};
        ret.connect(s1, this.data, s2);
        return ret;
    }

    override bool opEquals(Object that) const {
        if (auto c = cast(typeof(this)) that) {
            return this.data == c.data;
        }
        return false;
    }

    override string toString() const {
        return format!"'%s'"(this.data);
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
        auto a = merge(orig.acceptSet[], [s]);
        Fragment ret = {map: orig.map.dup, start: s, acceptSet: a};
        ret.connect(s, epsilon!dchar, orig.start);

        foreach (state; orig.acceptSet) {
            ret.connect(state, epsilon!dchar, orig.start);
        }
        return ret;
    }

    override bool opEquals(Object that) const {
        if (auto s = cast(Star) that) {
            return this.node == s.node;
        }
        return false;
    }

    override string toString() const {
        return format!"Star(%s)"(this.node);
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
        auto a = merge(l.acceptSet[], r.acceptSet[]);
        auto s = ctx.newState();
        Fragment ret = {start:s, map: m, acceptSet: a};
        ret.connect(s, epsilon!dchar, l.start);
        ret.connect(s, epsilon!dchar, r.start);
        return ret;
    }

    override bool opEquals(Object that) const {
        if (auto u = cast(typeof(this)) that) {
            return (this.left == u.left && this.right == u.right)
                || (this.left == u.right && this.right == u.left);
        }
        return false;
    }

    override string toString() const {
        return format!"Union(%s, %s)"(this.left, this.right);
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
            ret.connect(state, epsilon!dchar, r.start);
        }
        return ret;
    }

    override bool opEquals(Object that) const {
        if (auto c = cast(typeof(this)) that) {
            return this.left == c.left && this.right == c.right;
        }
        return false;
    }

    override string toString() const {
        return format!"Concat(%s, %s)"(this.left, this.right);
    }
}

unittest {
    auto c0 = new Char('a');
    auto c1 = new Char('a');
    assert(c0 == c1);

    // union can be filpped (a*)|b == b|(a*)
    auto u0 = new Union(new Star(new Char('a')),
                        new Char('b'));
    auto u1 = new Union(new Char('b'),
                        new Star(new Char('a')));
    assert(u0 == u1);
}
