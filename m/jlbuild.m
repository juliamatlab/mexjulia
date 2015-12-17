function jlbuild(vq)

if nargin < 1
  vq = '';
end

bits = strsplit(mfilename('fullpath'), filesep);
this_dir = strjoin(bits(1:end-1), filesep);
conf_name = [this_dir filesep 'jlconfig.mat'];
if exist(conf_name, 'file') ~= 2
  warning([conf_name ' not found. Attempting to reconfigure...']);
  jlconfig;
end
conf = matfile(conf_name);

% build the mex file
julia_src = [this_dir filesep '..' filesep 'src' filesep 'jlcall.cpp'];
mex_cmd = 'mex %s -largeArrayDims -O -output jlcall -outdir ''%s'' -I''%s'' -L''%s'' ''%s'' %s';
eval(sprintf(mex_cmd, vq, this_dir, conf.julia_include_dir, conf.julia_lib_dir, julia_src, conf.lib_opt));

% Add rpath to the binary
if ismac
  system(sprintf('install_name_tool -add_rpath ''%s'' ''%s''', conf.julia_lib_dir, fullfile(this_dir, ['jlcall.' mexext])));
end

end
