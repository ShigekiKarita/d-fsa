module dfsa.builder;


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

    @disable this(this);
    @disable new(size_t);

    struct Key {
        immutable State state;
        immutable Input input;
    }

    immutable State start;
    immutable Set!State acceptSet;
    alias Output = MutableSet!State;
    Output[Key] map;

    auto build() {
        auto trans(State s, Input i) {
            return this.map.get(Key(s, i), MutableSet!State([]));
        }
        return NFA!(State, Input, trans)(this.start, this.acceptSet);
    }

    void connect(State src, Input input, State dst) {
        auto key = Key(src, input);
        if (key !in this.map) {
            this.map[key] = Output();
        }
        this.map[key] ~= dst;
    }

    auto compose(scope const ref typeof(this) other) {
        auto ret = this.skelton();
        // TODO find much better way to compose assoc
        foreach (k, v; other.map) {
            ret.map[k] = Output(v.dup);
        }
        return ret;
    }

    auto skelton() {
        NFAFragment nfr;
        nfr.map = this.map.dup;
        return nfr;
    }
}
