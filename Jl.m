classdef Jl

  % the primary user interface
  methods (Static)

    % call a MEX-like Julia function
    function varargout = mex(nout, varargin)
        varargout = cell(nout, 1);
        Jl.check_initialized;
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
    
    function prompt()
      while true
        expr = input('julia> ', 's');
        if startsWith(expr,';'), break, end
        Jl.eval(expr)  
      end
    end
    
  end

  methods (Static)
    
    function bl = is_initialized()
      bl = false;
      try
        bl = mexjulia;
      end
    end
    
    % Check that the Julia runtime is initialized (and initialize it, if
    % necessary).
    function check_initialized()
      if ~Jl.is_initialized
        
        % check that the mexfunction exists
        if isempty(which('mexjulia'))
          error('It appears the mexjulia MEX function is missing. Consider running "Jl.build".\n');
        end

        if ispc
          % This is a hack for windows which lets the mex function
          % find the julia dlls during initialization without requiring that
          % julia be on the path. Shouldn't be necessary on platforms
          % that have rpath.
          old_dir = pwd;
          cd(Jl.julia_home);
        end
     
        % basic runtime initialization
        mexjulia('', Jl.julia_home, Jl.julia_sys_image);

        % Make sure MATLAB_HOME points to _this_ version of matlab.
        setenv('MATLAB_HOME', Jl.matlab_dir);

        % load the boot file
        mexjulia(0, ['include("' Jl.boot_file '")']);
      
        if ispc, cd(old_dir), end
      end    
    end
    
    function config(exe)
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
      
      % get the path of the image file
      cmd = 'println(unsafe_string(Base.JLOptions().image_file))';
      [~, img] = system(sprintf('"%s" -e "%s"', exe, cmd));
      img = Jl.chomp(img);
      assert(exist(img, 'file') == 2);
      fprintf('The path of the system image is %s\n', img);
      
      % save these to a mat file
      save jlconfig exe img;
      
      % rebuild the mex function, given the new configuration
      Jl.build;
    end
    
    % (re)build the mexjulia MEX function and do some other checks
    function build()
      
      % get the config script
      jl_root = fileparts(Jl.julia_home);
      cfg = fullfile(jl_root, 'share', 'julia', 'julia-config.jl');
      assert(exist(cfg, 'file') == 2);
      fprintf('The path of the Julia configuration script is %s\n', cfg);
      
      % get the build options
      exe = Jl.julia_bin;
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
      mex_cmd = 'mex -largeArrayDims -g -outdir "%s" %s %s %s %s';
      eval(sprintf(mex_cmd, Jl.this_dir, cflags, ldflags, src, ldlibs));
      
      % check if this directory is on the search path
      path_dirs = regexp(path, pathsep, 'split');
      if ispc
        on_path = any(strcmpi(Jl.this_dir, path_dirs));
      else
        on_path = any(strcmp(Jl.this_dir, path_dirs));
      end
      
      % if not, add it and save
      fprintf('Is %s on the MATLAB path?\n', Jl.this_dir);
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

    function bf = boot_file()
      bf = Jl.forward_slashify(fullfile(Jl.this_dir, 'jl', 'boot.jl'));
    end
    
    function val = get_jlconfig(key)
      try
        load('jlconfig', key);
        val = eval(key);
      catch
        error('It appears the jlconfig.mat file is missing. Consider running "Jl.config".\n');
      end
    end
    
    function exe = julia_bin()
      exe = Jl.get_jlconfig('exe');
    end
    
    function home = julia_home()
      home = fileparts(Jl.julia_bin);
    end
    
    function img = julia_sys_image()
      img = Jl.get_jlconfig('img');
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
