% An example of a MATLAB exception caught in Julia and passed back to
% MATLAB (with the Julia backtrace appended)
function matlab_exception()

exn_thrower = @() error('I take exception to everything.');

try
    jl.call('Mex.call_matlab', int32(0), exn_thrower)
catch e
    disp(getReport(e));
end

end

