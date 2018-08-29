module dfsa.set;
/**
   TODO support "CTFE" compile time function evaluation for set ops
*/


version (dfsa_set_rbtree) {
    private import std.container.rbtree : RedBlackTree, redBlackTree;
    alias Set = RedBlackTree;
    alias set = redBlackTree;

    bool canFind(T, alias less = "a < b", bool allowDuplicates = false)(const RedBlackTree!(T, less, allowDuplicates) rbt, T x) {
        return !rbt.equalRange(x).empty;
    }

    unittest {
        assert(1 in set(0, 1, 2));
    }
}
else {
    struct Set(T) {
        pure auto toString() const {
            import std.conv : to;
            return this.assoc.keys().to!string;
        }

        nothrow:

        private struct Empty {}
        Empty[T] assoc;
        alias assoc this;

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

        auto opBinaryRight(string op)(T x) {
            static if (op == "in") {
                return this.canFind(x);
            } else {
                static assert(false);
            }
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

        enum s0 = set(0, 1, 2);
        static assert(1 in s0);
        static assert(-1 !in s0);
        static assert(set(0, 1, 2) == set(1, 0, 2));

        enum s1 = { auto s = set(0, 1);
                    s.insert(2);
                    return s; }();
        static assert(2 in s1);
        static assert(-2 !in s1);
    }
}

auto merge(R1, R2)(R1 r1, R2 r2) {
    import std.range : chain;
    return set(chain(r1, r2));
}