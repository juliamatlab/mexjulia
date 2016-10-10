classdef Jl

  % the primary user interface
  methods (Static)

    % call a MEX-like Julia function
    function varargout = mex(nout, varargin)
        varargout = cell(nout, 1);
        Jl.check_init;
        [varargout{:}] = mexjulia('jl_mex', varargin{:});
    end

    % interpret string(s) as Julia expression(s), returning value(s)
    function varargout = eval(varargin)
        varargout = cell(nargin, 1);
        [varargout{:}] = Jl.mex(nargin, 'Mex.jl_eval', varargin{:});
    end

    % call a julia function (specified by its name as a string) with
    % the given arguments, returning its value
    function v = call(varargin)
      v = Jl.mex(1, 'Mex.jl_call', varargin{:});
    end

    % include a file in the Julia runtime
    function include(fn)
      Jl.eval(['include("' Jl.forward_slashify(fn) '")']);
    end

  end

  methods (Static)
    
    % Check that the Julia runtime is initialized (and initialize it, if
    % necessary).
    function check_init()
      
      try
        % fast path
        if mexjulia, return, end;
      catch
        warning('It appears the mexjulia MEX function is missing. Attempting to build...\n');
        Jl.build;
      end
      
      % basic runtime initialization
      mexjulia('');

      % Make sure MATLAB_HOME points to _this_ version of matlab.
      setenv('MATLAB_HOME', Jl.matlab_dir);

      % load the boot file
      boot_file = Jl.forward_slashify(fullfile(Jl.this_dir, 'jl', 'boot.jl'));
      assert(exist(boot_file, 'file') == 2);
      mexjulia(0, ['include("' boot_file '")']);
    end
    
    % (re)build the mexjulia MEX function and do some other checks
    function build(exe)
      
      % get the path to the julia to build against
      if nargin < 1
        % try to guess the path of the julia executable
        if ispc
          [~, exe] = system('where julia');
        else
          [~, exe] = system('which julia');
        end
        exe = strtrim(exe);
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
      
      % get the config script
      jl_root = fileparts(fileparts(exe));
      cfg = fullfile(jl_root, 'share', 'julia', 'julia-config.jl');
      assert(exist(cfg, 'file') == 2);
      fprintf('The path of the Julia configuration script is %s\n', cfg);
      
      % get the build options
      [~, cflags] = system(sprintf('"%s" "%s" %s', exe, cfg, '--cflags'));
      cflags = Jl.chomp(cflags);
      [~, ldflags] = system(sprintf('"%s" "%s" %s', exe, cfg, '--ldflags'));
      ldflags = Jl.chomp(ldflags);
      if ispc
        ldlibs = fullfile(jl_root, 'lib', 'libjulia.dll.a');
      else
        [~, ldlibs] = system(sprintf('"%s" "%s" %s', exe, cfg, '--ldlibs'));
        ldlibs = Jl.chomp(ldlibs);
      end

      % build the mex file
      src = fullfile(Jl.this_dir, 'mexjulia.cpp');
      mex_cmd = 'mex -largeArrayDims -O %s %s %s %s';
      eval(sprintf(mex_cmd, cflags, ldflags, src, ldlibs));
      
      % make sure the MATLAB.jl package is installed.
      [~, pkg_add] = system(sprintf('%s -e "Pkg.add(\\"MATLAB\\")"', exe));
      fprintf('Ensuring the MATLAB package is installed...\n%s', pkg_add);

      % check if this directory is on the search path
      path_dirs = regexp(path, pathsep, 'split');
      if ispc
        on_path = any(strcmpi(Jl.this_dir, path_dirs));
      else
        on_path = any(strcmp(Jl.this_dir, path_dirs));
      end
      
      % if not, add it and save
      fprintf('Is %s on the MATLAB path? ', Jl.this_dir);
      if ~on_path
        fprintf('No. Adding it and saving...\n');
        path(Jl.this_dir, path);
        savepath;
      else
        fprintf('Yes.\n');
      end
    end
    
    % full path of the mexjulia directory
    function md = this_dir()
      md = fileparts(mfilename('fullpath'));
    end

    % path to the root of this version of matlab
    function mh = matlab_dir()
      mh = fileparts(fileparts(fileparts(fileparts(which('path')))));
    end

    % replace backslashes with forward slashes on pcs (id fn otherwise)
    function p = forward_slashify(p)
      if ispc
        p = regexp(p, filesep, 'split');
        p = [sprintf('%s/', p{1:end-1}) p{end}];
      end
    end

    % remove leading, trailing whitespace
    function str = chomp(str)
      str = regexprep(str, '^\s*', '');
      str = regexprep(str, '\s$', '');
    end
  end
end
