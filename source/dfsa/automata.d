module dfsa.automata;

import dfsa.set;
import std.functional : binaryFun;

extern (C):
// @nogc:

// struct Set(T) {
//     immutable T[] data;
//     alias data this;
// }

// struct MutableSet(T) {
//     // T[] data;
//     // alias data this;
//     RedBlackTree!T data;
//     void insert
// }


enum epsilon(T : dchar) = dchar.init;
enum epsilon(T : string) = "";

struct ArcT(State, Input) {
    immutable State state;
    immutable Input input;

    auto toString() {
        import std.format;
        if (input == epsilon!Input) {
            return format!"Arc(%s, <eps>)"(state);
        }
        return format!"Arc(%s, %s)"(state, input);
    }
}

/// Transition : (current state, input symbol or eps) -> [next states]
struct NFA(State, Input) {
    alias Arc = ArcT!(State, Input);
    State start;
    Set!State accept;
    Set!State[Arc] map;

    pure transition(State s, Input i) const {
        return this.map.get(Arc(s, i), set!State());
    }

    pure epsExpand(scope const Set!State s) const {
        auto q = s.dup;
        Set!State ret;
        while (!q.empty) {
            auto stat = q.pop();
            auto nexts = this.transition(stat, epsilon!Input);
            ret.insert(stat);
            foreach (n; nexts) {
                if (n !in ret) {
                    q.insert(n);
                }
            }
        }
        return ret;
    }
}

/// Transition : (map, current state, input symbol) -> next state
struct DFA(State, Input, alias trans) {
    alias Arc = ArcT!(State, Input);
    State start;
    Set!State accepts;
    State[Arc] map;

    alias transition = trans;
    alias This = typeof(this);

    struct Runtime {
        const This* outer;
        State state;
        alias outer this;

        void move(Input i) {
            this.state = transition(this.map, state, i);
        }

        pure bool accept() const {
            return this.state in this.accepts;
        }

        bool accept(scope const Input[] inputs) {
            foreach (i; inputs) this.move(i);
            return this.accept;
        }
    }

    pure runtime() const {
        return Runtime(&this, this.start);
    }
}

unittest {
    /**
       NFA example
       | -> (0) --- a --> (1)
       |    ^  \           |
       |    |  |           b
       |   eps |           |
       |    |  |           v
       |    |  \--- a --> [2]
       |    \-------------/
    */

    alias Arc = ArcT!(int, string);

    enum NFA!(int, string) n = {
        start: 0,
        accept: set(2),
        map: [Arc(0, "a"): set(1, 2),
              Arc(1, "b"): set(2),
              Arc(2, ""):  set(0)]
    };
    import std.stdio;
    writeln(n);

    /**
       DFA example
       -> (1) -- a --> (2) -- b --> [3]
    */
    enum dfaMap = [
        Arc(1, "a"): 2,
        Arc(2, "b"): 3,
        ];

    auto dfaTransition(const int[Arc] map, int state, string c) {
        return map.get(Arc(state, c), 0);
    }
    enum DFA!(int, string, dfaTransition) d = { start: 1, accepts: set(3), map: dfaMap };
    static immutable i0 = ["a", "b"];
    static assert(d.runtime.accept(i0));
    static immutable i1 = ["b", "a"];
    static assert(!d.runtime.accept(i1));
}
