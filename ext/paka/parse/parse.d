module paka.parse.parse;

import purr.io;
import std.conv;
import std.file;
import std.array;
import std.utf;
import std.functional;
import std.ascii;
import std.string;
import std.algorithm;
import purr.vm;
import purr.inter;
import purr.base;
import purr.dynamic;
import purr.srcloc;
import purr.inter;
import purr.fs.disk;
import purr.fs.har;
import purr.fs.memory;
import purr.fs.files;
import purr.bytecode;
import purr.ir.walk;
import purr.ast.ast;
import paka.tokens;
import paka.macros;
import paka.parse.util;
import paka.parse.op;

/// reads open parens
Node[][] readOpen(string v)(ref TokenArray tokens) if (v == "()")
{
    Node[][] ret;
    Node[] args;
    tokens.match(Token.Type.open, [v[0]]);
    while (!tokens[0].isClose([v[1]]))
    {
        if (tokens[0].isSemicolon)
        {
            tokens.nextIs(Token.Type.semicolon);
            ret ~= args;
            args = null;
        }
        else
        {
            args ~= tokens.readExprBase;
            if (tokens[0].isComma)
            {
                tokens.nextIs(Token.Type.comma);
            }
        }
    }
    tokens.match(Token.Type.close, [v[1]]);
    ret ~= args;
    return ret;
}

Node[] readOpen1(string v)(ref TokenArray tokens) if (v == "()")
{
    Node[][] ret = tokens.readOpen!"()";
    if (ret.length > 1)
    {
        throw new Exception("unexpected semicolon in (...)");
    }
    return ret[0];
}

/// reads square brackets
Node[] readOpen(string v)(ref TokenArray tokens) if (v == "[]")
{
    Node[] args;
    tokens.match(Token.Type.open, [v[0]]);
    while (!tokens[0].isClose([v[1]]))
    {
        args ~= tokens.readExprBase;
        if (tokens[0].isComma)
        {
            tokens.nextIs(Token.Type.comma);
        }
    }
    tokens.match(Token.Type.close, [v[1]]);
    return args;
}

/// reads open curly brackets
Node[] readOpen(string v)(ref TokenArray tokens) if (v == "{}")
{
    Node[] args;
    tokens.match(Token.Type.open, [v[0]]);
    size_t items = 0;
    while (!tokens[0].isClose([v[1]]))
    {
        args ~= tokens.readExprBase;
        items++;
        if (tokens[0].isComma)
        {
            tokens.nextIs(Token.Type.comma);
        }
        else if (tokens[0].isOperator(":"))
        {
            tokens.nextIs(Token.Type.operator, ":");
        }
    }
    tokens.match(Token.Type.close, [v[1]]);
    return args;
}

// /// strips newlines and changes the input
void stripNewlines(ref TokenArray tokens)
{
    while (tokens[0].isSemicolon)
    {
        tokens.nextIs(Token.Type.semicolon);
    }
}

alias readPostCallExtend = Spanning!(readPostExtendImpl, Node);
Node readPostCallExtendImpl(ref TokenArray tokens, Node last)
{
    Node[][] args = tokens.readOpen!"()";
    while (tokens.length != 0 && tokens[0].isOpen("{"))
    {
        args[$ - 1] ~= cast(Node) new Call(new Ident("@fun"), [
                new Call([]), tokens.readBlock
                ]);
    }
    foreach (argList; args)
    {
        last = new Call(last, argList);
    }
    return last;
}

/// after reading a small expression, read a postfix expression
alias readPostExtend = Spanning!(readPostExtendImpl, Node);
Node readPostExtendImpl(ref TokenArray tokens, Node last)
{
    if (tokens.length == 0)
    {
        return last;
    }
    Node ret = void;
    if (tokens[0].isOpen("("))
    {
        ret = tokens.readPostCallExtendImpl(last);
    }
    else if (tokens[0].isOpen("{"))
    {
        Node[] args;
        while (tokens.length != 0 && tokens[0].isOpen("{"))
        {
            args ~= cast(Node) new Call(new Ident("@fun"), [
                    new Call([]), tokens.readBlock
                    ]);
        }
        ret = new Call(last, args);
    }
    else if (tokens.length > 2 && tokens[0].isOperator(".")
            && (tokens[1].isOpen("(") || tokens[1].isOpen("[")))
    {
        tokens.nextIs(Token.Type.operator, ".");
        if (tokens[0].isOpen("["))
        {
            Node[] arr = tokens.readOpen!"[]";
            ret = new Call(new Ident("@index"), [
                    last, new Call(new Ident("@do"), arr)
                    ]);
        }
        else
        {
            Node[][] arr = tokens.readOpen!"()";
            Node dov = new Call(new Ident("@do"),
                    arr.map!(s => cast(Node) new Call(new Ident("@do"), s)).array);
            ret = new Call(new Ident("@index"), [last, dov]);
        }
    }
    else if (tokens[0].isOperator(".") && !tokens[1].isOperator)
    {
        tokens.nextIs(Token.Type.operator, ".");
        Node ind = void;
        if (tokens[0].value[0].isDigit)
        {
            ind = new Ident(tokens[0].value);
        }
        else
        {
            ind = new Value(tokens[0].value);
        }
        ret = new Call(new Ident("@index"), [last, ind]);
        tokens.nextIsAny;
    }
    else
    {
        return last;
        // throw new Exception("parse error " ~ tokens.to!string);
    }
    return tokens.readPostExtend(ret);
}

/// read an if statement
alias readIf = Spanning!readIfImpl;
Node readIfImpl(ref TokenArray tokens)
{
    Node[] cond = tokens.readOpen1!"()";
    if (tokens.length < 1)
    {
        throw new Exception("if cannot have empty parens");
    }
    Node iftrue = tokens.readBlock;
    Node iffalse;
    if (tokens.length > 0 && tokens[0].isKeyword("else"))
    {
        tokens.nextIs(Token.Type.keyword, "else");
        iffalse = tokens.readBlock;
    }
    else
    {
        iffalse = new Ident("@nil");
    }
    return new Call(new Ident("@if"), [cond[0], iftrue, iffalse]);
}

void skip1(ref string str, ref Span span)
{
    if (str[0] == '\n')
    {
        span.first.line += 1;
        span.first.column = 1;
    }
    else
    {
        span.first.column += 1;
    }
    str = str[1 .. $];
}

bool isDigitInBase(char c, long base)
{
    if (base > 0 && base < 10)
    {
        return c - '0' < base;
    }
    if (base == 10)
    {
        return c.isDigit;
    }
    if (base > 10)
    {
        long val = c;
        if (val >= 'A' && val <= 'A')
        {
            val = val - 'A' + 'a';
        }
        bool isLetterDigit = val >= 10 && val < base;
        return isLetterDigit || c.isDigitInBase(10);
    }
    throw new Exception("base not valud: " ~ base.to!string);
}

long parseNumberOnly(ref string input, size_t base)
{
    string str;
    while (input.length != 0 && input[0].isDigitInBase(base))
    {
        str ~= input[0];
        input = input[1 .. $];
    }
    if (str.length == 0)
    {
        throw new Exception("found no digits when parse escape in base " ~ base.to!string);
    }
    return str.to!size_t(cast(uint) base);
}

size_t escapeNumber(ref string input)
{
    if (input[0] == '0')
    {
        char ctrlchr = input[1];
        input = input[2 .. $];
        switch (ctrlchr)
        {
        case 'b':
            return input.parseNumberOnly(2);
        case 'o':
            return input.parseNumberOnly(8);
        case 'n':
            size_t base = input.escapeNumber;
            if (input.length < 1 || input[0] != ':')
            {
                string why = "0n" ~ base.to!string ~ " must be followd by a colon (:)";
                throw new Exception("cannot have escape: " ~ why);
            }
            input = input[1 .. $];
            if (base == 1)
            {
                size_t num;
                while (input.length != 0 && input[0] == '0')
                {
                    num++;
                }
                return num;
            }
            if (base > 36)
            {
                string why = "0n must be followed by a number 1 to 36 inclusive";
                throw new Exception("cannot have escape: " ~ why);
            }
            return input.parseNumberOnly(base);
        case 'x':
            return input.parseNumberOnly(16);
        default:
            string why = "0 must be followed by one of: nbox";
            throw new Exception("cannot have escape: " ~ why);
        }
    }
    else
    {
        return input.parseNumberOnly(10);
    }
}

Node readStringPart(ref string str, ref Span span)
{
    Span spanInput = span;
    char first = str[0];
    if (first == '\\')
    {
        str.skip1(span);
    }
    string ret;
    while (str.length != 0 && str[0] != '\\')
    {
        ret ~= str[0];
        str.skip1(span);
    }
    Node node = void;
    if (first != '\\')
    {
        node = new Value(ret);
    }
    else
    {
        str.skip1(span);
        if ((ret[0] == 'u' && ret[1] == 'f') || (ret[0] == 'f' && ret[1] == 'u'))
        {
            string input = ret[3 .. $ - 1].strip;
            node = Location(spanInput.first.line, spanInput.first.column, "string", input ~ ";")
                .parsePakaAs!readExprBase;
            node = new Call(new Ident("_unicode_ctrl"), [node]);
        }
        else if (ret[0] == 'f')
        {
            string input = ret[2 .. $ - 1].strip;
            node = Location(spanInput.first.line, spanInput.first.column, "string", input ~ ";")
                .parsePakaAs!readExprBase;
        }
        else if (ret[0] == 'u')
        {
            string input = ret[2 .. $ - 1].strip;
            node = new Call(new Ident("_unicode_ctrl"), [new Value(input)]);
        }
        else
        {
            assert(false);
        }
    }
    node.span = spanInput;
    return node;
}

/// reads first element of postfix expression
alias readPostExpr = Spanning!readPostExprImpl;
Node readPostExprImpl(ref TokenArray tokens)
{
    Node last = void;
    if (tokens[0].isKeyword("lambda"))
    {
        tokens.nextIs(Token.Type.keyword, "lambda");
        if (tokens[0].isOpen("("))
        {
            last = new Call(new Ident("@fun"), [
                    new Call(tokens.readOpen1!"()"), tokens.readBlock
                    ]);
        }
        else if (tokens[0].isOpen("{"))
        {
            last = new Call(new Ident("@fun"), [new Call([]), tokens.readBlock]);
        }
    }
    else if (tokens[0].isKeyword("static"))
    {
        tokens.nextIs(Token.Type.keyword, "static");
        Node node = tokens.readBlock;
        Walker walker = new Walker;
        Function func = walker.walkProgram(node, staticCtx[$ - 1]);
        Dynamic ctx = genCtx;
        Dynamic val = run(func, [ctx], staticCtx[$ - 1].exportLocalsToBaseCallback(func));
        Mapping macros = ctx.tab.table;
        foreach (key, value; macros)
        {
            prefixMacros[$ - 1][key] = value;
        }
        return new Value(val);
    }
    else if (tokens[0].isOpen("("))
    {
        last = new Call(new Ident("@do"), tokens.readOpen1!"()");
    }
    else if (tokens[0].isOpen("["))
    {
        last = new Call(new Ident("@array"), tokens.readOpen!"[]");
    }
    else if (tokens[0].isOpen("{"))
    {
        last = new Call(new Ident("@table"), tokens.readOpen!"{}");
    }
    else if (tokens[0].isKeyword("if"))
    {
        tokens.nextIs(Token.Type.keyword, "if");
        last = tokens.readIf;
    }
    else if (tokens[0].isKeyword("while"))
    {
        tokens.nextIs(Token.Type.keyword, "while");
        Node cond = tokens.readOpen1!"()"[$ - 1];
        Node loop = tokens.readBlock;
        last = new Call(new Ident("@while"), [cond, loop]);
    }
    else if (tokens[0].isIdent)
    {
        bool wasMacro = false;
        outter: foreach_reverse (macros; prefixMacros)
        {
            foreach (key, value; macros)
            {
                if (key.str == tokens[0].value)
                {
                    tokens.nextIs(Token.Type.ident);
                    last = readFromMacro(value, tokens);
                    wasMacro = true;
                    break outter;
                }
            }
        }
        if (!wasMacro)
        {
            last = new Ident(tokens[0].value);
            tokens.nextIs(Token.Type.ident);
        }
    }
    else if (tokens[0].isString)
    {
        if (!tokens[0].value.canFind('\\'))
        {
            last = new Value(tokens[0].value);
        }
        else
        {
            Node[] args;
            string value = tokens[0].value;
            Span span = tokens[0].span;
            while (value.length != 0)
            {
                args ~= value.readStringPart(span);
            }
            last = new Call(new Ident("_paka_str_concat"), args);
        }
        tokens.nextIs(Token.Type.string);
    }
    return tokens.readPostExtend(last);
}

/// read prefix before postfix expression.
alias readPreExpr = Spanning!readPreExprImpl;
Node readPreExprImpl(ref TokenArray tokens)
{
    if (tokens[0].isOperator)
    {
        string[] vals;
        while (tokens[0].isOperator)
        {
            vals ~= tokens[0].value;
            tokens.nextIs(Token.Type.operator);
        }
        return parseUnaryOp(vals)(tokens.readPostExpr);
    }
    return tokens.readPostExpr;
}

bool isDotOperator(Token tok)
{
    return tok.isOperator(".") || tok.isOperator("\\");
}

alias readExprBase = Spanning!(readExprBaseImpl);
/// reads any expresssion with precedence of zero
Node readExprBaseImpl(ref TokenArray tokens)
{
    return tokens.readExpr(0);
}

bool isAnyOperator(Token tok, string[] ops)
{
    foreach (op; ops)
    {
        if (tok.isOperator(op))
        {
            return true;
        }
    }
    return false;
}

alias readExpr = Spanning!(readExprImpl, size_t);
/// reads any expresssion
Node readExprImpl(ref TokenArray tokens, size_t level)
{
    if (level == prec.length)
    {
        return tokens.readPreExpr;
    }
    TokenArray opers = TokenArray.init;
    string[][2][] dotcount;
    Node[] subNodes = [tokens.readExpr(level + 1)];
    while (tokens.length != 0 && tokens[0].isAnyOperator([".", "\\"] ~ prec[level]))
    {
        string[] pre;
        string[] post;
        while (tokens.length != 0 && tokens[0].isDotOperator)
        {
            pre ~= tokens[0].value;
            tokens.tokens = tokens.tokens[1 .. $];
        }
        opers ~= tokens[0];
        tokens.nextIsAny;
        while (tokens.length != 0 && tokens[0].isDotOperator)
        {
            post ~= tokens[0].value;
            tokens.tokens = tokens.tokens[1 .. $];
        }
        subNodes ~= tokens.readExpr(level + 1);
        dotcount ~= [pre, post];
    }
    Node ret = subNodes[0];
    Ident last;
    foreach (i, v; opers)
    {
        ret = parseBinaryOp(dotcount[i][0] ~ v.value ~ dotcount[i][1])(ret, subNodes[1]);
    }
    return ret;
}

/// reads any statement ending in a semicolon
alias readStmt = Spanning!readStmtImpl;
Node readStmtImpl(ref TokenArray tokens)
{
    if (tokens.length == 0)
    {
        return null;
    }
    while (tokens.length > 0 && tokens[0].isSemicolon)
    {
        tokens.nextIs(Token.Type.semicolon);
        if (tokens.length == 0)
        {
            return null;
        }
    }
    if (tokens.length == 0)
    {
        return null;
    }
    if (tokens[0].isOpen("("))
    {
        throw new Exception("parse error: cannot have open paren to start a statement");
    }
    if (tokens[0].isKeyword("return"))
    {
        tokens.nextIs(Token.Type.keyword, "return");
        return new Call(new Ident("@return"), [tokens.readExprBase]);
    }
    if (tokens[0].isKeyword("assert"))
    {
        tokens.nextIs(Token.Type.keyword, "assert");
        return new Call(new Ident("@do"),
                [
                    cast(Node) new Call(new Ident("_paka_begin_assert"), null),
                    cast(Node) new Call(new Ident("_paka_assert"),
                        [
                            cast(Node) new Call(new Ident("@inspect"), [
                                tokens.readExprBase
                            ])
                        ])
                ]);
    }
    if (tokens[0].isKeyword("def"))
    {
        tokens.nextIs(Token.Type.keyword, "def");
        Node name = tokens.readExprBase;
        Call call = cast(Call) name;
        if (call is null)
        {
            throw new Exception("parse error: body of def");
        }
        Call dobody = cast(Call) call.args[$ - 1];
        if (dobody is null)
        {
            throw new Exception("parse error: body of def");
        }
        return new Call(new Ident("@set"),
                [cast(Node) new Call(call.args[0 .. $ - 1])] ~ dobody.args[2 .. $]);
    }
    if (tokens[0].isKeyword("use"))
    {
        tokens.nextIs(Token.Type.keyword, "use");
        Token[] mod;
        while (!tokens[0].isOperator(":"))
        {
            mod ~= tokens[0];
            tokens.nextIsAny;
            if (tokens.length == 0)
            {
                throw new Exception(
                        "parse error: need colon in use (consider using import or include)");
            }
        }
        TokenArray pathToks = newTokenArray(mod);
        tokens.nextIs(Token.Type.operator, ":");
        Node[] args = [new Value(pathToks[0].value)];
        pathToks.nextIs(Token.Type.ident);
        while (pathToks.length >= 2 && pathToks[0].isOperator("/"))
        {
            pathToks.nextIs(Token.Type.operator, "/");
            args ~= new Value(pathToks[0].value);
            pathToks.nextIs(Token.Type.ident);
        }
        Node libvar = genSym;
        Node getlib = new Call(new Ident("_paka_import"), args);
        Node setlib = new Call(new Ident("@set"), [libvar, getlib]);
        Node[] each;
        while (true)
        {
            Node value = new Value(tokens[0].value);
            Node var = new Ident(tokens[0].value);
            tokens.nextIs(Token.Type.ident);
            if (tokens.length != 0 && tokens[0].isOperator("->"))
            {
                tokens.nextIs(Token.Type.operator, "->");
                var = new Ident(tokens[0].value);
                tokens.nextIs(Token.Type.ident);
            }
            value = new Call(new Ident("@index"), [libvar, value]);
            each ~= new Call(new Ident("@set"), [var, value]);
            if (tokens.length == 0)
            {
                break;
            }
            tokens.nextIs(Token.Type.comma);
        }
        return new Call(new Ident("@do"), setlib ~ each ~ libvar);
    }
    if (tokens[0].isKeyword("include"))
    {
        tokens.nextIs(Token.Type.keyword, "include");
        Token[] mod;
        while (true)
        {
            mod ~= tokens[0];
            tokens.nextIsAny;
            if (tokens.length == 0)
            {
                break;
            }
            if (tokens[0].isSemicolon)
            {
                tokens.nextIs(Token.Type.semicolon);
                break;
            }
        }
        TokenArray pathToks = newTokenArray(mod);
        string filename = pathToks[0].value;
        pathToks.nextIs(Token.Type.ident);
        while (pathToks.length >= 2 && pathToks[0].isOperator("/"))
        {
            filename ~= "/";
            pathToks.nextIs(Token.Type.operator, "/");
            filename ~= pathToks[0].value;
            pathToks.nextIs(Token.Type.ident);
        }
        if (filename.fsexists)
        {
        }
        else if (fsexists(filename ~ ".paka"))
        {
            filename ~= ".paka";
        }
        else
        {
            throw new Exception("include error: cannot locate: " ~ filename);
        }
        Location data = filename.readFile;
        return data.parsePaka;
    }
    if (tokens[0].isKeyword("import"))
    {
        tokens.nextIs(Token.Type.keyword, "import");
        Token[] mod;
        while (true)
        {
            mod ~= tokens[0];
            tokens.nextIsAny;
            if (tokens.length == 0)
            {
                break;
            }
            if (tokens[0].isSemicolon)
            {
                tokens.nextIs(Token.Type.semicolon);
                break;
            }
        }
        TokenArray pathToks = newTokenArray(mod);
        string filename = pathToks[0].value;
        pathToks.nextIs(Token.Type.ident);
        while (pathToks.length >= 2 && pathToks[0].isOperator("/"))
        {
            filename ~= "/";
            pathToks.nextIs(Token.Type.operator, "/");
            filename ~= pathToks[0].value;
            pathToks.nextIs(Token.Type.ident);
        }
        if (filename.fsexists)
        {
        }
        else if (fsexists(filename ~ ".paka"))
        {
            filename ~= ".paka";
        }
        else
        {
            throw new Exception("import error: cannot locate: " ~ filename);
        }
        Location data = filename.readFile;
        size_t ctx = enterCtx;
        scope (exit)
        {
            exitCtx;
        }
        Dynamic lib = ctx.eval(data);
        rootBases[ctx - 1] ~= Pair(filename, lib);
        foreach (key, value; lib.tab)
        {
            if (key.type == Dynamic.Type.str)
            {
                rootBases[ctx - 1] ~= Pair(key.str, value);
            }
        }
        return new Ident(filename);
    }
    return tokens.readExprBase;
}

/// reads many staments statement, each ending in a semicolon
/// does not read brackets surrounding
alias readBlockBody = Spanning!readBlockBodyImpl;
Node readBlockBodyImpl(ref TokenArray tokens)
{
    Node[] ret;
    while (tokens.length > 0 && !tokens[0].isClose("}"))
    {
        size_t lengthBefore = tokens.length;
        Node stmt = tokens.readStmt;
        if (stmt !is null)
        {
            ret ~= stmt;
        }
        if (tokens.length == lengthBefore)
        {
            break;
        }
    }
    return new Call(new Ident("@do"), ret);
}

/// wraps the readblock and consumes curly braces
alias readBlock = Spanning!readBlockImpl;
Node readBlockImpl(ref TokenArray tokens)
{
    tokens.nextIs(Token.Type.open, "{");
    Node ret = readBlockBody(tokens);
    tokens.nextIs(Token.Type.close, "}");
    return ret;
}

alias parsePakaValue = parsePakaAs!readBlockBodyImpl;
alias parsePaka = memoize!parsePakaValue;
/// parses code as the paka programming language
Node parsePakaAs(alias parser)(Location loc)
{
    TokenArray tokens = newTokenArray(loc.tokenize);
    try
    {
        Node node = parser(tokens);
        return node;
    }
    catch (Exception e)
    {
        string[] lines = loc.src.split("\n");
        size_t[] nums;
        size_t ml = 0;
        foreach (i; locs)
        {
            if (nums.length == 0 || nums[$ - 1] < i.line)
            {
                nums ~= i.line;
                ml = max(ml, i.line.to!string.length);
            }
        }
        string ret;
        foreach (i; nums)
        {
            string s = i.to!string;
            foreach (j; 0 .. ml - s.length)
            {
                ret ~= ' ';
            }
            if (i > 0 && i < lines.length)
            {
                ret ~= i.to!string ~ ": " ~ lines[i - 1].to!string ~ "\n";
            }
        }
        e.msg = ret ~ e.msg;
        throw e;
    }
}

/// parses code as archive of the paka programming language
Node parse(Location loc)
{
    Location[] olocs = locs;
    locs = null;
    staticCtx ~= enterCtx;
    prefixMacros ~= emptyMapping;
    scope (exit)
    {
        locs = olocs;
        staticCtx.length--;
        prefixMacros.length--;
    }
    fileSystem ~= parseHar(loc, fileSystem);
    MemoryTextFile main = "main.paka".readMemFile;
    if (main is null)
    {
        main = "__main__".readMemFile;
    }
    if (main is null)
    {
        throw new Exception("input error: missing __main__");
    }
    Location location = main.location;
    return location.parsePaka;
}