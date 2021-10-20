function performance()
%% Mex.jl Performance Overhead
% Here we test the performance overhead of the various ways of calling Julia
% We use the divrem function, since it is very quick and shows how to
% handle multiple arguments

%% Simple method
% Just use jl.call
[a,b] = jl.call('divrem',7,3);
% time it:
tic; for i=1:2000; [a,b] = jl.call('divrem',7,3); end; elpsd = toc;
fprintf('jl.call: %3.0f us/call\n',elpsd*0.5e3);

%% Custom Julia method
% Here we make a 'MEX-like' julia function
jleval divrem_mex(args::Vector{MATLAB.MxArray}) = divrem(MATLAB.jscalar(args[1]),MATLAB.jscalar(args[2]));
% and we use jl.mex
[a,b] = jl.mex('divrem_mex',7,3);
% time it:
tic; for i=1:2000; [a,b] = jl.mex('divrem_mex',7,3); end; elpsd = toc;
fprintf('jl.mex:  %3.0f us/call\n',elpsd*0.5e3);

%% Custom mexjulia wrapper
% We make a special wrapper (see below) to call mexjulia directly. This
% method also requires the MEX-like Julia function we made earlier.
[a,b] = divrem(7,3);
% time it:
tic; for i=1:2000; [a,b] = divrem(7,3); end; elpsd = toc;
fprintf('direct:  %3.0f us/call\n',elpsd*0.5e3);

%% RAW
% For maximum performance. This requires dealing with the MEX pointer arrays
jleval('using MATLAB: MxArray, jscalar, mxarray');
jleval(sprintf('%s\n',...
    'function divrem_raw(plhs::Vector{Ptr{Cvoid}}, prhs::Vector{Ptr{Cvoid}})',...
    'out = divrem(jscalar(MxArray(prhs[1], false)), jscalar(MxArray(prhs[2], false)))',...
    'nlhs = length(plhs)',...
    'nlhs > 0 && (mx = mxarray(out[1]); mx.own = false; plhs[1] = mx.ptr)',...
    'nlhs > 1 && (mx = mxarray(out[2]); mx.own = false; plhs[2] = mx.ptr)',...
    'end'));
[a,b] = divrem_raw(7,3);
% time it:
tic; for i=1:2000; [a,b] = divrem_raw(7,3); end; elpsd = toc;
fprintf('raw:     %3.0f us/call\n',elpsd*0.5e3);
end

%% wrappers
function [o1,o2] = divrem(a,b)
[rv,o1,o2] = mexjulia('jl_mex', 'divrem_mex', a, b);
if ~islogical(rv); throw(rv); end
end

function [o1,o2] = divrem_raw(a,b)
[o1,o2] = mexjulia('divrem_raw', a, b);
end