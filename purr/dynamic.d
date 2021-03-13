module purr.dynamic;

import std.algorithm;
import std.conv;
import std.array;
import std.traits;
import purr.io;
import core.memory;
import purr.bytecode;
import purr.vm;
import purr.error;
import purr.data.map;

// version(unsafe)
// {

// }
// else
// {
version = safe;
// }
pragma(inline, true):

alias Args = Dynamic[];
alias Array = Dynamic[];

alias Delegate = Dynamic function(Args);
// alias Mapping = Map!(Dynamic, Dynamic);
alias Mapping = Dynamic[Dynamic];
Mapping emptyMapping()
{
    // return new Mapping;
    return (Dynamic[Dynamic]).init;
}

private size_t symc = 0;
Dynamic gensym()
{
    return dynamic(symc++);
}

Table[] beforeTables;

void*[] lookingFor;
class Table
{
    Mapping table = emptyMapping;
    Table metatable;
    alias table this;

    Table init()
    {
        return Table.empty;
    }

    static Table empty()
    {
        return new Table;
    }

    this()
    {
        table = emptyMapping;
    }

    this(typeof(table) t)
    {
        // assert(t !is null);
        table = t;
        metatable = null;
    }

    this(typeof(table) t, Table m)
    {
        // assert(t !is null);
        table = t;
        metatable = m;
    }

    Table withGet(Table newget)
    {
        if (Dynamic* get = "get".dynamic in table)
        {
            *get.arrPtr ~= newget.dynamic;
        }
        else
        {
            table["get".dynamic] = [newget.dynamic].dynamic;
        }
        return this;
    }

    Table withGet(Args...)(Args args) if (args.length != 1)
    {
        if (args.length == 0)
        {
            return this;
        }
        return withGet(args[0]).withGet(args[1 .. $]);
    }

    Table withProto(Table proto)
    {
        withGet(proto);
        meta.withGet(proto.meta);
        return this;
    }

    Table withProto(Args...)(Args args) if (args.length != 1)
    {
        if (args.length == 0)
        {
            return this;
        }
        return withProto(args[0]).withProto(args[1 .. $]);
    }

    ref Table meta()
    {
        if (metatable is null)
        {
            metatable = Table.empty;
        }
        return metatable;
    }

    Dynamic rawIndex(Dynamic key)
    {
        if (Dynamic* d = key in table)
        {
            return *d;
        }
        throw new BoundsException("key not found: " ~ key.to!string);
    }

    void rawSet(Dynamic key, Dynamic value)
    {
        table[key] = value;
    }

    void set(Dynamic key, Dynamic value)
    {
        Dynamic* metaset = dynamic("set") in meta;
        if (metaset !is null)
        {
            (*metaset)([dynamic(this), key, value]);
        }
        rawSet(key, value);
    }

    ref Dynamic opIndex(Dynamic key)
    {
        if (Dynamic* val = key in this)
        {
            return *val;
        }
        throw new BoundsException("key not found: " ~ key.to!string);
    }

    Dynamic* opBinaryRight(string op)(Dynamic other) if (op == "in")
    {
        foreach (i; lookingFor)
        {
            if (i is cast(void*) this)
            {
                return null;
            }
        }
        lookingFor ~= cast(void*) this;
        scope (exit)
        {
            lookingFor.length--;
        }
        Dynamic* ret = other in table;
        if (ret)
        {
            return ret;
        }
        if (meta.length == 0)
        {
            return null;
        }
        Dynamic* metaget = "get".dynamic in meta;
        if (metaget !is null && metaget.type == Dynamic.Type.arr)
        {
            foreach (getter; metaget.arr)
            {
                if (Dynamic* got = other in getter.tab)
                {
                    return got;
                }
            }
            return null;
        }
        else if (metaget !is null && metaget.type == Dynamic.Type.tab)
        {
            return other in (*metaget).tab;
        }
        else if (metaget !is null)
        {
            return new Dynamic((*metaget)([this.dynamic, other]));
        }
        return null;
    }

    Dynamic opBinary(string op)(Dynamic other)
    {
        enum string opname(string op)()
        {
            switch (op)
            {
            default : assert(0);
            case "~" : return "cat";
            case "+" : return "add";
            case "-" : return "sub";
            case "*" : return "mul";
            case "/" : return "div";
            case "%" : return "mod";
            }
        }
        return meta[dynamic(opname!op)]([dynamic(this), other]);
    }

    Dynamic opCall(Args args)
    {
        if (Dynamic* dyn = "self".dynamic in meta)
        {
            return meta[dynamic("call")](dyn.arr ~ args);
        }
        return meta[dynamic("call")](args);
    }

    Dynamic opUnary(string op)()
    {
        enum string opname(string op)()
        {
            switch (op)
            {
            default : assert(0);
            case "-" : return "neg";
            }
        }
        return meta[dynamic(opname!op)]([this]);
    }

    override string toString()
    {
        foreach (i, v; beforeTables)
        {
            if (v is this)
            {
                return "&" ~ i.to!string;
            }
        }
        beforeTables ~= this;
        scope (exit)
        {
            beforeTables.length--;
        }
        Dynamic* str = "str".dynamic in meta;
        if (str !is null)
        {
            Dynamic res = *str;
            if (res.type != Dynamic.Type.str)
            {
                res = res([dynamic(this)]);
            }
            if (res.type != Dynamic.Type.str)
            {
                throw new TypeException("str must return a string");
            }
            return res.str;
        }
        return rawToString;
    }

    string rawToString()
    {
        char[] ret;
        ret ~= "{";
        size_t i = 0;
        foreach (key, value; table)
        {
            if (i != 0)
            {
                ret ~= ", ";
            }
            ret ~= key.to!string;
            ret ~= ": ";
            ret ~= value.to!string;
            i++;
        }
        ret ~= "}";
        return cast(string) ret;
    }
}

Dynamic dynamic(T...)(T a)
{
    return Dynamic(a);
}

struct Fun
{
    Dynamic function(Args) value;
    // alias value this;
    string mangled;
    Dynamic[] names;
    Dynamic[] args;
    string toString()
    {
        return callableFormat(names, args);
    }
}

struct Dynamic
{
    enum Type : int
    {
        nil,
        log,
        sml,
        str,
        arr,
        tab,
        fun,
        pro,
    }

    union Value
    {
        bool log;
        double sml;
        string* str;
        Array* arr;
        Table tab;
        union Callable
        {
            Fun* fun;
            Function pro;
        }

        Callable fun;
    }

pragma(inline, true):
align(8): // do not change alignment!
    Type type = void;
    Value value = void;

    static Dynamic strToNum(string s)
    {
        return dynamic(s.to!double);
    }

    this(Type t)
    {
        type = t;
    }

    this(bool log)
    {
        value.log = log;
        type = Type.log;
    }

    this(double num)
    {
        value.sml = num;
        type = Type.sml;
    }

    this(string str)
    {
        value.str = cast(string*) GC.malloc(string.sizeof);
        *value.str = str;
        type = Type.str;
    }

    this(Array arr)
    {
        value.arr = cast(Array*) GC.malloc(Array.sizeof);
        *value.arr = arr;
        type = Type.arr;
    }

    this(Mapping tab)
    {
        value.tab = new Table(tab);
        type = Type.tab;
    }

    this(Table tab)
    {
        value.tab = tab;
        type = Type.tab;
    }

    // this(Dynamic function(Args) fun)
    // {
    //     value.fun.fun = new Fun(fun);
    //     type = Type.fun;
    // }

    this(Fun fun)
    {
        value.fun.fun = [fun].ptr;
        type = Type.fun;
    }

    // this(Dynamic delegate(Args) del)
    // {
    //     value.fun.del = new Del(del);
    //     type = Type.del;
    // }

    this(Function pro)
    {
        value.fun.pro = pro;
        type = Type.pro;
    }

    this(Dynamic other)
    {
        value = other.value;
        type = other.type;
    }

    static Dynamic nil()
    {
        Dynamic ret = dynamic(false);
        ret.value = Dynamic.Value.init;
        ret.type = Dynamic.Type.nil;
        return ret;
    }

    string toString()
    {
        return this.strFormat;
    }

    Dynamic opCall(Args args)
    {
        switch (type)
        {
        case Dynamic.Type.fun:
            return fun.fun.value(args);
            // case Dynamic.Type.del:
            //     return fun.del.value(args);
        case Dynamic.Type.pro:
            if (fun.pro.self.length == 0)
            {
                return run(fun.pro, args);
            }
            else
            {
                return run(fun.pro, fun.pro.self ~ args);
            }
        case Dynamic.Type.tab:
            return value.tab(args);
        default:
            throw new TypeException("error: not a function: " ~ this.to!string);
        }
    }

    int opCmp(Dynamic other)
    {
        return cmpDynamic(this, other);
    }

    int flatOpCmp(Dynamic other)
    {
        Type t = type;
        switch (t)
        {
        default:
            // assert(0);
            throw new TypeException(
                    "error: not comparable: " ~ this.to!string ~ " " ~ other.to!string);
        case Type.nil:
            return 0;
        case Type.log:
            return value.log - other.log;
        case Type.sml:
            double a = as!double;
            double b = other.value.sml;
            if (a < b)
            {
                return -1;
            }
            if (a == b)
            {
                return 0;
            }
            return 1;
        case Type.str:
            return cmp(*value.str, other.str);
        }
    }

    size_t toHash() const nothrow
    {
        final switch (type)
        {
        case Dynamic.Type.nil:
            return 0;
        case Dynamic.Type.log:
            if (value.log) {
                return 1;
            }
            else {
                return 2;
            }
        case Dynamic.Type.sml:
            if (value.sml > 0) {
                return 3 + cast(size_t) value.sml;
            }
            else {
                return 3 + cast(size_t) -value.sml;
            }
        case Dynamic.Type.str:
            return (*value.str).hashOf;
        case Dynamic.Type.arr:
            return value.arr.length + 2 << 52;
        case Dynamic.Type.tab:
            return value.tab.table.length + 2 << 53;
        case Dynamic.Type.fun:
            return size_t.max - 3;
        case Dynamic.Type.pro:
            return size_t.max - 2;
        }
        return cast(size_t) type;
    }

    bool opEquals(const Dynamic other) const
    {
        return cmpDynamic(this, other) == 0;
    }

    Dynamic opBinary(string op)(Dynamic other)
    {
        static if (op == "~")
        {
            if (type == Type.str && other.type == Type.str)
            {
                return dynamic(str ~ other.str);
            }
            if (type == Type.arr && other.type == Type.arr)
            {
                return dynamic(arr ~ other.arr);
            }
        }
        else
        {
            if (type == Type.sml && other.type == Type.sml)
            {
                return dynamic(mixin("value.sml " ~ op ~ " other.value.sml"));
            }
            if (type == Type.tab)
            {
                return mixin("tab " ~ op ~ " other");
            }
        }
        throw new TypeException("invalid types: " ~ type.to!string ~ op ~ other.type.to!string);
    }

    Dynamic opUnary(string op)()
    {
        return dynamic(mixin(op ~ "as!double"));
    }

    bool log()
    {
        version (safe)
        {
            if (type != Type.log)
            {
                throw new TypeException("expected logical type");
            }
        }
        return value.log;
    }

    string str()
    {
        version (safe)
        {
            if (type != Type.str)
            {
                throw new TypeException("expected string type");
            }
        }
        return *value.str;
    }

    Array arr()
    {
        version (safe)
        {
            if (type != Type.arr)
            {
                throw new TypeException("expected array type");
            }
        }
        return *value.arr;
    }

    Table tab()
    {
        version (safe)
        {
            if (type != Type.tab)
            {
                throw new TypeException("expected table type");
            }
        }
        return value.tab;
    }

    string* strPtr()
    {
        version (safe)
        {
            if (type != Type.str)
            {
                throw new TypeException("expected string type");
            }
        }
        return value.str;
    }

    Array* arrPtr()
    {
        version (safe)
        {
            if (type != Type.arr)
            {
                throw new TypeException("expected array type");
            }
        }
        return value.arr;
    }

    Value.Callable fun()
    {
        version (safe)
        {
            // if (type != Type.fun && type != Type.pro && type != Type.del)
            if (type != Type.fun && type != Type.pro)
            {
                throw new TypeException("expected callable type not " ~ type.to!string);
            }
        }
        return value.fun;
    }

    T as(T)() if (isIntegral!T)
    {
        if (type == Type.sml)
        {
            return cast(T) value.sml;
        }
        else
        {
            throw new TypeException("expected numeric type");
        }
    }

    T as(T)() if (isFloatingPoint!T)
    {
        if (type == Type.sml)
        {
            return cast(T) value.sml;
        }
        else
        {
            throw new TypeException("expected numeric type");
        }
    }

    bool isTruthy()
    {
        return type != Type.nil && (type != Type.log || value.log);
    }
}

private int cmp(T)(T a, T b) if (!is(T == Function) && !is(T == Dynamic))
{
    if (a == b)
    {
        return 0;
    }
    if (a < b)
    {
        return -1;
    }
    return 1;
}

private int cmpFunction(const Function a, const Function b)
{
    return cmp(cast(void*) a, cast(void*) b);
}

alias cmpDynamic = cmpDynamicImpl;

// private int cmpDynamic(T...)(T a)
// {
//     int res = cmpDynamicImpl(a);
//     return res;
// }

Table[2][] tableAbove;
int cmpTable(Table at, Table bt)
{
    foreach (i, p; tableAbove)
    {
        if (at is p[0] && bt is p[1])
        {
            return 0;
        }
    }
    tableAbove ~= [at, bt];
    scope (exit)
    {
        tableAbove.length--;
    }
    if (Dynamic* mcmp = "cmp".dynamic in at.meta)
    {
        return cast(int)(*mcmp)([at.dynamic, bt.dynamic]).value.sml;
    }
    if (int c = cmp(at.table.length, bt.table.length))
    {
        return c;
    }
    foreach (key, value; at)
    {
        const Dynamic* bValue = key in bt;
        if (bValue is null)
        {
            foreach (key2, value2; bt)
            {
                if (key2 !in at)
                {
                    return cmpDynamic(key, key2);
                }
            }
            assert(0);
        }
        if (int res = cmpDynamic(value, *bValue))
        {
            return res;
        }
    }
    if (at.meta.length == 0 && at.meta.length == 0)
    {
        return 0;
    }
    return cmpTable(at.meta, bt.meta);
}

Dynamic[2][] above;
private int cmpDynamicImpl(Dynamic a, Dynamic b)
{
    if (b.type != a.type)
    {
        return cmp(a.type, b.type);
    }
    final switch (a.type)
    {
    case Dynamic.Type.nil:
        return 0;
    case Dynamic.Type.log:
        return cmp(a.value.log, b.value.log);
    case Dynamic.Type.str:
        return cmp(*a.value.str, *b.value.str);
    case Dynamic.Type.sml:
        return cmp(a.value.sml, b.value.sml);
    case Dynamic.Type.arr:
        Dynamic[2] cur = [a, b];
        foreach (i, p; above)
        {
            if (cur[0] is p[0] && cur[1] is p[1])
            {
                return 0;
            }
        }
        above ~= cur;
        scope (exit)
        {
            above.length--;
        }
        const Dynamic[] as = *a.value.arr;
        const Dynamic[] bs = *b.value.arr;
        if (int c = cmp(as.length, bs.length))
        {
            return c;
        }
        foreach (i; 0 .. as.length)
        {
            if (int res = cmpDynamic(as[i], bs[i]))
            {
                return res;
            }
        }
        return 0;
    case Dynamic.Type.tab:
        Dynamic[2] cur = [a, b];
        foreach (i, p; above)
        {
            if (cur[0] is p[0] && cur[1] is p[1])
            {
                return 0;
            }
        }
        above ~= cur;
        scope (exit)
        {
            above.length--;
        }
        return cmpTable(a.value.tab, b.value.tab);
    case Dynamic.Type.fun:
        return cmp(a.value.fun.fun, b.value.fun.fun);
        // case Dynamic.Type.del:
        //     return cmp(a.value.fun.del, b.value.fun.del);
    case Dynamic.Type.pro:
        return cmpFunction(a.value.fun.pro, b.value.fun.pro);
    }
}

string callableFormat(Dynamic[] names, Dynamic[] args)
{
    string argsRepr;
    if (args.length != 0)
    {
        argsRepr = "(" ~ args.map!(x => x.str).joiner(",").array.to!string ~ ") ";
    }
    string namesRepr;
    if (names.length >= 1)
    {
        namesRepr = names[0].str;
    }
    return "fun " ~ namesRepr ~ argsRepr ~ "{...}";
}

Dynamic[] before = null;
private string strFormat(Dynamic dyn)
{
    foreach (i, v; before)
    {
        if (dyn is v)
        {
            return "&" ~ i.to!string;
        }
    }
    before ~= dyn;
    scope (exit)
    {
        before.length--;
    }
    switch (dyn.type)
    {
    default:
        return "<?" ~ dyn.type.to!string ~ ">";
    case Dynamic.Type.nil:
        return "nil";
    case Dynamic.Type.log:
        return dyn.log.to!string;
    case Dynamic.Type.sml:
        if (dyn.value.sml % 1 == 0 && dyn.value.sml > long.min && dyn.value.sml < long.max)
        {
            return to!string(cast(long) dyn.value.sml);
        }
        return dyn.value.sml.to!string;
    case Dynamic.Type.str:
        if (before.length == 0)
        {
            return dyn.str;
        }
        else
        {
            return '"' ~ dyn.str ~ '"';
        }
    case Dynamic.Type.arr:
        char[] ret;
        ret ~= "[";
        foreach (i, v; dyn.arr)
        {
            if (i != 0)
            {
                ret ~= ", ";
            }
            ret ~= v.to!string;
        }
        ret ~= "]";
        return cast(string) ret;
    case Dynamic.Type.tab:
        return dyn.tab.to!string;
    case Dynamic.Type.fun:
        return (*dyn.value.fun.fun).to!string;
        // case Dynamic.Type.del:
        //     return (*dyn.value.fun.del).to!string;
    case Dynamic.Type.pro:
        return dyn.fun.pro.to!string;
    }
}
