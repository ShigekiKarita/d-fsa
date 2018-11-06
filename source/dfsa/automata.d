module dfsa.automata;

import dfsa.set;
import std.functional : binaryFun;

// @nogc:
// nothrow:
// pure:

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

    pure transition(const State s, const Input i) const {
        return this.map.get(Arc(s, i), set!State());
    }

    pure epsExpand(S: Set!State)(const auto ref S s) const {
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

///
pure @safe @nogc unittest {
    alias N = NFA!(int, string);
    alias Arc = N.Arc;
    enum N n = {
        start: 0,
        accept: set(2),
        map: [Arc(0, "a"): set(1, 2),
              Arc(1, "b"): set(2),
              Arc(2, ""):  set(0),
              Arc(0, ""): set(3)]
    };

    // reachable states by epsilon transitions
    static assert(n.epsExpand(set(0)) == set(0, 3));
    static assert(n.epsExpand(set(1)) == set(1));
    static assert(n.epsExpand(set(2)) == set(0, 2, 3));
    static assert(n.epsExpand(set(3)) == set(3));
}


/// Transition : (map, current state, input symbol) -> next state
struct DFA(State, Input, alias trans, Accepts = Set!State) {
    alias Arc = ArcT!(State, Input);
    State start;
    Accepts accepts;
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
            return this.accepts.canFind(this.state);
        }

        bool accept(scope const Input[] inputs) {
            foreach (i; inputs) this.move(i);
            return this.accept;
        }
    }

    pure runtime() {
        return Runtime(&this, this.start);
    }
}

///
pure nothrow @safe @nogc unittest {
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

auto nfa2dfa(State, Input)(NFA!(State, Input) nfa) {
    import dfsa.set : DisjointSet;
    alias Arc = ArcT!(Set!State, Input);

    auto trans(const Set!State[Arc] map, Set!State state, Input c) {
        Set!State ret;
        foreach (elem; state) {
            ret = ret ~ nfa.transition(elem, c);
        }
        return nfa.epsExpand(ret);
    }

    alias D = DFA!(Set!State, Input, trans, DisjointSet!State);

    D dfa = {
        start: nfa.epsExpand(set(nfa.start)),
        accepts: DisjointSet!State(nfa.accept)
    };
    return dfa;
}


auto nfa2dfa(State = int, Input = dchar, NFA!(int, dchar) nfa)() {
    import dfsa.set : DisjointSet;
    alias Arc = ArcT!(Set!State, Input);

    auto trans(const Set!State[Arc] map, Set!State state, Input c) {
        Set!State ret;
        foreach (elem; state) {
            ret = ret ~ nfa.transition(elem, c);
        }
        return nfa.epsExpand(ret);
    }

    alias D = DFA!(Set!State, Input, trans, DisjointSet!State);

    D dfa = {
        start: nfa.epsExpand(set(nfa.start)),
        accepts: DisjointSet!State(nfa.accept)
    };
    return dfa;
}


unittest {
    alias Arc = ArcT!(int, string);
    enum NFA!(int, string) n = {
        start: 0,
        accept: set(2),
        map: [Arc(0, "a"): set(1, 2),
              Arc(1, "b"): set(2),
              Arc(2, ""):  set(0)]
    };

    enum d = nfa2dfa(n);
    import std.stdio;
    writeln(d);
}
