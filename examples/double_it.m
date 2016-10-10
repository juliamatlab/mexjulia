% An example of a custom mex-like Julia Function

% Define a mex-like julia function. A mex-like julia function accepts a 
% vector of MxArrays as its single input and returns an iterable 
% collection of values, each of which can be passed to `mxarray`.
Jl.eval('double_it(args::Vector{MxArray}) = [2*jvariable(arg) for arg in args]');

% Generate some data.
a = rand(5, 5)

% Call our function. The first argument is the number of output values to
% be returned.
Jl.mex(1, 'double_it', a)
