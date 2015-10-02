Base.load_juliarc()

using MATLAB

libmex = dlopen(MATLAB.matlab_library("libmex"), Libdl.RTLD_GLOBAL | Libdl.RTLD_LAZY)
mexfn(fun::Symbol) = dlsym(libmex::Ptr{Void}, fun)

function mex_args(nrhs, prhs)
  ptrs  = pointer_to_array(convert(Ptr{Ptr{Void}}, prhs), nrhs, false)
  [ jvariable(MxArray(mx, false)) for mx in ptrs ]
end

function mex_return(nlhs, plhs, vs...)
  @assert nlhs == length(vs)
  ptrs = pointer_to_array(convert(Ptr{Ptr{Void}}, plhs), nlhs, false)
  for i in 1:nlhs
    mx = mxarray(vs[i])
    mx.own = false
    ptrs[i] = mx.ptr
  end
end

function mex_showerror(e)
  buf = IOBuffer()
  showerror(buf, e)
  seek(buf, 0)
  ccall(mexfn(:mexErrMsgTxt), Void, (Ptr{Uint8},), readall(buf))
end

# a proper eval
function mex_eval(nlhs::Int32, plhs::Ptr{Void}, nrhs::Int32, prhs::Ptr{Void})
  try
    @assert nlhs == nrhs
    mex_return(nlhs, plhs, [ eval(parse(e)) for e in mex_args(nrhs, prhs) ]...)
  catch e
    mex_showerror(e)
  end
end

# call an arbitrary julia function (or other callable)
function mex_call(nlhs::Int32, plhs::Ptr{Void}, nrhs::Int32, prhs::Ptr{Void})
  try
    @assert nlhs == 1 && nrhs >= 1
    args = mex_args(nrhs, prhs)
    mex_return(1, plhs, eval(parse(args[1]))(args[2:end]...))
  catch e
    mex_showerror(e)
  end
end
