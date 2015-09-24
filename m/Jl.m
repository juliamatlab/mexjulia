classdef Jl

  properties (Constant)
    
    % using the debug version?
    debug = false;
    
    % the mex function handle
    call = Jl.get_handle();

    % julia paths
    SUFFIX = Jl.get_suffix();
    JULIA_TOP = 'C:/tw/Julia-0.5.0-dev';
    JULIA_LIB = [Jl.JULIA_TOP '/lib'];
    JULIA_BIN = [Jl.JULIA_TOP '/bin'];
    JULIA_EXE = [Jl.JULIA_BIN '/julia' Jl.SUFFIX '.exe'];
    JULIA_IMG = [Jl.JULIA_LIB '/julia/sys' Jl.SUFFIX '.dll'];

    % boot file
    BOOT_FILE_PATH = Jl.get_boot_file_path();
    
    % trick to force initialization
    booted = Jl.boot;    
  end
  
  methods (Static)
    
    function info()
      Jl.call();
    end
    
    function [v1, v2, v3, v4, v5] = eval(e1, e2, e3, e4, e5)
      switch nargin
        case 1
          v1 = Jl.call('mexeval', e1);
        case 2
          [v1, v2] = Jl.call('mexeval', e1, e2);
        case 3
          [v1, v2, v3] = Jl.call('mexeval', e1, e2, e3);
        case 4
          [v1, v2, v3, v4] = Jl.call('mexeval', e1, e2, e3, e4);
        case 5
          [v1, v2, v3, v4, v5] = Jl.call('mexeval', e1, e2, e3, e4, e5);
      end
    end
    
    function include(fn)
      Jl.eval(['include("' fn '")']);
    end
      
    function reboot()
      Jl.raw_include(Jl.BOOT_FILE_PATH);
    end
  end
  
  methods (Static, Access=private)
    
    function hdl = get_handle()
      if Jl.debug
        hdl = @jl_calld;
      else
        hdl = @jl_call;
      end
    end
    
    function sfx = get_suffix()
      if Jl.debug
        sfx = '-debug';
      else
        sfx = '';
      end
    end

    function bf = get_boot_file_path()
      bits = strsplit(mfilename('fullpath'), filesep);
      bf = strjoin([bits(1:end-1), 'mexboot.jl'], '/');
    end
    
    function raw_eval(expr)
      Jl.call(0, expr)
    end
    
    function raw_include(fn)
      Jl.raw_eval(['include("' fn '")']);
    end
    
    function bl = boot()
      % add julia bin directory to exe path
      setenv('PATH', [getenv('PATH') pathsep Jl.JULIA_BIN]);
      
      % initialize the runtime
      Jl.call('', Jl.JULIA_LIB, Jl.JULIA_EXE, Jl.JULIA_IMG);
      
      % load the boot file
      Jl.raw_include(Jl.BOOT_FILE_PATH);
      
      bl = true;
    end
  end
end
