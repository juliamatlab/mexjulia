classdef jl
  %JL static class encapsulating matlab-side functionality for mexjulia
  
  methods (Static)
    % call a MEX-like Julia function
    function varargout = mex(nout, varargin)
        varargout = cell(nout, 1);
        jl.check_initialized;
        [varargout{:}] = mexjulia('jl_mex', varargin{:});   
    end

    % interpret string(s) as Julia expression(s), returning value(s)
    function varargout = eval(varargin)
        varargout = cell(nargin, 1);
        [varargout{:}] = jl.mex(nargin, 'Mex.jl_eval', varargin{:});
    end

    % call a julia function (specified by its name as a string) with
    % the given arguments, returning its value
    function v = call(varargin)
      v = jl.mex(1, 'Mex.jl_call', varargin{:});
    end

    % include a file in the Julia runtime
    function include(fn)
      jl.eval(['include("' jl.forward_slashify(fn) '")']);
    end
    
    function repl(prompt, doneq)
      
      if nargin < 2
        doneq = @(expr)startsWith(expr,';');
        if nargin < 1
          prompt = 'julia> ';
        end
      end
      
      while true
        expr = input(prompt, 's');
        if doneq(expr), break, end
        jl.eval(expr)  
      end
    end
    
    function bl = is_initialized()
      try
        bl = mexjulia;
      catch
        bl = false;
      end
    end
    
    % Check that the Julia runtime is initialized (and initialize it, if
    % necessary).
    function check_initialized()
      if ~jl.is_initialized
        
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
          cd(jl.julia_home);
        end
     
        % basic runtime initialization
        mexjulia('', jl.julia_home, jl.sys_image);

        % Make sure MATLAB_HOME points to _this_ version of matlab.
        setenv('MATLAB_HOME', jl.matlab_dir);

        % load the boot file
        mexjulia(0, ['include("' jl.boot_file '")']);
      
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
        if ~exist(exe, 'file')
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
      jl.set('julia_bin', exe);
      
      % get JULIA_HOME
      cmd = 'println(unsafe_string(Base.JLOptions().julia_home))';
      [~, jlhome] = system(sprintf('"%s" -e "%s"', exe, cmd));
      jlhome = jl.chomp(jlhome);
      assert(exist(jlhome, 'dir') == 7);
      jl.set('julia_home', jlhome);
      
      % get the path of the image file
      cmd = 'println(unsafe_string(Base.JLOptions().image_file))';
      [~, img] = system(sprintf('"%s" -e "%s"', exe, cmd));
      img = jl.chomp(img);
      assert(exist(img, 'file') == 2);
      jl.set('sys_image', img);
      
      % check for debugging
      cmd = 'println(Base.JLOptions().debug_level > 1)';
      [~, dbg] = system(sprintf('"%s" -e "%s"', exe, cmd));
      dbg = jl.chomp(dbg);
      jl.set('is_debug', dbg);
      
      % check if threading is enabled
      cmd = 'println(ccall(:jl_threading_enabled, Cint, ()) != 0)';
      [~, thr] = system(sprintf('"%s" -e "%s"', exe, cmd));
      thr = jl.chomp(thr);
      jl.set('threading_enabled', thr);
      
      % get include directory
      incdir = fullfile(fileparts(jlhome), 'include', 'julia');
      assert(exist(incdir, 'dir') == 7);
      jl.set('inc_dir', incdir);
      
      % get lib directory
      libdir = fullfile(fileparts(jlhome), 'lib');
      assert(exist(libdir, 'dir') == 7);
      jl.set('lib_dir', libdir);
      
      % get julia lib
      if eval(dbg)
        lib_base = 'libjulia-debug';
      else
        lib_base = 'libjulia';
      end
      jl.set('lib_base', lib_base);
      
      % set cflags
      if eval(dbg)
        cflags = '-g';
      else
        cflags = '-O';
      end
      cflags = [cflags ' -I' '"' jl.get('inc_dir') '"'];
      if eval(jl.get('threading_enabled'))
        cflags = [cflags ' -DJULIA_ENABLE_THREADING'];
      end
      jl.set('build_cflags', cflags);
      
      % set ldflags
      ldflags = ['-L' '"' jl.get('lib_dir') '"'];
      jl.set('build_ldflags', ldflags);
      
      % set ldlibs
      ldlibs = [ jl.get('lib_base') '.dll.a libopenlibm.dll.a' ];
      jl.set('build_ldlibs', ldlibs);
      
      % set mex source file
      src = fullfile(jl.this_dir, 'mexjulia.cpp');
      jl.set('build_src', src);
      
      % show the contents of the dictionary
      jl.get;
      
      % check if this directory is on the search path
      path_dirs = regexp(path, pathsep, 'split');
      if ispc
        on_path = any(strcmpi(jl.this_dir, path_dirs));
      else
        on_path = any(strcmp(jl.this_dir, path_dirs));
      end
      
      % if not, add it and save
      if ~on_path
        fprintf('%s is not on the MATLAB path. Adding it and saving...\n', jl.this_dir);
        path(jl.this_dir, path);
        savepath;
      end

      % rebuild the mex function, given the new configuration
      jl.build;
    end
    
    function build()
      try
        cflags = jl.get('build_cflags');
        ldflags = jl.get('build_ldflags');
        src = jl.get('build_src');
        ldlibs = jl.get('build_ldlibs');
      catch
        error('Failed to get mex build parameters. Run ''jl.config''.');
      end
        
      try
        mex_ptrn = 'mex -largeArrayDims -outdir "%s" %s %s %s %s';
        mex_cmd = sprintf(mex_ptrn, jl.this_dir, cflags, ldflags, src, ldlibs);
        fprintf('The mex command to be executed:\n%s\n', mex_cmd);
        eval(mex_cmd);
      catch
        jl.get;
        msg = ['Mex build failed.\n', ...
          'Consider editing the ''build_*'' fields in the mexjulia',...
          ' dictionary', ...
          ' using the ''jl.set'' command.\nRun ''jl.get'' to see the',...
          ' current',...
          ' contents of the mexjulia dictionary.'];
        error(sprintf(msg));
      end
    end
    
    function clear()
      save jldict;
    end
      
    function check_dict()
      if exist('jldict.mat', 'file') ~= 2
        jl.clear;
      end
    end
    
    function value = get(key)
      jl.check_dict;
      
      if nargin > 0
        load('jldict', key);
        try
          value = eval(key);
        catch
          value = '';
        end
      else
        value = struct;
        keys = who(matfile('jldict'));
        nkeys = length(keys);
        for k = 1:nkeys
          value.(keys{k}) = jl.get(keys{k});
        end
      end
    end
    
    function set(key__, value__)
      jl.check_dict;
      if ~ischar(key__)
        error('The key must be a string.');
      end
      
      if nargin < 2
        load jldict;
        eval(sprintf('clear %s', key__));
        clear key__ value__
        save jldict;
      else
        if ~ischar(value__)
          error('The value must be a string.');
        end
        eval(sprintf('%s=''%s'';', key__, value__));
        eval(sprintf('save -append jldict %s', key__));
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
      bf = jl.forward_slashify(fullfile(jl.this_dir, 'jl', 'boot.jl'));
    end
       
    function home = julia_home()
      home = jl.get('julia_home');
    end
    
    function img = sys_image()
      img = jl.get('sys_image');
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

