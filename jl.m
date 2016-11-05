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

        % tweak path to find shared libs
        if ispc
          % This is a hack for windows which lets the mex function
          % find the julia dlls during initialization without requiring that
          % julia be on the path.
          old_dir = pwd;
          cd(jl.julia_home);
        end
     
        % basic runtime initialization
        mexjulia('', jl.julia_home, jl.sys_image);

        % Make sure MATLAB_HOME points to _this_ version of matlab.
        setenv('MATLAB_HOME', jl.matlab_dir);

        % load the boot file
        mexjulia(0, ['include("' jl.boot_file '")']);

        % restore the path
        if ispc
          cd(old_dir);
        end
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
      jlhome = jl.eval_with_exe('unsafe_string(Base.JLOptions().julia_home)');
      assert(exist(jlhome, 'dir') == 7);
      jl.set('julia_home', jlhome);
      
      % get the path of the image file
      img = jl.eval_with_exe('unsafe_string(Base.JLOptions().image_file)');
      assert(exist(img, 'file') == 2);
      jl.set('sys_image', img);
      
      % check for debugging
      dbg = jl.eval_with_exe('ccall(:jl_is_debugbuild, Cint, ()) != 0');
      jl.set('is_debug', dbg);
      
      % check if threading is enabled
      thr = jl.eval_with_exe('ccall(:jl_threading_enabled, Cint, ()) != 0');
      jl.set('threading_enabled', thr);
      
      % get include directory
      incdir = fullfile(fileparts(jlhome), 'include', 'julia');
      assert(exist(incdir, 'dir') == 7);
      jl.set('inc_dir', incdir);
            
      % get julia lib
      if eval(dbg)
        lib_base = 'julia-debug';
      else
        lib_base = 'julia';
      end
      lib_path = jl.eval_with_exe(sprintf('Libdl.dlpath(\\\"lib%s\\\")', lib_base));
      if ispc
        lib_dir = fullfile(jlhome, '..', 'lib');
      else
        lib_dir = fileparts(lib_path);
      end
      jl.set('lib_base', lib_base);
      jl.set('lib_path', lib_path);
      jl.set('lib_dir', lib_dir);
      
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
      ldflags = ['-L"' jl.get('lib_dir') '"'];
      if ~ispc
        ldflags = [ldflags ' -Wl,-rpath="' jl.get('lib_dir') '"'];
      end
      jl.set('build_ldflags', ldflags);
      
      % set ldlibs
      if ispc
        ldlibs = [ 'lib' jl.get('lib_base') '.dll.a' ];
      else
        ldlibs = [ '-l' jl.get('lib_base') ];
      end
      jl.set('build_ldlibs', ldlibs);
      
      % set mex source file
      src = fullfile(jl.this_dir, 'mexjulia.cpp');
      jl.set('build_src', src);
      
      % show the contents of the dictionary
      disp(jl.get);
      
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
      
      if ispc
        mex_ptrn = 'mex -v -largeArrayDims %s -outdir "%s" %s %s %s';
      else
        mex_ptrn = 'mex LDFLAGS=''%s $LDFLAGS'' -v -largeArrayDims -outdir "%s" %s %s %s';
      end
      mex_cmd = sprintf(mex_ptrn, ldflags, jl.this_dir, cflags, src, ldlibs);
      fprintf('The mex command to be executed:\n%s\n', mex_cmd);
      eval(mex_cmd);
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
    
    function [val, err] = eval_with_exe(expr)
      exe = jl.get('julia_bin');
      if ~ispc
          % hide the LD_LIBRARY_PATH as it can cause errors when running
          % julia from matlab
          save_ld_lib_path = getenv('LD_LIBRARY_PATH');
          setenv LD_LIBRARY_PATH;
      end
      [err, val] = system(sprintf('"%s" -e "println(%s)"', exe, expr));
      if ~ispc
          % restore the LD_LIBRARY_PATH
          setenv('LD_LIBRARY_PATH', save_ld_lib_path);
      end
      if err ~= 0
          error(val)
      end
      val = jl.chomp(val);
    end
    
  end
  
end

