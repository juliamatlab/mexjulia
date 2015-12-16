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

    function varargout = eval(varargin)
        varargout = cell(1, length(varargin));
        [varargout{:}] = Jl.mex('mex_eval', varargin{:});
    end

    function p = forward_slashify(p)
      p = regexp(p, filesep, 'split');
      p = [sprintf('%s/', p{1:end-1}) p{end}];
    end

    function eval_string(expr)
      Jl.mex(0, expr);
    end

    function include(fn)
      Jl.eval_string(['include("' Jl.forward_slashify(fn) '")']);
    end

    function v = call(fn, varargin)
      v = Jl.mex('mex_call', fn, varargin{:});
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
      mfiledir = fileparts(mfilename('fullpath'));
      conf = [mfiledir filesep 'jlconfig.mat'];

      % run jlconfig if the file doesn't exist
      if exist(conf, 'file') ~= 2
        warning([conf ' not found. Attempting to reconfigure...']);
        jlconfig;
      end
    end

    function boot = get_boot_file()
      mfiledir = fileparts(mfilename('fullpath'));
      boot = fullfile(mfiledir, '..', 'jl', 'boot.jl');
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
