#include <mex.h>
#include <julia.h>

void jl_check(bool bl) {
  const size_t len = 1024;
  static char msg[len];

  if (!bl)
  {
      jl_value_t *e = jl_exception_occurred();
      if(e)
      {
          snprintf(msg, len, "Unhandled Julia exception: %s", jl_typeof_str(e));
          mexErrMsgTxt(msg);
      }
  }
  jl_exception_clear();
}

void jl_atexit_hook_0() {
  jl_atexit_hook(0);
}

void mexFunction(int nl, mxArray* pl[], int nr, const mxArray* pr[]) {

  if (nr == 0) { // initalization check

    pl[0] = mxCreateLogicalScalar(jl_is_initialized() != 0);

  } else if (mxIsChar(pr[0])) { // call a function with this name...

    if(mxGetDimensions(pr[0])[0] != 0) { // ...if the name isn't empty...

      jl_value_t **args;
      JL_GC_PUSHARGS(args, 4);

      char *fnName = mxArrayToString(pr[0]);
      jl_function_t *fn = jl_get_function(jl_main_module, fnName);
      mxFree(fnName);
      if(!fn) {
        JL_GC_POP();
        mexErrMsgTxt("Function not found.");
      }

      args[0] = (jl_value_t *)fn;
      args[1] = jl_apply_array_type(jl_voidpointer_type, 1);
      args[2] = (jl_value_t *)jl_ptr_to_array_1d(args[1], pl, nl > 1 ? nl : 1, 0);
      args[3] = (jl_value_t *)jl_ptr_to_array_1d(args[1], pr + 1, nr - 1, 0);
      bool bl = jl_call2(fn, args[2], args[3]) != NULL;

      JL_GC_POP();
      jl_check(bl);

    } else{ // ...because the empty name means initialization

      if (!jl_is_initialized()) {
        jl_options.handle_signals = JL_OPTIONS_HANDLE_SIGNALS_OFF;
        jl_init(JULIA_INIT_DIR);
        mexAtExit(jl_atexit_hook_0);
      }

    }
  } else { // evaluate remaining string arguments

    bool bl = true;
    for (int i = 1; i < nr; ++i) {
      if (!mxIsChar(pr[i])) continue;
      char *expr = mxArrayToString(pr[i]);
      bl &= jl_eval_string(expr) != NULL;
      mxFree(expr);
    }
    jl_check(bl);
  }
}
