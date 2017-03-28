module dprolog.Term;

import dprolog.Token,
       dprolog.util;

import std.stdio,
       std.conv,
       std.algorithm,
       std.range;

class Term {
    Token token;
    Term[] children;
    immutable bool isDetermined;
    immutable bool isCompound;

    this(Token token, Term[] children) {
        this.token = token;
        this.children = children;
        this.isDetermined = (token.instanceOf!Atom && children.all!(c => c.isDetermined)) || token.instanceOf!Number;
        this.isCompound = token==Operator.comma || token==Operator.semicolon;
    }

    bool isAtom() @property {
        return token.instanceOf!Atom && !token.instanceOf!Functor && !token.instanceOf!Operator;
    }

    bool isNumber() @property {
        return token.instanceOf!Number;
    }

    bool isVariable() @property {
        return token.instanceOf!Variable;
    }

    bool isStructure() @property {
        return token.instanceOf!Functor || (token.instanceOf!Operator && token!=Operator.pipe);
    }

    bool isList() @property {
        return token == Operator.pipe;
    }

    override string toString() {
        if (isList) {
            return "[" ~ children.front.to!string ~ " | " ~ children.back.to!string ~ "]";
        } else if (isStructure) {
            return token.lexeme.to!string ~ "(" ~ children.map!(c => c.to!string).join(", ") ~ ")";
        } else {
            return token.lexeme.to!string;
        }
    }

    invariant {
        assert(
            (token.instanceOf!Atom                      ) ||
            (token.instanceOf!Number   && children.empty) ||
            (token.instanceOf!Variable && children.empty)
        );
        assert(token != Operator.rulifier);
        assert(token != Operator.querifier);
    }


    /* ---------- Unit Tests ---------- */


    unittest {
        writeln(__FILE__, ": test kinds");

        Atom atom = new Atom("a", -1, -1);
        Number num = new Number("1", -1, -1);
        Variable var = new Variable("X", -1, -1);
        Functor fun = new Functor(atom);
        Operator pipe = cast(Operator) Operator.pipe;

        Term atomT = new Term(atom, []);
        Term numT = new Term(num, []);
        Term varT = new Term(var, []);
        Term funT = new Term(fun, [atomT, varT, numT]);
        Term listT = new Term(pipe, [funT,  new Term(pipe, [numT, varT])]);

        import std.range, std.array, std.algorithm, std.functional;
        bool function(Term, int) validate = (term, index) => term.adjoin!(
            //          0,               1,                 2,                  3,             4
            t => t.isAtom, t => t.isNumber, t => t.isVariable, t => t.isStructure, t => t.isList
        ).array.enumerate.all!(a => a.value == (a.index == index));

        assert(validate(atomT, 0));
        assert(validate(numT, 1));
        assert(validate(varT, 2));
        assert(validate(funT, 3));
        assert(validate(listT, 4));
        assert(validate(listT.children.back, 4));
        assert(validate(listT.children.back.children.back, 2));
    }
}