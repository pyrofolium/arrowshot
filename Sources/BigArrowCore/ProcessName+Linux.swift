#if os(Linux)
import Glibc

/// Darwin's libproc `proc_name` for Linux: copies a process's short name from /proc into
/// `buffer` (NUL-terminated) and returns its length, 0 when the process is gone.
func proc_name(_ pid: Int32, _ buffer: UnsafeMutableRawPointer, _ size: UInt32) -> Int32 {
    guard size > 0, let file = fopen("/proc/\(pid)/comm", "r") else { return 0 }
    defer { fclose(file) }
    let bytes = buffer.assumingMemoryBound(to: CChar.self)
    guard fgets(bytes, Int32(size), file) != nil else { return 0 }
    var length = strlen(bytes)
    if length > 0, bytes[length - 1] == 10 {
        length -= 1
        bytes[length] = 0
    }
    return Int32(length)
}
#endif
