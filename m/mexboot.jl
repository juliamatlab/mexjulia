# load user init script
haskey(ENV, "HOME") &&
isfile(ENV["HOME"]*"/.juliarc.jl") &&
include(ENV["HOME"]*"/.juliarc.jl");

using MATLAB
# would be great to redirect STD[IN|OUT|ERR]...

libmex = dlopen("C:/Program Files/MATLAB/R2015a/bin/win64/libmex", Libdl.RTLD_GLOBAL | Libdl.RTLD_LAZY)
mexfunc(fun::Symbol) = dlsym(libmex::Ptr{Void}, fun)
mex_printf(msg) = ccall(mexfunc(:mexPrintf), Int32, (Ptr{Uint8},), ASCIIString(string(msg)))

# test functions
function mexhello(nlhs::Int32, plhs::Ptr{Void}, nrhs::Int32, prhs::Ptr{Void})
  mex_printf(ENV["HOME"]*"\n")
  mex_printf(ENV["JULIA_PKGDIR"]*"\n")
  mex_printf(Pkg.dir()*"\n")
end

function mexlibpath(nlhs::Int32, plhs::Ptr{Void}, nrhs::Int32, prhs::Ptr{Void})
  mex_printf(MATLAB.matlab_library_path*"\n")
end

mex_err_msg_txt(msg) = ccall(mexfunc(:mexErrMsgTxt), Void, (Ptr{Uint8},), ASCIIString(string(msg)))
mex_warn_msg_txt(msg) = ccall(mexfunc(:mexWarnMsgTxt), Void, (Ptr{Uint8},), ASCIIString(string(msg)))

# helpers for mexFunction args
# function mexargs(nlhs::Int32, plhs::Ptr{Void}, nrhs::Int32, prhs::Ptr{Void})
#   outs = pointer_to_array(convert(Ptr{Ptr{Void}}, plhs), nlhs, false)
#   ins = pointer_to_array(convert(Ptr{Ptr{Void}}, prhs), nrhs, false)
#
#   arys = Vector{MATLAB.MxArray}(nrhs)
#   for i in 1:nrhs
#     arys[i] = MATLAB.MxArray(ins[i], false)
#   end
#
#   (outs, arys)
# end

# define a proper eval
# function mexeval(nlhs::Int32, plhs::Ptr{Void}, nrhs::Int32, prhs::Ptr{Void})
#   (outs, arys) = mexargs(nlhs, plhs, nrhs, prhs)
#
#   for i in 1:length(arys)
#     # evaluate the argument, converted to a string
#     v = eval(jstring(arys[i]))
#
#     # if there is a corresponding output, return the value
#     if i <= nlhs
#       mx = MATLAB.mxarray(v)
#       mx.own = false
#       outs[i] = mx.ptr
#     end
#   end
# end
