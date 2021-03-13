module paka.lib.arr;

import core.memory;
import std.array;
import std.algorithm;
import std.parallelism;
import std.concurrency;
import std.conv;
import std.conv;
import purr.base;
import purr.dynamic;
import purr.error;
import purr.io;

Pair[] libarr()
{
    Pair[] ret;
    ret ~= FunctionPair!libsplit("split");
    ret ~= FunctionPair!libextend("extend");
    ret ~= FunctionPair!libslice("slice");
    ret ~= FunctionPair!libfilter("filter");
    ret ~= FunctionPair!librange("range");
    ret ~= FunctionPair!libsorted("sorted");
    ret ~= FunctionPair!liblen("len");
    ret ~= FunctionPair!libpush("push");
    ret ~= FunctionPair!libpop("pop");
    ret ~= FunctionPair!libmap("map");
    ret ~= FunctionPair!libzip("zip");
    ret ~= FunctionPair!libeach("each");
    ret ~= FunctionPair!libfrom("from");
    return ret;
} /// returns a list

Dynamic libfrom(Args args) {
    return args[0].tab.meta["arr".dynamic](args);
}

/// with one arg it returns 0..$0
/// with two args it returns $0..$1
/// with three args it counts from $0 to $1 with interval $2
Dynamic librange(Args args) @Arg("min")
{
    if (args.length == 1)
    {
        Dynamic[] ret;
        foreach (i; cast(double) 0 .. args[0].as!double)
        {
            ret ~= dynamic(i);
        }
        return dynamic(ret);
    }
    if (args.length == 2)
    {
        Dynamic[] ret;
        foreach (i; args[0].as!double .. args[1].as!double)
        {
            ret ~= dynamic(i);
        }
        return dynamic(ret);
    }
    if (args.length == 3)
    {
        double start = args[0].as!double;
        double stop = args[1].as!double;
        double step = args[2].as!double;
        Dynamic[] ret;
        while (start < stop)
        {
            ret ~= dynamic(start);
            start += step;
        }
        return dynamic(ret);
    }
    throw new TypeException("bad number of arguments to range");
}

/// returns an array where the function has been called on each element
Dynamic libmap(Args args)
{
    Array res = (cast(Dynamic*) GC.malloc(args[0].arr.length * Dynamic.sizeof, 0, typeid(Dynamic)))[0..args[0].arr.length];
    foreach (k, i; args[0].arr)
    {
        Dynamic cur = i;
        foreach (f; args[1 .. $])
        {
            cur = f([cur, k.dynamic]);
        }
        res[k] = cur;
    }
    return dynamic(res);
}

/// calls $1+ on each and returns nil
Dynamic libeach(Args args)
{
    foreach (k, i; args[0].arr)
    {
        Dynamic cur = i;
        foreach (f; args[1 .. $])
        {
            cur = f([cur, k.dynamic]);
        }
    }
    return Dynamic.nil;
}

/// creates new array with only the elemtns that $1 returnd true with
Dynamic libfilter(Args args)
{
    Dynamic[] res;
    foreach (k, i; args[0].arr)
    {
        Dynamic cur = i;
        foreach (f; args[1 .. $])
        {
            cur = f([cur, k.dynamic]);
        }
        if (cur.type != Dynamic.Type.nil && (cur.type != Dynamic.Type.log || cur.log))
        {
            res ~= i;
        }
    }
    return dynamic(res);
}

/// zips arrays interleaving
Dynamic libzip(Args args)
{
    Dynamic[] res;
    foreach (i; 0 .. args[0].arr.length)
    {
        Dynamic[] sub = new Dynamic[args.length];
        foreach (k, ref v; sub)
        {
            v = args[k].arr[i];
        }
        res ~= dynamic(sub);
    }
    return dynamic(res);
}

/// length of array
Dynamic liblen(Args args)
{
    return dynamic(args[0].arr.length);
}

/// splits array with deep equality by elemtns
Dynamic libsplit(Args args)
{
    return dynamic(args[0].arr.splitter(args[1]).map!(x => dynamic(x)).array);
}

/// pushes to an existing array, returning nil
Dynamic libpush(Args args)
{
    *args[0].arrPtr ~= args[1 .. $];
    return Dynamic.nil;
}

/// pops from an existing array, returning nil
Dynamic libpop(Args args)
{
    (*args[0].arrPtr).length--;
    return Dynamic.nil;
}

/// extends pushes arrays to array
Dynamic libextend(Args args)
{
    foreach (i; args[1 .. $])
    {
        (*args[0].arrPtr) ~= i.arr;
    }
    return Dynamic.nil;
}

/// slices array from 0..$1 for 1 argumnet
/// slices array from $1..$2 for 2 argumnets
Dynamic libslice(Args args)
{
    if (args.length == 2)
    {
        return dynamic(args[0].arr[args[1].as!size_t .. $].dup);
    }
    else
    {
        return dynamic(args[0].arr[args[1].as!size_t .. args[2].as!size_t].dup);
    }
}

Dynamic libsorted(Args args)
{
    if (args.length == 1)
    {
        return args[0].arr.sort.array.dynamic;
    }
    else
    {
        throw new Exception("bad number of arguments to sort");
    }
}
