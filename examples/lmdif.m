% Levenberg-Marquardt solver with finite differencing for the Jacobian
function x = lmdif(f, x0)

% first time through, load the julia function
persistent loaded;
if isempty(loaded)
  jl_file = fullfile(fileparts(mfilename('fullpath')), 'lmdif.jl');
  Jl.include(jl_file);
  loaded = true;
end

sln = Jl.call('lmdif', f, x0);

if ~(sln.x_converged || sln.f_converged || sln.g_converged)
  throw('lmdif failed to converge');
end

x = sln.minimum;

end
