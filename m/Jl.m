classdef Jl

  properties (Constant)
    call = Jl.init__(@jl_calld);
    booted = Jl.boot__();
  end
  
  methods (Static)
    function v = eval(expr)
      v = Jl.call('mexeval', expr);
    end
    
    function raw_eval(expr)
      Jl.call(0, expr)
    end
    
    function raw_include(fn)
      Jl.raw_eval(['include("' fn '")']);
    end
    
    function raw_include_boot()
      bits = strsplit(mfilename('fullpath'), filesep);
      boot_file = strjoin([bits(1:end-1), 'mexboot.jl'], '/');
      Jl.raw_include(boot_file);
    end
  end
  
  methods (Static, Access=private)
    
    function bl = boot__()
      Jl.raw_include_boot();
      bl = true;
    end
    
    function hdl = init__(hdl)
      % for some reason, initialization must occur with pwd being the julia
      % bin directory
      
      % get mex function directory
      s = functions(hdl);
      bits = strsplit(s.file, filesep);
      d = strjoin(bits(1:end-1), filesep);
      
      curdir = pwd();
      cd(d);
      
      % initialize
      hdl();
      
      cd(curdir);
    end
  end
end