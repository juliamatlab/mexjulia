function jlconfig(exe)

if nargin < 1
  % try to guess the path of the julia executable
  if ispc
    [~, o] = system('where julia');
  else
    [~, o] = system('which julia');
  end
  exes = strsplit(o, {'\n','\r'}, 'CollapseDelimiters', true);
  exe = exes{1};
  if exist(exe, 'file') == 0
    exe = 'julia';
  end

  % get path of julia executable
  if ispc
    wc = '*.exe';
  else
    wc = '*';
  end
  [exe, pathexe] = uigetfile(wc,'Select the Julia executable', exe);
  exe = [pathexe exe];
end
assert(exist(exe, 'file') == 2);
fprintf('The path of the Julia executable is %s\n', exe);

% get the julia bin directory
julia_bin_dir = directory(exe);
assert(exist(julia_bin_dir, 'dir') == 7);
fprintf('The directory of the Julia executable is %s\n', julia_bin_dir);

% get julia home
if ispc
  cmd = '%s -e println(%s)';
else
  cmd = '%s -e ''println(%s)''';
end
[~, julia_home] = system(sprintf(cmd, exe, 'JULIA_HOME'));
julia_home = chomp(julia_home);
assert(exist(julia_home, 'dir') == 7);
fprintf('JULIA_HOME is %s\n', julia_home);

% get julia image
[~, julia_image] = system(sprintf(cmd, exe, 'bytestring(Base.JLOptions().image_file)'));
julia_image = chomp(julia_image);
assert(exist(julia_image, 'file') == 2);
fprintf('The Julia image is %s\n', julia_image);

% get include dir
if ispc
  inc_dir_str = '"joinpath(match(r\"(.*)(bin)\",JULIA_HOME).captures[1],\"include\",\"julia\")"';
else
  inc_dir_str = 'joinpath(match(r"(.*)(bin)",JULIA_HOME).captures[1], "include", "julia")';
end
[~, julia_include_dir] = system(sprintf(cmd, exe, inc_dir_str));
julia_include_dir = chomp(julia_include_dir);
assert(exist(julia_include_dir, 'dir') == 7);
assert(exist([julia_include_dir filesep 'julia.h'], 'file') == 2);
fprintf('The Julia include directory is %s\n', julia_include_dir);

% get lib dir, opts
if ispc
  bits = strsplit(julia_image, filesep);
  julia_lib_dir = strjoin(bits(1:end-2), filesep);
  lib_opt = 'libjulia.dll.a';
else
  [~, julia_lib_dir] = system(sprintf(cmd, exe, 'abspath(dirname(Libdl.dlpath("libjulia")))'));
  lib_opt = '-ljulia';
end
julia_lib_dir = chomp(julia_lib_dir);
assert(exist(julia_lib_dir, 'dir') == 7);

% write the config file
this_dir = directory(mfilename('fullpath'));
conf = matfile([this_dir filesep 'jlconfig.mat']);
conf.Properties.Writable = true;
conf.julia_bin_dir = julia_bin_dir;
conf.julia_home = julia_home;
conf.julia_image = julia_image;
conf.julia_include_dir = julia_include_dir;
conf.julia_lib_dir = julia_lib_dir;
conf.lib_opt = lib_opt;

% build the mex function
jlbuild;

% check if this directory is on the search path
path_dirs = strsplit(path, pathsep);
if ispc
  on_path = any(strcmpi(this_dir, path_dirs));
else
  on_path = any(strcmp(this_dir, path_dirs));
end

% if not, add it and save
if ~on_path
  fprintf('%s is not on the MATLAB path. Adding it and saving...\n', this_dir);
  path(this_dir, path);
  savepath;
else
  fprintf('%s is already on the MATLAB path.\n', this_dir);
end

fprintf('Configuration complete.\n');

end

% *** helper functions ***

% directory of path
function d = directory(p)
  bits = strsplit(p, filesep);
  d = strjoin(bits(1:end-1), filesep);
end

% remove leading, trailing whitespace
function str = chomp(str)
  str = regexprep(str, '^\s*', '');
  str = regexprep(str, '\s$', '');
end

function str = np(str)
  str = strjoin(strsplit(str, filesep), '/');
end
