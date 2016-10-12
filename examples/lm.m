function sln = lm(f, x0)

% first time through, load the julia function
persistent loaded;
if isempty(loaded)
  jl_file = fullfile(fileparts(mfilename('fullpath')), 'lm.jl');
  Jl.include(jl_file);

  loaded = true;
end

try
  sln = Jl.mex(1, 'mex_levenberg_marquardt', f, x0);
catch
  % if error, force reload for next time (presumably after editing the script)
  loaded = [];
end