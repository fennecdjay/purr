module lang.plugin.loader;

import std.stdio;
import std.string;
import lang.plugin.plugins;
import lang.plugin.plugin;
import core.sys.posix.dlfcn;

void*[string] dlls;
string[] paths;

void linkLang(string name)
{
    void* handle = dlopen(name.toStringz, RTLD_LAZY);
    if (handle is null)
    {
        throw new Exception("cannot dlopen: " ~ name);
    }
    dlls[name] = handle;
    Plugin function() fplugin = cast(Plugin function()) dlsym(handle, "dext_get_library_plugin".toStringz);
    char* err = dlerror();
    if (err !is null)
    {
        throw new Exception(cast(string) ("dlsym error: " ~ err.fromStringz));
    }
    Plugin plugin = fplugin();
    addPlugin(plugin);
}