#include <mex.h>
#include <julia.h>

void jl_check(void *result) {
  const size_t len = 1024;
  static char msg[len];

  if(result != NULL) return;

  jl_value_t *e = jl_exception_occurred();
  if(e) {
    snprintf(msg, len, "Unhandled Julia exception: %s", jl_typeof_str(e));
    jlbacktrace();
    jl_exception_clear();
    mexErrMsgTxt(msg);
  }
}

void jl_atexit_hook_0() {
  jl_atexit_hook(0);
}

void mexFunction(int nl, mxArray* pl[], int nr, const mxArray* pr[]) {

  if (nr == 0) { // initalization check

    pl[0] = mxCreateLogicalScalar(jl_is_initialized());

  } else if (mxIsChar(pr[0])) { // call a function with this name...

    if(mxGetDimensions(pr[0])[0] != 0) { // ...if the name isn't empty...

      char *fnName = mxArrayToString(pr[0]);
      jl_function_t *fn = jl_get_function(jl_main_module, fnName);
      mxFree(fnName);
      if(!fn) mexErrMsgTxt("Function not found.");

      jl_value_t *args[4];
      args[0] = jl_box_int32(nl);
      args[1] = jl_box_voidpointer(pl);
      args[2] = jl_box_int32(nr-1);
      args[3] = jl_box_voidpointer(pr+1);
      jl_check(jl_call(fn, args, 4));

    } else{ // ...because the empty name means initialization

      if (!jl_is_initialized()) {

        char *home = nr >= 2 && mxIsChar(pr[1]) ? mxArrayToString(pr[1]) : NULL;
        char *image = nr >= 3 && mxIsChar(pr[2]) ? mxArrayToString(pr[2]) : NULL;
        jl_init_with_image(home, image);
        mxFree(home);
        mxFree(image);

        mexAtExit(jl_atexit_hook_0);
      }

    }
  } else { // evaluate remaining string arguments

    for (int i = 1; i < nr; ++i) {
      if (!mxIsChar(pr[i])) continue;
      char *expr = mxArrayToString(pr[i]);
      void *r = jl_eval_string(expr);
      mxFree(expr);
      jl_check(r);
    }

  }
}
