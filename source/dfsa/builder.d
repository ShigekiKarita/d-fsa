module dfsa.builder;

import dfsa.set;

nothrow:

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
    import dfsa.automata;
    alias NFA_ = NFA!(State, Input);
    alias Arc = NFA_.Arc;

    @disable this(this);
    @disable new(size_t);

    // immutable
    State start;
    // immutable
    Output acceptSet;
    alias Output = Set!State;
    Output[Arc] map;

    auto build() {
        auto trans(State s, Input i) {
            return this.map.get(Arc(s, i), set!State());
        }
        return NFA_(this.start, this.acceptSet, this.map);
    }

    void connect(State src, Input input, State dst) {
        auto key = Arc(src, input);
        if (key !in this.map) {
            this.map[key] = set!State();
        }
        this.map[key].insert(dst);
    }

    auto compose(scope ref typeof(this) other) {
        auto ret = this.skelton();
        // TODO find much better way to compose assoc
        foreach (k, v; other.map) {
            ret.map[k] = set(v[]);
        }
        return ret;
    }

    auto skelton() {
        NFAFragment nfr;
        nfr.map = this.map.dup;
        return nfr;
    }
}
