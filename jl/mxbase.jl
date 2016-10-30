# Determine MATLAB library path and provide facilities to load libraries with
# this path

function get_paths()
    global matlab_homepath = get(ENV, "MATLAB_HOME", "")
    if matlab_homepath == ""
        if is_linux()
            matlab_homepath = dirname(dirname(realpath(chomp(readstring(`which matlab`)))))
        elseif is_apple()
            apps = readdir("/Applications")
            filter!(app -> ismatch(r"^MATLAB_R[0-9]+[ab]\.app$", app), apps)
            if ~isempty(apps)
                matlab_homepath = joinpath("/Applications", maximum(apps))
            end
        elseif is_windows()
            default_dir = Int == Int32 ? "C:\\Program Files (x86)\\MATLAB" : "C:\\Program Files\\MATLAB"
            if isdir(default_dir)
                dirs = readdir(default_dir)
                filter!(dir -> ismatch(r"^R[0-9]+[ab]$", dir), dirs)
                if ~isempty(dirs)
                    matlab_homepath = joinpath(default_dir, maximum(dirs))
                end
            end
        end
    end

    if matlab_homepath == ""
        error("The MATLAB path could not be found. Set the MATLAB_HOME environmental variable to specify the MATLAB path.")
    end

    # Get path to MATLAB libraries
    global matlab_library_path = nothing
    if is_linux()
        matlab_library_path = joinpath(matlab_homepath, "bin", (Int == Int32 ? "glnx86" : "glnxa64"))
    elseif is_apple()
        matlab_library_path = joinpath(matlab_homepath, "bin", (Int == Int32 ? "maci" : "maci64"))
    elseif is_windows()
        matlab_library_path = joinpath(matlab_homepath, "bin", (Int == Int32 ? "win32" : "win64"))
    end

    if matlab_library_path != nothing && !isdir(matlab_library_path)
        matlab_library_path = nothing
    end
end
get_paths()

function open_matlab_library(lib::String)
    lib_path = matlab_library_path == nothing ? lib : joinpath(matlab_library_path, lib)
    ptr = Libdl.dlopen(lib_path, Libdl.RTLD_GLOBAL | Libdl.RTLD_LAZY)
    if ptr == C_NULL
        error("Failed to load $(lib)")
    end
    ptr
end
