#include <mex.h>
#include <julia.h>
#include <vector>

#define STR(s) #s
#define XSTR(s) STR(s)

void jl_check(const char *msg) {
  jl_value_t *e = jl_exception_occurred();
  if(e) {
    std::vector<char> buf_ptr(64 * 1024);
    snprintf(&(buf_ptr[0]), buf_ptr.size(),
             "A julia exception of type %s occurred: %s",
             jl_typeof_str(e), msg);
    jl_exception_clear();
    mexErrMsgTxt(&(buf_ptr[0]));
  }
}

bool g_init = false;

void jl_finalize() {
  jl_atexit_hook(0);
}

void mexFunction(int nlhs, mxArray* plhs[], int nrhs, const mxArray* prhs[]) {
  if (nrhs == 0) { // initilize, if necessary

    if (!g_init) {

      jl_init(XSTR(JULIA_INIT_DIR));
      jl_check("call to 'jl_init' failed");
      mexAtExit(jl_finalize);

      g_init = true;
    }

  } else if (mxIsChar(prhs[0])) { // call a function with this name

    // get the function
    char *fnName = mxArrayToString(prhs[0]);
    jl_function_t *fn = jl_get_function(jl_main_module, fnName);
    mxFree(fnName);
    jl_check("call to 'jl_get_function' failed");
    if(fn == NULL) mexErrMsgTxt("call to 'jl_get_function' returned NULL");

    jl_value_t *args[4];
    args[0] = jl_box_int32(nlhs);
    args[1] = jl_box_voidpointer(plhs);
    args[2] = jl_box_int32(nrhs-1);
    args[3] = jl_box_voidpointer(prhs+1);
    jl_call(fn, args, 4);
    jl_check("call to 'jl_call' failed");

  } else { // evaluate the remaining arguments as strings

    for(int i = 1; i < nrhs; ++i) {
      char *expr = mxArrayToString(prhs[i]);
      jl_eval_string(expr);
      mxFree(expr);
      jl_check("call to 'jl_eval_string' failed");
    }
  }
}
