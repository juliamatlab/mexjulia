% Levenberg-Marquardt solver with finite differencing for the Jacobian
function x = lmdif(f, x0)

% first time through, load the julia function
persistent loaded;
if isempty(loaded)
  jl_file = fullfile(fileparts(mfilename('fullpath')), 'lmdif.jl');
  jl.include(jl_file);
  loaded = true;
end

sln = jl.callkw(2, 'lmdif', f, x0, 'show_trace', true);

if ~(sln.x_converged || sln.f_converged || sln.g_converged)
  throw('lmdif failed to converge');
end

x = sln.minimizer;

end
