#include <julia.h>
#include <mex.h>

#ifdef _OS_LINUX_
#include <dlfcn.h>
#endif

void jl_atexit_hook_0()
{
    jl_atexit_hook(0);
}

bool check_init()
{
    try
    {
        return jl_is_initialized() != 0;
    }
    catch (...)
    {
        return false;
    }
}

void mexFunction(int nl, mxArray* pl[], int nr, const mxArray* pr[])
{
    if (nr == 0) // initalization check
    {
        pl[0] = mxCreateLogicalScalar(check_init());
    }
    else if (mxIsChar(pr[0])) // call a function with this name...
    {
        if(mxGetDimensions(pr[0])[0] != 0) // ...if the name isn't empty...
        {
            char *fnName = mxArrayToString(pr[0]);
            jl_function_t *fn = jl_get_function(jl_main_module, fnName);
            mxFree(fnName);
            if(!fn)
            {
                mexErrMsgTxt("Function not found.");
            }

            jl_value_t **args;
            JL_GC_PUSHARGS(args, 4);
            args[0] = (jl_value_t *)fn;
            args[1] = jl_apply_array_type(reinterpret_cast<jl_value_t *>(jl_voidpointer_type), 1);
            args[2] = (jl_value_t *)jl_ptr_to_array_1d(args[1], pl, nl > 1 ? nl : 1, 0);
            args[3] = (jl_value_t *)jl_ptr_to_array_1d(args[1], pr + 1, nr - 1, 0);
            jl_call2(fn, args[2], args[3]);
            JL_GC_POP();
        }
        else // ...because the empty name means initialization
        {
            if (!check_init())
            {
                char *home = nr >= 2 && mxIsChar(pr[1]) ? mxArrayToString(pr[1]) : NULL;
                char *image = nr >= 3 && mxIsChar(pr[2]) ? mxArrayToString(pr[2]) : NULL;
                char *lib = nr >= 4 && mxIsChar(pr[3]) ? mxArrayToString(pr[3]) : NULL;

#ifdef _OS_LINUX_
                if (!dlopen(lib, RTLD_LAZY | RTLD_GLOBAL))
                {
                    mexErrMsgTxt(dlerror());
                }
#endif

                jl_init_with_image(home, image);
                mxFree(home);
                mxFree(image);
                mexAtExit(jl_atexit_hook_0);
            }
        }
    }
    else // evaluate the first remaining argument as a julia expression
    {
        if (mxIsChar(pr[1]))
        {
            char *expr = mxArrayToString(pr[1]);
            jl_eval_string(expr);
            mxFree(expr);
        }
    }

    // check for unhandled julia exception
    jl_value_t *e = jl_exception_occurred();
    if(e)
    {
        const size_t len = 1024;
        static char msg[len];
        snprintf(msg, len, "Unhandled Julia exception: %s", jl_typeof_str(e));
        jl_exception_clear();
        mexErrMsgTxt(msg);
    }
}
