module dfsa.set;

private import std.container.rbtree : RedBlackTree, redBlackTree;
alias Set = RedBlackTree;
alias set = redBlackTree;

bool canFind(T, alias less = "a < b", bool allowDuplicates = false)(const RedBlackTree!(T, less, allowDuplicates) rbt, T x) {
    return !rbt.equalRange(x).empty;
}

auto merge(R1, R2)(R1 r1, R2 r2) {
    import std.range : chain;
    return set(chain(r1, r2));
}
