module dfsa.regexp;
import dfsa.automata;
import dfsa.parser : parseNFA;

struct Regexp {
    alias DFA = typeof(parseNFA(string.init).nfa2dfa);
    DFA dfa;

    this(string pattern) {
        this.dfa = nfa2dfa(parseNFA(pattern));
    }

    bool match(dstring s) {
        return this.dfa.runtime.accept(s);
    }
}


unittest
{
    {
        auto r = Regexp("a");
        assert(r.match("a"));
        assert(!r.match("b"));
    }
    {
        auto r = Regexp("(ABC*|abc*)*");
        assert(r.match("ABC"));
        assert(!r.match("ABBC"));
        assert(r.match("abcccABABC"));
        assert(!r.match("abABAb"));
        assert(r.match(""));
    }
    enum nfa = parseNFA("(ABC*|abc*)*");
    // alias NFA = typeof(parseNFA(string.init));
    enum dfa = nfa2dfa!(int, dchar, nfa)();
    alias match = (dstring s) => dfa.runtime.accept(s);
    static assert(match("ABC"));
    static assert(!match("ABBC"));
    static assert(match("abcccABABC"));
    static assert(!match("abABAb"));
    static assert(match(""));
}
