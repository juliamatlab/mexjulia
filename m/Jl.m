classdef Jl

  properties (Constant)
    config_file = Jl.get_config_file;
    boot_file = Jl.get_boot_file;
    julia_bin_dir = Jl.get_julia_bin_dir;
    julia_home = Jl.get_julia_home;
    julia_image = Jl.get_julia_image;
    mex = Jl.get_mex_handle;
  end

  methods (Static)

    function bl = check_init()
      bl = Jl.mex();
    end

    function [v1, v2, v3, v4, v5] = eval(e1, e2, e3, e4, e5)
      switch nargin
        case 1
          v1 = Jl.mex('mex_eval', e1);
        case 2
          [v1, v2] = Jl.mex('mex_eval', e1, e2);
        case 3
          [v1, v2, v3] = Jl.mex('mex_eval', e1, e2, e3);
        case 4
          [v1, v2, v3, v4] = Jl.mex('mex_eval', e1, e2, e3, e4);
        case 5
          [v1, v2, v3, v4, v5] = Jl.mex('mex_eval', e1, e2, e3, e4, e5);
      end
    end

    function p = forward_slashify(p)
      p = strjoin(strsplit(p, filesep), '/');
    end

    function eval_string(expr)
      Jl.mex(0, expr);
    end

    function include(fn)
      Jl.eval_string(['include("' Jl.forward_slashify(fn) '")']);
    end

    function v = call(fn, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
      switch nargin
        case 1
          v = Jl.mex('mex_call', fn);
        case 2
          v = Jl.mex('mex_call', fn, a1);
        case 3
          v = Jl.mex('mex_call', fn, a1, a2);
        case 4
          v = Jl.mex('mex_call', fn, a1, a2, a3);
        case 5
          v = Jl.mex('mex_call', fn, a1, a2, a3, a4);
        case 6
          v = Jl.mex('mex_call', fn, a1, a2, a3, a4, a5);
        case 7
          v = Jl.mex('mex_call', fn, a1, a2, a3, a4, a5, a6);
        case 8
          v = Jl.mex('mex_call', fn, a1, a2, a3, a4, a5, a6, a7);
        case 9
          v = Jl.mex('mex_call', fn, a1, a2, a3, a4, a5, a6, a7, a8);
        case 10
          v = Jl.mex('mex_call', fn, a1, a2, a3, a4, a5, a6, a7, a8, a9);
        case 11
          v = Jl.mex('mex_call', fn, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10);
      end
    end
  end

  methods (Static, Access=private)

    function hdl = get_mex_handle()
      % run jlbuild if the mex function doesn't exist
      if isempty(which('jlcall'))
        warning('''jlcall'' not found. Attempting to build...');
        jlbuild;
      end

      hdl = @jlcall;

      % *** runtime initialization ***

      % add julia bin directory to exe path
      setenv('PATH', [getenv('PATH') pathsep Jl.julia_bin_dir]);

      % initialize the Julia runtime
      jlcall('', Jl.julia_home, Jl.julia_image);

      % load the boot file
      jlcall(0, ['include("' Jl.forward_slashify(Jl.boot_file) '")']);
    end

    function conf = get_config_file()
      bits = strsplit(mfilename('fullpath'), filesep);
      conf = strjoin([bits(1:end-1), 'jlconfig.mat'], filesep);

      % run jlconfig if the file doesn't exist
      if exist(conf, 'file') ~= 2
        warning([conf ' not found. Attempting to reconfigure...']);
        jlconfig;
      end
    end

    function boot = get_boot_file()
      bits = strsplit(mfilename('fullpath'), filesep);
      boot = strjoin([bits(1:end-2), 'jl', 'boot.jl'], filesep);
    end

    function v = read_config(nm)
      conf = matfile(Jl.config_file);
      v = conf.(nm);
    end

    function d = get_julia_bin_dir()
      d = Jl.read_config('julia_bin_dir');
    end

    function h = get_julia_home()
      h = Jl.read_config('julia_home');
    end

    function i = get_julia_image()
      i = Jl.read_config('julia_image');
    end
  end
end
