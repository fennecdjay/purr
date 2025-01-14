module ext.paka.plugin;

import ext.paka.base;
import ext.paka.parse.parse;
import purr.plugin.plugin;
import purr.plugin.plugins;

shared static this()
{
    thisPlugin.addPlugin;
}

Plugin thisPlugin()
{
    Plugin plugin = new Plugin;
    plugin.libs ~= pakaBaseLibs;
    plugin.parsers["paka"] = code => parse(code);
    return plugin;
}
