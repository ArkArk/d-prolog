module dprolog.Lexer;

import dprolog.Token;

import std.stdio,
       std.conv,
       std.string,
       std.ascii,
       std.range,
       std.array,
       std.algorithm,
       std.regex,
       std.concurrency,
       std.container : DList;

class Lexer {

private:
    bool _isTokenized = false;
    auto _resultTokens = DList!Token();

    bool _hasError = false;
    string _errorMessage = "";

public:
    void run(immutable string src) {
        clear();
        tokenize(src);
    }

    Token[] get() in {
        assert(_isTokenized);
    } body {
        return _resultTokens.array;
    }

    bool hasError() @property {
        return _hasError;
    }

    string errorMessage() @property in {
        assert(hasError);
    } body {
        return _errorMessage;
    }

private:

    void clear() {
        _isTokenized = false;
        _resultTokens.clear;
        _hasError = false;
        _errorMessage = "";
    }

    void tokenize(immutable string src) {
        _resultTokens.clear;
        auto lookaheader = getLookaheader(src);
        while(!lookaheader.empty) {
            TokenGen tokenGen = getTokenGen(lookaheader);
            Token token = getToken(lookaheader, tokenGen);
            if (token !is null) {
                _resultTokens.insertBack(token);
            }
        }
        _isTokenized = true;
    }

    TokenGen getTokenGen(Generator!Node lookaheader) {
        Node node = lookaheader.front;
        char c = node.value.to!char;
        auto genR = [
            AtomGen,
            NumberGen,
            VariableGen,
            LParenGen,
            RParenGen,
            PeriodGen,
            EmptyGen
        ].find!(gen => gen.varidateHead(c));
        return genR.empty ? ErrorGen : genR.front;
    }

    Token getToken(Generator!Node lookaheader, TokenGen tokenGen) {
        if (lookaheader.empty) return null;
        Node node = getTokenNode(lookaheader, tokenGen);
        return tokenGen.getToken(node);
    }

    Node getTokenNode(Generator!Node lookaheader, TokenGen tokenGen) in {
        assert(!lookaheader.empty);
    } body {
        Node nowNode = lookaheader.front;
        bool existToken = tokenGen.varidate(nowNode.value);
        if (tokenGen.varidateHead(nowNode.value.to!char)) {
            nowNode = Node("", int.max, int.max);
            while(!lookaheader.empty) {
                Node tmpNode = nowNode ~ lookaheader.front;
                if (tokenGen.varidate(tmpNode.value)) {
                    nowNode = tmpNode;
                    existToken = true;
                } else if (existToken) {
                    break;
                }
                lookaheader.popFront;
            }
        }
        if (!existToken) {
            setErrorMessage(nowNode);
            clearLookaheader(lookaheader);
        }
        return nowNode;
    }

    void setErrorMessage(Node node) {
        _hasError = true;
        _errorMessage = "TokenError(" ~node.line.to!string~ ", " ~node.column.to!string~ "): cannot tokenize \"" ~node.value~ "\".";
    }

    Generator!Node getLookaheader(immutable string src) {
        return new Generator!Node({
            foreach(line, str; src.splitLines) {
                foreach(column, ch; str) {
                    Node(ch.to!string, line+1, column+1).yield;
                }
            }
        });
    }

    void clearLookaheader(Generator!Node lookaheader) {
        while(!lookaheader.empty) {
            lookaheader.popFront;
        }
    }

    struct TokenGen {
        immutable bool function(char) varidateHead;
        immutable bool function(string) varidate;
        immutable Token function(Node) getToken;
    }

    static TokenGen AtomGen = TokenGen(
        (char head)     => head.isLower || head=='\'' || Token.specialCharacters.canFind(head),
        (string lexeme) {
            static auto re = regex(r"([a-z][_0-9a-zA-Z]*)|('[^']*')|([" ~Token.specialCharacters.escaper.to!string~ r"]+)");
            auto res = lexeme.matchFirst(re);
            return !res.empty && res.front==lexeme;
        },
        (Node node)     => Operator.existOp(node.value) ? new Operator(node.value, node.line, node.column) : new Atom(node.value, node.line, node.column)
    );

    static TokenGen NumberGen = TokenGen(
        (char head)     => head.isDigit,
        (string lexeme) {
            static auto re = regex(r"0|[1-9][0-9]*");
            auto res = lexeme.matchFirst(re);
            return !res.empty && res.front==lexeme;
        },
        (Node node)     => new Number(node.value, node.line, node.column)
    );

    static TokenGen VariableGen = TokenGen(
        (char head)     => head.isUpper || head=='_',
        (string lexeme) {
            static auto re = regex(r"[_A-Z][_0-9a-zA-Z]*");
            auto res = lexeme.matchFirst(re);
            return !res.empty && res.front==lexeme;
        },
        (Node node)     => new Variable(node.value, node.line, node.column)
    );

    static TokenGen LParenGen = TokenGen(
        (char head)     => head=='(',
        (string lexeme) => lexeme=="(",
        (Node node)     => new LParen(node.value, node.line, node.column)
    );

    static TokenGen RParenGen = TokenGen(
        (char head)     => head==')',
        (string lexeme) => lexeme==")",
        (Node node)     => new RParen(node.value, node.line, node.column)
    );

    static TokenGen PeriodGen = TokenGen(
        (char head)     => head=='.',
        (string lexeme) => lexeme==".",
        (Node node)     => new Period(node.value, node.line, node.column)
    );

    static TokenGen EmptyGen = TokenGen(
        (char head)     => head.isWhite,
        (string lexeme) => lexeme.length==1 && lexeme.front.to!char.isWhite,
        (Node node)     => null
    );

    static TokenGen ErrorGen = TokenGen(
        (char head)     => false,
        (string lexeme) => false,
        (Node node)     => null
    );

    struct Node {
        string value;
        int line;
        int column;

        Node opBinary(string op)(Node that) if (op == "~") {
            return Node(
                this.value~that.value,
                min(this.line, that.line),
                this.line<that.line ? this.column                   :
                this.line>that.line ? that.column                   :
                                      min(this.column, that.column)
            );
        }

        string toString() {
            return "Node(value: \"" ~value~ "\", line: " ~line.to!string~ ", column: " ~column.to!string~ ")";
        }

    }




    /* ---------- Unit Tests ---------- */

    // test Node
    unittest {
        writeln(__FILE__, ": test Node");

        Node n1 = Node("abc", 1, 10);
        Node n2 = Node("de", 2, 5);
        Node n3 = Node("fg", 2, 1);
        assert(n1~n2 == Node("abcde", 1, 10));
        assert(n2~n3 == Node("defg", 2, 1));
    }

    // test TokenGen
    unittest {
        writeln(__FILE__, ": test TokenGen");

        // AtomGen
        assert(AtomGen.varidateHead('a'));
        assert(AtomGen.varidateHead('\''));
        assert(AtomGen.varidateHead(','));
        assert(!AtomGen.varidateHead('A'));
        assert(AtomGen.varidate("abc"));
        assert(AtomGen.varidate("' po _'"));
        assert(AtomGen.varidate("|+|"));
        assert(!AtomGen.varidate("' po _"));
        // NumberGen
        assert(NumberGen.varidateHead('0'));
        assert(!NumberGen.varidateHead('_'));
        assert(NumberGen.varidate("123"));
        assert(NumberGen.varidate("0"));
        assert(!NumberGen.varidate("0123"));
        // VariableGen
        assert(VariableGen.varidateHead('A'));
        assert(VariableGen.varidateHead('_'));
        assert(!VariableGen.varidateHead('a'));
        assert(VariableGen.varidate("Po"));
        assert(VariableGen.varidate("_yeah"));
        // LParenGen
        assert(LParenGen.varidateHead('('));
        assert(LParenGen.varidate("("));
        // RParenGen
        assert(RParenGen.varidateHead(')'));
        assert(RParenGen.varidate(")"));
        // PeriodGen
        assert(PeriodGen.varidateHead('.'));
        assert(PeriodGen.varidate("."));
        // EmptyGen
        assert(EmptyGen.varidateHead(' '));
        assert(EmptyGen.varidate(" "));
    }

    // test lookaheader
    unittest {
        writeln(__FILE__, ": test Lookaheader");

        auto lexer = new Lexer;
        auto lookaheader = lexer.getLookaheader("a\nbc\nd");

        assert(!lookaheader.empty);
        assert(lookaheader.front == Node("a", 1, 1));
        lookaheader.popFront;
        assert(lookaheader.front == Node("b", 2, 1));
        lookaheader.popFront;
        assert(lookaheader.front == Node("c", 2, 2));
        lookaheader.popFront;
        assert(lookaheader.front == Node("d", 3, 1));
        lookaheader.popFront;
        assert(lookaheader.empty);
    }

    // test getTokenGen
    unittest {
        writeln(__FILE__, ": test getTokenGen");

        auto lexer = new Lexer;
        auto lookaheader = lexer.getLookaheader("hoge(10, X).");
        assert(lexer.getTokenGen(lookaheader) == AtomGen);
        lookaheader.drop(4);
        assert(lexer.getTokenGen(lookaheader) == LParenGen);
        lookaheader.drop(1);
        assert(lexer.getTokenGen(lookaheader) == NumberGen);
        lookaheader.drop(2);
        assert(lexer.getTokenGen(lookaheader) == AtomGen);
        lookaheader.drop(1);
        assert(lexer.getTokenGen(lookaheader) == EmptyGen);
        lookaheader.drop(1);
        assert(lexer.getTokenGen(lookaheader) == VariableGen);
        lookaheader.drop(1);
        assert(lexer.getTokenGen(lookaheader) == RParenGen);
        lookaheader.drop(1);
        assert(lexer.getTokenGen(lookaheader) == PeriodGen);
        lookaheader.drop(1);
        assert(lookaheader.empty);

        assert(!lexer._hasError);
        assert(lexer._errorMessage.empty);
    }

    // test getTokenNode
    unittest {
        writeln(__FILE__, ": test getTokenNode");

        auto lexer = new Lexer;
        auto lookaheader = lexer.getLookaheader("hoge(10, X).");
        assert(lexer.getTokenNode(lookaheader, AtomGen)     == Node("hoge", 1, 1));
        assert(lexer.getTokenNode(lookaheader, LParenGen)   == Node("(", 1, 5));
        assert(lexer.getTokenNode(lookaheader, NumberGen)   == Node("10", 1, 6));
        assert(lexer.getTokenNode(lookaheader, AtomGen)     == Node(",", 1, 8));
        assert(lexer.getTokenNode(lookaheader, EmptyGen)    == Node(" ", 1, 9));
        assert(lexer.getTokenNode(lookaheader, VariableGen) == Node("X", 1, 10));
        assert(lexer.getTokenNode(lookaheader, RParenGen)   == Node(")", 1, 11));
        assert(lexer.getTokenNode(lookaheader, PeriodGen)   == Node(".", 1, 12));
        assert(lookaheader.empty);

        assert(!lexer._hasError);
        assert(lexer._errorMessage.empty);
    }

    // test getToken
    unittest {
        writeln(__FILE__, ": test getToken");

        auto lexer = new Lexer;
        auto lookaheader = lexer.getLookaheader("hoge(10, X).");
        assert(cast(Atom) lexer.getToken(lookaheader, AtomGen));
        assert(cast(LParen) lexer.getToken(lookaheader, LParenGen));
        assert(cast(Number) lexer.getToken(lookaheader, NumberGen));
        assert(cast(Operator) lexer.getToken(lookaheader, AtomGen));
        assert(lexer.getToken(lookaheader, EmptyGen) is null);
        assert(cast(Variable) lexer.getToken(lookaheader, VariableGen));
        assert(cast(RParen) lexer.getToken(lookaheader, RParenGen));
        assert(cast(Period) lexer.getToken(lookaheader, PeriodGen));
        assert(lookaheader.empty);

        assert(!lexer._hasError);
        assert(lexer._errorMessage.empty);
    }

    // test tokenize
    unittest {
        writeln(__FILE__, ": test tokenize");

        auto lexer = new Lexer;
        lexer.run("hoge(10, X).");
        assert(!lexer.hasError);
        Token[] tokens = lexer.get();
        assert(tokens.length == 7);
        assert(cast(Atom)     tokens[0]);
        assert(cast(LParen)   tokens[1]);
        assert(cast(Number)   tokens[2]);
        assert(cast(Operator) tokens[3]);
        assert(cast(Variable) tokens[4]);
        assert(cast(RParen)   tokens[5]);
        assert(cast(Period)   tokens[6]);
    }

    // test errorMessage
    unittest {
        writeln(__FILE__, ": test errorMessage");

        auto lexer = new Lexer;
        assert(!lexer.hasError);
        lexer.run("po][po");
        assert(lexer.hasError);
        lexer.clear;
        assert(!lexer.hasError);
    }
}