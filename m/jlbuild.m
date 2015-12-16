function jlbuild(vq)

if nargin < 1
  vq = '';
end

this_dir = fileparts(mfilename('fullpath'));
conf_name = fullfile(this_dir, 'jlconfig.mat');
if exist(conf_name, 'file') ~= 2
  warning([conf_name ' not found. Attempting to reconfigure...']);
  jlconfig;
end
conf = matfile(conf_name);

% build the mex file
julia_src = fullfile(this_dir, '..', 'src', 'jlcall.cpp');
mex_cmd = 'mex %s -largeArrayDims -O -output jlcall -outdir ''%s'' -I''%s'' -L''%s'' ''%s'' %s';
eval(sprintf(mex_cmd, vq, this_dir, conf.julia_include_dir, conf.julia_lib_dir, julia_src, conf.lib_opt));

end
