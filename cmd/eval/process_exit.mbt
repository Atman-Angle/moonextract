///|
#cfg(any(target="native", target="llvm"))
extern "c" fn exit_process(code : Int32) = "exit"
