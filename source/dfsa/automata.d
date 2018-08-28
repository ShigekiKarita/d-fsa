module dfsa.automata;

import std.container.rbtree : RedBlackTree, redBlackTree;
import std.functional : binaryFun;
import std.algorithm : canFind;

extern (C):
@nogc:

struct Set(T) {
    immutable T[] data;
    alias data this;
}

struct MutableSet(T) {
    T[] data;
    alias data this;
}


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
            return this.acceptStates.data.canFind(this.state);
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


@nogc pure
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
        if (state == 0 && c == "a") return Set!int([1, 2]);
        if (state == 1 && c == "b") return Set!int([2]);
        if (state == 2 && c == "") return Set!int([0]);
        return Set!int([]);
    }

    alias N0 = NFA!(int, string, transition);
    static immutable a0 = [2];
    N0 n = { start: 0, accept: Set!int(a0) };
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
    static immutable a1 = [3];
    static immutable D0 d = { start: 1, acceptStates: Set!int(a1) };
    static immutable i0 = ["a", "b"];
    static assert(d.runtime.accept(i0));
    static immutable i1 = ["b", "a"];
    static assert(!d.runtime.accept(i1));
}
