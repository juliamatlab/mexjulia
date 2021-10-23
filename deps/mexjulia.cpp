#include <julia.h>
#include <mex.h>

#ifdef _OS_LINUX_
#include <dlfcn.h>
#endif

// Return a boolean indicating whether Julia has been initialized.
bool check_init()
{
  return jl_is_initialized() != 0;
}

// Run Julia finalizers.
void jl_atexit_hook_0()
{
  jl_atexit_hook(0);
}

// Julia Mex Function.
//
// As described in the MATLAB documentation, the following function signature is used:
// - nlhs: Number of output (left-side) arguments, or the size of the plhs array.
// - plhs: Array of output arguments.
// - nrhs: Number of input (right-side) arguments, or the size of the prhs array.
// - prhs: Array of input arguments.
//
// If no input arguments are provided, this function returns a flag indicating whether 
// Julia is initialized.
// 
// If the first input argument is logical `false`, this function initializes Julia.
//
// If the first input argument is logical `true`, this function evaluates Julia code and 
// returns nothing.  This is useful for initializing packages.
//
// Otherwise, this function calls a function with a name corresponding to the first input
// argument to this function and input arguments corresponding to the remaining input 
// arguments to this function
void mexFunction(int nlhs, mxArray* plhs[], int nrhs, const mxArray* prhs[])
{
  if (nrhs == 0) // return flag indicating whether Julia is initialized
  {
    plhs[0] = mxCreateLogicalScalar(check_init());
  }
  else if (mxIsChar(prhs[0])) // call a Mex-like Julia function
  {
    // extract function and arguments
    char *fnName = mxArrayToString(prhs[0]);
    jl_function_t *fn = jl_get_function(jl_main_module, fnName);
    mxFree(fnName);
    if(!fn)
    {
      mexErrMsgTxt("Function not found.");
    }
    jl_value_t **args;
    JL_GC_PUSHARGS(args, 3);
    args[0] = jl_apply_array_type(reinterpret_cast<jl_value_t *>(jl_voidpointer_type), 1);
    args[1] = (jl_value_t *)jl_ptr_to_array_1d(args[0], plhs, nlhs > 1 ? nlhs : 1, 0);
    args[2] = (jl_value_t *)jl_ptr_to_array_1d(args[0], prhs + 1, nrhs - 1, 0);
    jl_call2(fn, args[1], args[2]);
    JL_GC_POP();
  }
  else if (mxIsLogicalScalar(prhs[0]))
  {
    if (mxIsLogicalScalarTrue(prhs[0])) // evaluate the provided string
    {
      if (mxIsChar(prhs[1]))
      {
        char *expr = mxArrayToString(prhs[1]);
        jl_eval_string(expr);
        mxFree(expr);
      }
    }
    else // initialize Julia
    {
      if (!check_init())
      {
        char *home =  nrhs > 1 && mxIsChar(prhs[1]) ? mxArrayToString(prhs[1]) : NULL;
        char *image = nrhs > 2 && mxIsChar(prhs[2]) ? mxArrayToString(prhs[2]) : NULL;
        char *lib =   nrhs > 3 && mxIsChar(prhs[3]) ? mxArrayToString(prhs[3]) : NULL;
        jl_options.handle_signals = JL_OPTIONS_HANDLE_SIGNALS_OFF;
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



  // check for unhandled julia exception
  jl_value_t *e = jl_exception_occurred();
  if (e)
  {
    const size_t len = 1024;
    static char msg[len];
    snprintf(msg, len, "Unhandled Julia exception: %s", jl_typeof_str(e));
    jl_exception_clear();
    mexErrMsgTxt(msg);
  }
}
