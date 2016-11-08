using Optim
using Calculus

# a simple wrapper for Levenberg-Marquardt with finite differencing for the
# Jacobian
lmdif(f, x0; show_trace::Bool=false) = Optim.levenberg_marquardt(f, jacobian(f), x0, show_trace=show_trace)
