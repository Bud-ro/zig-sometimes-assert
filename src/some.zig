const std = @import("std");
const config = @import("config");

/// This must be initialized by the test runner
pub var sometimes_info: std.array_hash_map.AutoArrayHashMap(*const std.builtin.SourceLocation, bool) = undefined;

pub fn assert_sometimes(src: *const std.builtin.SourceLocation, ok: bool) void {
    if (comptime config.enable_sometimes) {
        std.debug.print("Source info: {s}:{}:{}\n", .{ src.file, src.line, src.column });
        if (sometimes_info.get(src)) |v| {
            if (v == false and ok) {
                sometimes_info.put(src, ok) catch @panic("Allocation failed");
            }
        } else {
            sometimes_info.put(src, ok) catch @panic("Allocation failed");
        }
    }
}
