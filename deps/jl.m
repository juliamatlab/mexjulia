classdef jl
    %JL static class encapsulating matlab-side functionality for mexjulia

    methods (Static)
        % Call a MEX-like Julia function.
        %
        % nout - the number of expected return values
        % fn - the name of the function to call
        %
        % A MEX-like function is one that can be invoked with a value of type
        % `Vector{MxArray}` and returns a collection of values for which a
        % conversion to `MxArray` exists.
        function varargout = mexn(nout, fn, varargin)
            % check if julia is initialized
            jl.check_initialized;

            % call julia function
            outputs = cell(nout+1, 1);
            [outputs{:}] = mexjulia('jl_mex', fn, varargin{:});

            % throw error if error occured
            if ~islogical(outputs{1})
                throw(outputs{1});
            end

            % assign outputs
            varargout = outputs(2:end);
        end

        % Like mexn but assumes exactly one output
        function val = mex(fn, varargin)
            val = jl.mexn(1, fn, varargin{:});
        end

        % Interpret string(s) as Julia expression(s), returning value(s).
        function varargout = eval(varargin)
            varargout = cell(nargin, 1);
            [varargout{:}] = jl.mexn(nargin, 'Mex.jl_eval', varargin{:});
        end

        % Call a Julia function, possibly with keyword arguments, returning its
        % value.
        %
        % fn - the name of the function to call
        % npos - the number of arguments to be treated as positional
        %
        % Arguments beyond the first npos are assumed to come in key/value
        % pairs.
        %
        % If npos < 0 all arguments are assumed to be positional.
        function v = callkw(fn, npos, varargin)
            if npos >= 0
                nkw = length(varargin) - npos;
                if nkw < 0
                    error('The number of positional arguments exceeds the total number of arguments.');
                elseif mod(nkw,2) ~= 0
                    error('The number of keyword arguments is %u, but must be even.', nkw);
                end
            end
            v = jl.mex('Mex.jl_call_kw', fn, int32(npos), varargin{:});
        end

        % Call a Julia function with the given (positional) arguments, returning its value.
        %
        % fn - the name of the function to call
        function v = call(fn, varargin)
            v = jl.callkw(fn, -1, varargin{:});
        end

        % Wrap a Julia function in a matlab function handle.
        %
        % fn - the name of the function to wrap
        % npos - if provided, the number of arguments to be treated as
        % positional
        function hdl = wrap(fn, npos)
            if nargin < 2
                npos = -1;
            end
            hdl = @(varargin) jl.callkw(fn, npos, varargin{:});
        end

        % Wrap a MEX-like Julia function in a matlab function handle.
        %
        % fn - the name of the function to wrap
        % nout - if provided, the number of output values to expect (default=1)
        function hdl = wrapmex(fn, nout)
            if nargin < 2
                nout = 1;
            end
            hdl = @(varargin) jl.mexn(nout, fn, varargin{:});
        end

        % Include a file in the Julia runtime
        function include(fn)
            jl.eval(sprintf('Base.include(Main, "%s"); nothing', jl.forward_slashify(fn)));
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
                if endsWith(expr,';');
                    jl.eval(expr);
                else
                    jl.eval(expr)
                end
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
                    error('It appears the mexjulia MEX function is missing. Consider building "Mex.jl".\n');
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
                jldict = load('jldict', 'julia_home', 'sys_image', 'lib_path');

                mexjulia('', jldict.julia_home, jldict.sys_image, jldict.lib_path);

                % Make sure MATLAB_HOME points to _this_ version of matlab.
                setenv('MATLAB_HOME', jl.matlab_dir);

                % load Mex.jl
                mexjulia(0, ['Base.load_julia_startup(); using Mex;']);

                % restore the path
                if ispc
                    cd(old_dir);
                end
            end
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

    end

end
