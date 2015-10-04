Base.load_juliarc()

using MATLAB

const libmex = dlopen(MATLAB.matlab_library("libmex"), Libdl.RTLD_GLOBAL | Libdl.RTLD_LAZY)
mexfn(fun::Symbol) = dlsym(libmex::Ptr{Void}, fun)

function call_matlab(fn::ASCIIString, nout::Integer, args...)
  mxs = map(mxarray, args)
  ins = Ptr{Void}[mx.ptr for mx in mxs]
  nin = length(ins)

  outs = Vector{Ptr{Void}}(nout)

  @assert 0 == ccall(mexfn(:mexCallMATLAB), Int32,
    (Int32, Ptr{Ptr{Void}}, Int32, Ptr{Ptr{Void}}, Ptr{Uint8}),
     nout,  outs,           nin,   ins,            fn        )

  [jvariable(MxArray(o)) for o in outs]
end

mex_write(fid, bytes) = call_matlab("fwrite", 0, Float64(fid), bytes)

# redirect STDOUT, STDERR -- wish I knew how to do that!
#const pout = redirect_stdout()[1]
#const perr = redirect_stderr()[1]
# pout.readcb = p -> mex_write(1, readavailable(p))
# perr.readcb = p -> mex_write(2, readavailable(p))
# Base.start_reading(pout)
# Base.start_reading(perr)

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

# a fancier eval
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
