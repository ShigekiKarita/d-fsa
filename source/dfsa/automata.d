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


struct Epsilon {}

/// Transition : (current state, input symbol or eps) -> [next states]
struct NFA(State, Input, alias Transition) {
    State start;
    Set!State accept;
}

/// Transition : (current state, input symbol) -> next state
struct DFA(State, Input, alias trans) {
    State start;
    Set!State acceptStates;
    alias transition = binaryFun!trans;
    alias This = typeof(this);

    struct Runtime {
        const This* outer;
        State state;
        alias outer this;

        void move(Input i) {
            this.state = transition(state, i);
        }

        bool accept() {
            return this.acceptStates.canFind(this.state);
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


// @nogc pure
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
    auto transition(int state, string c) {
        if (state == 0 && c == "a") return set(1, 2);
        if (state == 1 && c == "b") return set(2);
        if (state == 2 && c == "") return set(0);
        return set!int();
    }

    alias N0 = NFA!(int, string, transition);
    N0 n = { start: 0, accept: set(2) };
    // writeln(n);

    /**
       DFA example
       -> (1) -- a --> (2) -- b --> [3]
    */
    auto dfaTransition(int state, string c) {
        if (state == 1 && c == "a") return 2;
        if (state == 2 && c == "b") return 3;
        return 0;
    }

    alias D0 = DFA!(int, string, dfaTransition);
    static immutable D0 d = { start: 1, acceptStates: set(3) };
    static immutable i0 = ["a", "b"];
    assert(d.runtime.accept(i0));
    static immutable i1 = ["b", "a"];
    assert(!d.runtime.accept(i1));
}
