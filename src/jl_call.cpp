#include <mex.h>
#include <julia.h>
#include <vector>

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

const size_t BUF_LEN = 1024;
char g_julia_home[BUF_LEN];
char g_julia_bin[BUF_LEN];
char g_julia_image[BUF_LEN];

void jl_finalize() {
  jl_atexit_hook(0);
}

void mexFunction(int nl, mxArray* pl[], int nr, const mxArray* pr[]) {

  if (nr == 0) { // maybe dump some info, eventually

  } else if (mxIsChar(pr[0])) { // call a function with this name

    if(mxGetDimensions(pr[0])[0] == 0) { // empty string means initialization

      if (jl_is_initialized()) return;

      if(nr < 4 || !mxIsChar(pr[1]) || !mxIsChar(pr[2]) || !mxIsChar(pr[3]))
        mexErrMsgTxt(
          "Initialization requires 3 arguments:\n"
          "\t1. The Julia lib directory;\n"
          "\t2. The path to the Julia executable;\n"
          "\t3. The path of the system image.");

      mxGetString(pr[1], g_julia_home, BUF_LEN);
      mxGetString(pr[2], g_julia_bin, BUF_LEN);
      mxGetString(pr[3], g_julia_image, BUF_LEN);

      libsupport_init();

      jl_options.julia_home = g_julia_home;
      jl_options.julia_bin = g_julia_bin;
      jl_options.image_file = g_julia_image;

      julia_init(JL_IMAGE_JULIA_HOME);
      jl_check("call to 'jl_init' failed");

      mexAtExit(jl_finalize);

      return;
    }

    // get the function
    char *fnName = mxArrayToString(pr[0]);
    jl_function_t *fn = jl_get_function(jl_main_module, fnName);
    mxFree(fnName);
    jl_check("call to 'jl_get_function' failed");
    if (fn == NULL) mexErrMsgTxt("call to 'jl_get_function' returned NULL");

    jl_value_t *args[4];
    args[0] = jl_box_int32(nl);
    args[1] = jl_box_voidpointer(pl);
    args[2] = jl_box_int32(nr-1);
    args[3] = jl_box_voidpointer(pr+1);
    jl_call(fn, args, 4);
    jl_exception_clear();

  } else { // evaluate the remaining arguments as strings

    for (int i = 1; i < nr; ++i) {
      char *expr = mxArrayToString(pr[i]);
      jl_eval_string(expr);
      mxFree(expr);
      jl_check("call to 'jl_eval_string' failed");
    }
  }
}
