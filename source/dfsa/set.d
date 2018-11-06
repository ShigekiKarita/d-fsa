module dfsa.set;
/**
   TODO support "CTFE" compile time function evaluation for set ops
*/

pure:
nothrow:

// this rbtree set is obsolete but I remain this for perfomance comparison.
version (dfsa_set_rbtree) {
    private import std.container.rbtree : RedBlackTree, redBlackTree;
    alias Set = RedBlackTree;
    alias set = redBlackTree;

    unittest {
        assert(1 in set(0, 1, 2));
    }
}
// this assoc set is being used for runtime/compile-time set
else {
    struct Set(T) {
        pure auto toString() const {
            import std.format : format;
            return this.assoc.keys().format!"set(%(%s, %))";
        }

        nothrow:

        struct Empty {}
        Empty[T] assoc;

        pure length() const {
            return this.assoc.length;
        }

        pure empty() const {
            return this.length == 0;
        }

        pure opSlice() const {
            return this.assoc.keys();
        }

        @safe void insert(T x) {
            assoc[x] = Empty();
        }

        pure bool canFind(T x) const {
            if (__ctfe) {
                // FIXME do not linear search
                foreach (k; this) {
                    if (k == x) return true;
                }
                return false;
            } else {
                return (x in this.assoc) != null;
            }
        }

        pure opBinary(string op)(T x) const {
            static if (op == "~") {
                return merge(this[], [x]);
            } else {
                static assert(false);
            }
        }

        pure opBinary(string op)(const typeof(this) r) const {
            static if (op == "~") {
                return merge(this[], r.dup[]);
            } else {
                static assert(false);
            }
        }

        pure opBinaryRight(string op)(T x) const {
            static if (op == "~") {
                return merge(this, [x]);
            } static if (op == "in") {
                return this.canFind(x);
            } else {
                static assert(false);
            }
        }

        @safe auto opOpAssign(string op)(T x) {
            static if (op == "~") {
                this.insert(x);
                return this;
            } else {
                static assert(false);
            }
        }

        auto opOpAssign(string op)(typeof(this) r) {
            static if (op == "~") {
                foreach (x; r[]) this.insert(x);
                return this;
            } else {
                static assert(false);
            }
        }

        pure auto dup() const {
            return set(this[]);
        }

        bool remove(T x) {
            return this.assoc.remove(x);
        }

        T pop() {
            import std.range;
            auto f = this[].front;
            this.remove(f);
            return f;
        }

        auto clear() {
            return this.assoc.clear();
        }
    }

    auto set(T)(T[] xs...) {
        Set!T ret;
        foreach (x; xs) {
            ret.insert(x);
        }
        return ret;
    }

    import std.traits : isArray;
    import std.range : isInputRange;

    auto set(R)(R r) if (isInputRange!R && !isArray!R) {
        Set!(typeof(r.front)) ret;
        foreach (x; r) {
            ret.insert(x);
        }
        return ret;
    }

    // yes this is capable of ctfe
    unittest {
        import std.stdio;

        // simple ops
        enum s0 = set(0, 1, 2);
        static assert(s0.length == 3);
        static assert(1 in s0);
        static assert(-1 !in s0);
        static assert(set(0, 1, 2) == set(1, 0, 2));

        // mutations
        enum s1 = { auto s = set(0, 1);
                    s ~= 2;
                    s ~= set(3, 4, 5);
                    s.remove(5);
                    return s; }();
        static assert(s1 == set(0, 1, 2, 3, 4));
        static assert(3 in s1);
        static assert(-2 !in s1);

        // dup
        auto s2 = set(0, 1);
        auto s3 = s2.dup;
        assert(s2.remove(1));
        assert(!s2.remove(1));
        s2.clear();
        assert(s2.length == 0);
        assert(s3 == set(0, 1));
        static assert(set(0, 1, 2, 3, 4) == set(0, 1) ~ 2 ~ set(3, 4));

        // set of set
        import std.range : front;
        static assert(set(set(0))[].front == set(0));
        static assert(set(set(0, 1), set(0, 1)).length == 1);
        static assert(set(set(0), set(0, 1)).length == 2);
    }
}

auto merge(R1, R2)(R1 r1, R2 r2) {
    import std.range : chain;
    return set(chain(r1, r2));
}

/// because assoc (hashmap) indexing is O(1), I use smaller[i] in larger
struct IntersectRange(T) {

    typeof(Set!T.init[]) smaller;
    Set!T larger;

    this(Set!T a, Set!T b) {
        import std.range : front, empty, popFront;
        if (a.length > b.length) {
            this.larger = a;
            this.smaller = b[];
        } else {
            this.larger = b;
            this.smaller = a[];
        }
        while (!this.empty && this.smaller.front !in this.larger) {
            this.smaller.popFront;
        }
    }

    void popFront() {
        if (this.empty) return;
        import std.range : popFront, front;
        this.smaller.popFront();
        while (!this.empty && this.smaller.front !in this.larger) {
            this.smaller.popFront;
        }
    }

    @property
    pure T front() const {
        import std.range : front;
        return this.smaller.front;
    }

    @property
    pure bool empty() const {
        import std.range : empty;
        return this.smaller.empty;
    }
}

auto intersect(T)(Set!T a, Set!T b) {
    return IntersectRange!T(a, b);
}

unittest {
    enum iset = intersect(set(1, 2, 3), set(2, 3, 4));
    static assert(set(iset) == set(2, 3));
    static assert(isInputRange!(IntersectRange!int));
    static assert(intersect(set(1, 2), set(3, 4)).empty);
}

struct DisjointSet(T) {
    Set!T base;

    bool canFind(const Set!T other) const {
        foreach (o; other[]) {
            if (this.base.canFind(o)) {
                return true;
            }
        }
        return false;
    }
}
