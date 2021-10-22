% An example of a MATLAB function called by embedded Julia
function varargout = call_matlab_function(funcname, varargin)

nout = max(1, nargout);

[varargout{1:nout}] = jl.call('Mex.call_matlab', nout, funcname, varargin{:});

end