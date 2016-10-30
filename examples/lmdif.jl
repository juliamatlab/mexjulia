using Optim
using Calculus

# a simple wrapper for Levenberg-Marquardt with finite differencing for the
# Jacobian
lmdif(f, x0) = Optim.levenberg_marquardt(f, jacobian(f), x0)
