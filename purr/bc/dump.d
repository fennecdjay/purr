module purr.bc.dump;

import std.conv;
import purr.io;
import purr.bytecode;
import purr.bc.iterator;

class OpcodePrinter : OpcodeIterator
{
    string ret;
    size_t depth = 0;

    void inline(A...)(A args)
    {
        static foreach (i, arg; args)
        {
            ret ~= arg.to!string;
        }
    }

    void line(A...)(A args)
    {
        inline(args, "\n");
    }

    void indent()
    {
        foreach (_; 0 .. depth)
        {
            ret ~= "    ";
        }
    }

override:
    void enter(Function func)
    {
        if (func.stab.length != 0)
        {
            foreach (k, v; func.stab.byPlace)
            {
                indent;
                foreach (i; 0 .. func.instrs.length.to!string.length + 1)
                {
                    inline(' ');
                }
                line(".symbol offset=", k, " identifier=", v);
            }
        }
        if (func.capture.length != 0)
        {
            foreach (cap; func.capture)
            {
                indent;
                foreach (i; 0 .. func.instrs.length.to!string.length + 1)
                {
                    inline(' ');
                }
                line(".capture offset=", cap.offset, " identifier=", func.captab[cap.offset],
                        " from=", cap.from, " direct=", !cap.is2, " arg=", cap.isArg);
            }
        }
    }

    void got(Opcode op)
    {
        foreach (_; 0 .. depth)
        {
            ret ~= "    ";
        }
        string bstr = bytepos.to!string;
        foreach (i; bstr.length .. func.instrs.length.to!string.length)
        {
            inline('0');
        }
        inline(bstr);
        inline(": ");
    }

    void nop()
    {
        line("nop");
    }

    void push(ushort constIndex)
    {
        line("push index=", constIndex, " value=", func.constants[constIndex]);
    }

    void pop()
    {
        line("pop");
    }

    void rec()
    {
        line("rec");
    }

    void sub(ushort funcIndex)
    {
        line("sub index=", funcIndex, " func={");
        depth++;
        walk(func.funcs[funcIndex]);
        depth--;
        indent;
        line("}");
    }

    void call(ushort argCount)
    {
        line("call argc=", argCount);
    }

    void scall(ushort constIndex, ushort argCount)
    {
        line("scall index=", constIndex, " argc=", argCount);
    }

    void opgt()
    {
        line("opgt");
    }

    void oplt()
    {
        line("oplt");
    }

    void opgte()
    {
        line("opgte");
    }

    void oplte()
    {
        line("oplte");
    }

    void opeq()
    {
        line("opeq");
    }

    void opneq()
    {
        line("opneq");
    }

    void tuple(ushort argCount)
    {
        line("tuple length=", argCount);
    }

    void array(ushort argCount)
    {
        line("array length=", argCount);
    }

    void table(ushort argCount)
    {
        line("table length=", argCount);
    }

    void index()
    {
        line("index");
    }

    void opneg()
    {
        line("opneg");
    }

    void opcat()
    {
        line("opcat");
    }

    void opadd()
    {
        line("opadd");
    }

    void opsub()
    {
        line("opsub");
    }

    void opmul()
    {
        line("opmul");
    }

    void opdiv()
    {
        line("opdiv");
    }

    void opmod()
    {
        line("opmod");
    }

    void load(ushort localIndex)
    {
        line("load offset=", localIndex, " identifier=", func.stab[localIndex]);
    }

    void loadc(ushort captureIndex)
    {
        line("loadc offset=", captureIndex, " capture=", func.captab[captureIndex]);
    }

    void store(ushort localIndex)
    {
        line("store offset=", localIndex, " identifier=", func.stab[localIndex]);
    }

    void istore()
    {
        line("istore");
    }

    void cstore(ushort captureIndex)
    {
        line("store offset=", captureIndex, " identifier=", func.captab[captureIndex]);
    }

    void retval()
    {
        line("retval");
    }

    void iftrue(ushort jumpIndex)
    {
        line("iftrue index=", jumpIndex);
    }

    void branch(ushort iftrue, ushort iffalse)
    {
        line("branch iftrue=", iftrue, " iffalse=", iffalse);
    }

    void iffalse(ushort jumpIndex)
    {
        line("iffalse index=", jumpIndex);
    }

    void jump(ushort jumpIndex)
    {
        line("jump index=", jumpIndex);
    }

    void argno(ushort argIndex)
    {
        line("argno number=", argIndex);
    }

    void args()
    {
        line("args");
    }

    void inspect()
    {
        line("inspect");
    }
}