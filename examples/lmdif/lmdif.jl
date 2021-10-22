using LsqFit, Calculus

# a simple wrapper for Levenberg-Marquardt with finite differencing for the Jacobian
lmdif(f, x0; show_trace::Bool=false) =
 LsqFit.levenberg_marquardt(f, jacobian(f), x0, show_trace=show_trace)

# custom MEX-like wrapper
using MATLAB: jvalue
lmdif(args::Vector{MATLAB.MxArray}) =
 lmdif(jvalue(args[1]), jvalue(args[2]), show_trace=(length(args)>2 ? jvalue(args[3]) : false))