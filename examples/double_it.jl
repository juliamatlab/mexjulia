function double_it(nlhs::Int32, plhs::Ptr{Void}, nrhs::Int32, prhs::Ptr{Void})
  try
    @assert nlhs <= 1 && nrhs == 1
    args = mex_args(nrhs, prhs)
    mex_return(1, plhs, 2*args[1])
  catch e
    mex_showerror(e)
  end
end
