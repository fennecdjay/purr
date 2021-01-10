module lang.quest.globals;

import std.stdio;
import std.functional;
import std.algorithm;
import lang.dynamic;
import lang.quest.qscope;
import lang.quest.dynamic;
import lang.quest.maker;
import lang.quest.std.kernel;
import lang.quest.std.basic;
import lang.quest.std.null_;
import lang.quest.std.comparable;
import lang.quest.std.number;
import lang.quest.std.text;
import lang.quest.std.function_;
import lang.quest.std.object;

Table gobject = null;
Table globalObject()
{
    if (gobject is null)
    {
        Mapping meta = emptyMapping;
        meta["str".dynamic] = dynamic(&objectStrToAtText);
        meta["cmp".dynamic] = dynamic(&objectMetaCmp);
        gobject = new Table(emptyMapping, new Table(meta));
        Mapping mapping = emptyMapping;
        mapping[".=".qdynamic] = qdynamic(&objectDotEquals);
        mapping["<=>".qdynamic] = qdynamic(&objectCmp);
        mapping["==".qdynamic] = qdynamic(&objectEq);
        mapping["!=".qdynamic] = qdynamic(&objectNeq);
        gobject.table = mapping;
    }
    return gobject;
}

Table gbasic = null;
Table globalBasic()
{
    if (gbasic is null)
    {
        Mapping mapping = emptyMapping;
        Mapping meta = emptyMapping;
        meta["cmp".dynamic] = dynamic(&basicMetaCmp);
        gbasic = new Table(mapping, new Table(meta).withProto(globalObject));
    }
    return gbasic;
}

Table gcmp = null;
Table globalCmp()
{
    if (gcmp is null)
    {
        Mapping mapping = emptyMapping;
        gcmp = new Table(mapping, new Table().withProto(globalObject));
        mapping["<".qdynamic] = qdynamic(&cmpLt);
        mapping[">".qdynamic] = qdynamic(&cmpGt);
        mapping["<=".qdynamic] = qdynamic(&cmpLte);
        mapping[">=".qdynamic] = qdynamic(&cmpGte);
    }
    return gcmp;
}

Table gnumber = null;
Table globalNumber()
{
    if (gnumber is null)
    {
        Mapping mapping = emptyMapping;
        gnumber = new Table(mapping, new Table().withProto(globalBasic, globalCmp, globalObject));
        mapping["@text".qdynamic] = qdynamic(&numberText);
        mapping["+".qdynamic] = qdynamic(&numberAdd);
        mapping["-".qdynamic] = qdynamic(&numberSub);
        mapping["*".qdynamic] = qdynamic(&numberMul);
        mapping["/".qdynamic] = qdynamic(&numberDiv);
        mapping["%".qdynamic] = qdynamic(&numberMod);
        mapping["+=".qdynamic] = qdynamic(&numberSetAdd);
        mapping["-=".qdynamic] = qdynamic(&numberSetSub);
        mapping["*=".qdynamic] = qdynamic(&numberSetMul);
        mapping["/=".qdynamic] = qdynamic(&numberSetDiv);
        mapping["%=".qdynamic] = qdynamic(&numberSetMod);
        mapping["<=>".qdynamic] = qdynamic(&numberCmp);
    }
    return gnumber;
}

Table gstring = null;
Table globalText()
{
    if (gstring is null)
    {
        Mapping meta = emptyMapping;
        meta["str".dynamic] = dynamic(&textMetaStr);
        gstring = new Table(emptyMapping, new Table(meta).withProto(globalBasic, globalCmp, globalObject));
        Mapping mapping = emptyMapping;
        mapping["@text".qdynamic] = qdynamic(&textText);
        mapping["=".qdynamic] = qdynamic(&textSet);
        mapping["<=>".qdynamic] = qdynamic(&textCmp);
        gstring.table = mapping;
    }
    return gstring;
}

Table gnull = null;
Table globalNull()
{
    if (gstring is null)
    {
        Mapping mapping = emptyMapping;
        Mapping meta = emptyMapping;
        meta["val".dynamic] = Dynamic.nil;
        gnull = new Table(mapping, new Table(meta).withProto(globalBasic, globalObject));
        mapping["@text".qdynamic] = "null".makeText;
    }
    return gnull;
}

Table gfunc = null;
Table globalFunction()
{
    if (gfunc is null)
    {
        gfunc = new Table(emptyMapping, new Table().withProto(globalBasic, globalObject));
        Mapping mapping = emptyMapping;
        mapping["()".qdynamic] = qdynamic(&functionCall);
        mapping["@text".qdynamic] = qdynamic(&functionText);
        gfunc.table = mapping;
    }
    return gfunc;
}

Table baseScope() {
    Mapping mapping = emptyMapping;
    mapping["disp".qdynamic] = qdynamic(&globalDisp);
    mapping["dispn".qdynamic] = qdynamic(&globalDispn);
    mapping["return".qdynamic] = qdynamic(&globalReturn);
    mapping["Number".qdynamic] = globalNumber.qdynamic;
    mapping["Text".qdynamic] = globalText.qdynamic;
    mapping["Function".qdynamic] = globalFunction.qdynamic;
    mapping["Object".qdynamic] = globalObject.qdynamic;
    return new Table(mapping, new Table().withProto(globalObject));
}