import Libdl
import Printf
using MATLAB

# include elements from the julia-config.jl script, needed for getting flags for
# building the mex file

isDebug() = ccall(:jl_is_debugbuild, Cint, ()) != 0

function shell_escape(str)
    str = replace(str, "'" => "'\''")
    return "\"$str\""
end

function libDir()
    return if isDebug()
        dirname(abspath(Libdl.dlpath("libjulia-debug")))
    else
        dirname(abspath(Libdl.dlpath("libjulia")))
    end
end

private_libDir() = abspath(Sys.BINDIR, Base.PRIVATE_LIBDIR)

function includeDir()
    return abspath(Sys.BINDIR, Base.INCLUDEDIR, "julia")
end

function cflags()
    fl = "-I $(shell_escape(includeDir()))"
    if Sys.isunix()
        fl = fl * " -fPIC"
    end
    return fl
end

function ldflags()
    fl = "-L$(shell_escape(libDir()))"
    if Sys.isunix()
        fl = fl * " -Wl,-rpath $(shell_escape(libDir()))"
    end
    return fl
end

function ldlibs()
    libname = if isDebug()
        "julia-debug"
    else
        "julia"
    end
    if Sys.isunix()
        return "-l$libname -ldl"
    else
        return "-l$libname -lopenlibm"
    end
end

# get build parameters
is_debug = isDebug()
julia_bin = is_debug ?
    joinpath(unsafe_string(Base.JLOptions().julia_bindir), "julia-debug") :
    joinpath(unsafe_string(Base.JLOptions().julia_bindir), "julia")
julia_home = unsafe_string(Base.JLOptions().julia_bindir)
sys_image = unsafe_string(Base.JLOptions().image_file)
lib_base = is_debug ? "julia-debug" : "julia"
lib_path = Libdl.dlpath("lib$lib_base")
lib_dir = Sys.iswindows() ? joinpath(dirname(julia_home), "lib") : dirname(lib_path)
inc_dir = includeDir()
build_cflags = cflags()
build_ldflags = ldflags()
build_ldlibs = ldlibs()
build_src = abspath("mexjulia.cpp")
outdir = joinpath(pwd(),"..","mexjulia")
mex_cmd = "mex -v -largeArrayDims -outdir \"$outdir\" LDFLAGS=\'$(build_ldflags) \$LDFLAGS\' CFLAGS=\'$(build_cflags) \$CFLAGS\' \"$(build_src)\" $(build_ldlibs)"

# Save build parameters to .mat file
mat"""
% save build parameters to .mat file
is_debug = $is_debug;
julia_bin = $julia_bin;
julia_home = $julia_home;
sys_image = $sys_image;
lib_base = $lib_base;
lib_path = $lib_path;
lib_dir = $lib_dir;
inc_dir = $inc_dir;
build_cflags = $build_cflags;
build_ldflags = $build_ldflags;
build_ldlibs = $build_ldlibs;
build_src = $build_src;
mex_cmd = $mex_cmd;
save("jldict.mat", "is_debug", "julia_bin", "julia_home",...
    "sys_image", "lib_base", "lib_path", "lib_dir", "inc_dir", "build_cflags",...
    "build_ldflags", "build_ldlibs", "build_src", "mex_cmd");
"""

# build mex file
s1 = MSession()
eval_string(s1, mex_cmd)
close(s1)

# move jldict.mat to mexjulia folder
mv("jldict.mat", joinpath(outdir, "jldict.mat"), force=true)

# add mexjulia directory to MATLAB path
mat"""
% check if current directory is on MATLAB path
path_dirs = regexp(path, pathsep, 'split');
if ispc
    on_path = any(strcmpi($outdir, path_dirs));
else
    on_path = any(strcmp($outdir, path_dirs));
end

% if not, add it and save
if ~on_path
    fprintf('%s is not on the MATLAB path. Adding it and saving...\\n\', $(pwd()));
    path($outdir, path);
    savepath;
end
"""
