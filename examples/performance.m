function performance()
%% Mex.jl Performance Overhead
% Here we test the performance overhead of the various ways of calling Julia
% We use the divrem function, since it is very quick and shows how to
% handle multiple arguments

%% jl.call
% allow Julia to compile.
[q,r] = jl.call('divrem',7,3);
% time it:
tic; for i=1:2000; [q,r] = jl.call('divrem',7,3); end; elpsd = toc;
fprintf('jl.call: %3.0f us/call\n',elpsd*0.5e3);

%% jl.mex
% Here we make a 'MEX-like' julia function
jleval divrem_mex(args::Vector{MATLAB.MxArray}) = divrem(MATLAB.jscalar(args[1]),MATLAB.jscalar(args[2]));
% allow Julia to compile.
[q,r] = jl.mex('divrem_mex',7,3);
% time it:
tic; for i=1:2000; [q,r] = jl.mex('divrem_mex',7,3); end; elpsd = toc;
fprintf('jl.mex:  %3.0f us/call\n',elpsd*0.5e3);

%% mexjulia
% We make a custom wrapper (see `divrem` below) to call mexjulia directly. This
% method also requires the MEX-like Julia function we made earlier.
[q,r] = divrem(7,3);
% time it:
tic; for i=1:2000; [q,r] = divrem(7,3); end; elpsd = toc;
fprintf('direct:  %3.0f us/call\n',elpsd*0.5e3);

%% mexjulia raw
% For maximum performance. This requires dealing with the MEX pointer arrays
jleval('using MATLAB: MxArray, jscalar, mxarray');
jleval(sprintf('%s\n',...
    'function divrem_raw(plhs::Vector{Ptr{Cvoid}}, prhs::Vector{Ptr{Cvoid}})',...
    'out = divrem(jscalar(MxArray(prhs[1], false)), jscalar(MxArray(prhs[2], false)))',...
    'nlhs = length(plhs)',...
    'nlhs > 0 && (mx = mxarray(out[1]); mx.own = false; plhs[1] = mx.ptr)',...
    'nlhs > 1 && (mx = mxarray(out[2]); mx.own = false; plhs[2] = mx.ptr)',...
    'end'));
[q,r] = divrem_raw(7,3);
% time it:
tic; for i=1:2000; [q,r] = divrem_raw(7,3); end; elpsd = toc;
fprintf('raw:     %3.0f us/call\n',elpsd*0.5e3);
end

%% wrappers
function [q,r] = divrem(x,y)
[rv,q,r] = mexjulia('jl_mex', 'divrem_mex', x, y);
if ~islogical(rv); throw(rv); end
end

function [q,r] = divrem_raw(x,y)
[q,r] = mexjulia('divrem_raw', x, y);
end