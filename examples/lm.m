function sln = lm(f, jac, x0)

% first time through, load the julia function
persistent loaded;
if isempty(loaded)
  jl_file = fullfile(fileparts(mfilename('fullpath')), 'lm.jl');
  Jl.include(jl_file);

  loaded = true;
end

sln = Jl.mex(1, 'mex_levenberg_marquardt', f, jac, x0);
