import std.stdio;

import std.container.rbtree : RedBlackTree, redBlackTree;

/** Roadmap

    1. NFA/DFA
    2. Syntax tree
    3. Syntax tree to NFA
    4. NFA to DFA
    5. bind all
*/


/** Rules

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

@nogc extern (C) {

    enum Syntax {
        or = "|",
        repeat = "*",
        lpar = "(",
        rpar = ")",
        escape = "\\"
    }

    struct Set(T) {
        immutable T[] data;
        alias data this;
    }

    struct Epsilon {}

    import std.functional : binaryFun;

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
                import std.algorithm : canFind;
                return this.acceptStates.data.canFind(this.state);
            }

            bool accept(Input[] inputs) {
                foreach (i; inputs) this.move(i);
                return this.accept;
            }
        }

        auto runtime() {
            return Runtime(&this, this.start);
        }
    }
}

unittest {
    /** NFA example
    -> (0) --- a --> (1)
       ^  \           |
       |  |           b
      eps |           |
       |  |           v
       |  \--- a --> [2]
       \-------------/
    */
    auto transition(int state, string c) {
        if (state == 0 && c == "a") return Set!int([1, 2]);
        if (state == 1 && c == "b") return Set!int([2]);
        if (state == 2 && c == "") return Set!int([0]);
        return Set!int([]);
    }

    alias N0 = NFA!(int, string, transition);
    N0 n = { start: 0, accept: Set!int([2]) };
    writeln(n);

    /** DFA example
       -> (1) -- a --> (2) -- b --> [3]
     */
    auto dfaTransition(int state, string c) {
        if (state == 1 && c == "a") return 2;
        if (state == 2 && c == "b") return 3;
        return 0;
    }

    alias D0 = DFA!(int, string, dfaTransition);
    D0 d = { start: 1, acceptStates: Set!int([3]) };
    assert(d.runtime.accept(["a", "b"]));
    assert(!d.runtime.accept(["b", "a"]));
}

version (Have_d_fsa) {
    void main() {
        writeln("DONE.");
    }
} else version (unittest) {}
