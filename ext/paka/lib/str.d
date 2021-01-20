module paka.lib.str;

import purr.base;
import purr.dynamic;
import std.array;
import std.string;
import std.algorithm.iteration;
import std.algorithm;
import std.stdio;
import std.conv;
import std.uni;

Pair[] libstr()
{
    Pair[] ret = [
        Pair("len", &liblen), Pair("split", &libsplit), Pair("join",
                &libjoin), Pair("chars", &libchars),
        Pair("to_upper", dynamic(&libtoupper)), Pair("to_lower",
                &libtolower), Pair("to_number", &libtonumber),
        Pair("slice", &libslice), Pair("strip", dynamic(&libstrip)),
        Pair("char", &libchar), Pair("ascii", &libascii), Pair("from", &libfrom),
    ];
    return ret;
}

/// calls tostring of object
Dynamic libfrom(Args args)
{
    return dynamic(args[0].to!string);
}

/// gets length of string
Dynamic liblen(Args args)
{
    return dynamic(args[0].str.length);
}

/// reutrns ascii value of first char of string
Dynamic libascii(Args args)
{
    return dynamic(cast(double) args[0].str[0]);
}

/// reutrns first char of string
Dynamic libchar(Args args)
{
    return dynamic(cast(string)[cast(char) args[0].as!size_t]);
}

/// reutrns string split at deliminer
Dynamic libsplit(Args args)
{
    Dynamic[] ret = args[0 .. 1];
    foreach (at; args[1 .. $])
    {
        Dynamic[] tmp = [];
        foreach (str; ret)
        {
            tmp ~= str.str.splitter(at.str).map!dynamic.array;
        }
        ret = tmp;
    }
    return dynamic(ret);
    // return dynamic(args[0].str.splitter(args[1].str).map!(x => dynamic(x)).array);
}

/// joins string to deliminer
Dynamic libjoin(Args args)
{
    string ret;
    foreach (key, value; args[1].arr)
    {
        if (key != 0)
        {
            ret ~= args[0].str;
        }
        ret ~= value.str;
    }
    return ret.dynamic;
}

/// reutrns string split at everey char
Dynamic libchars(Args args)
{
    return dynamic(args[0].str.map!(x => dynamic(x.to!string)).array);
}

/// return uppercase ascii string
Dynamic libtoupper(Args args)
{
    return dynamic(args[0].str.toUpper);
}

/// return lowercase ascii string
Dynamic libtolower(Args args)
{
    return dynamic(args[0].str.toLower);
}

/// return string converted to string
Dynamic libtonumber(Args args)
{
    return Dynamic.strToNum(args[0].str);
}

/// return string without whitespace on either end
Dynamic libstrip(Args args)
{
    return dynamic(args[0].str.strip);
}

/// return sliced string similar to arr.slice
Dynamic libslice(Args args)
{
    if (args.length == 2)
    {
        return dynamic(args[0].str[args[1].as!size_t .. $]);
    }
    else
    {
        return dynamic(args[0].str[args[1].as!size_t .. args[2].as!size_t]);
    }
}
