///|
#cfg(any(target="native", target="llvm"))
extern "c" fn exit_process(code : Int32) = "exit"

///|
#cfg(target="wasm")
fn exit_process(code : Int32) -> Unit = "wasi_snapshot_preview1" "proc_exit"

///|
#cfg(target="wasm-gc")
fn exit_process(code : Int32) -> Unit = "__moonbit_sys_unstable" "exit"

///|
#cfg(target="js")
extern "js" fn exit_process_js(code : Int32) -> Bool =
  #| function(code) {
  #|   if (typeof process !== "undefined" && typeof process.exit === "function") {
  #|     process.exit(code);
  #|     return true;
  #|   }
  #|   return false;
  #| }

///|
#cfg(target="js")
fn exit_process(code : Int32) -> Unit {
  if !exit_process_js(code) {
    abort("process exit is unavailable")
  }
}
