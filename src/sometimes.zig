//! Declarations relevant to "Sometimes Assertions"
//! Inspired by https://antithesis.com/docs/best_practices/sometimes_assertions/

/// This must be initialized by the test runner
pub var info: std.hash_map.AutoHashMap(*const std.builtin.SourceLocation, SometimesType) = undefined;

const SometimesType = enum {
    always_false,
    always_true,
    mixed,
};

pub fn assert(
    src: *const std.builtin.SourceLocation,
    ok: bool,
) void {
    if (@inComptime()) {
        // It might be interesting to ensure that test builds exercise reachable sometimes assertions
        // at comptime as well.
        // This would look like `pub fn assert(src: *const std.builtin.SourceLocation, ok: bool, comptime check_comptime: sometimes_comptime)`
        // e.g. `sometimes.assert(&@src(), condition, .comptime_and_runtime);`
        //
        // However there are some big issues surrounding:
        // - incremental
        // - Compilation order
        // - Running code after all other code has been compiled, etc.
        // For that reason there are no current plans to support this use case.
        return;
    }

    if (comptime config.enable_sometimes) {
        const val = info.getOrPut(src) catch @panic("Out of memory");
        if (val.found_existing) {
            switch (val.value_ptr.*) {
                .always_false => {
                    if (ok) {
                        val.value_ptr.* = .mixed;
                    }
                },
                .always_true => {
                    if (!ok) {
                        val.value_ptr.* = .mixed;
                    }
                },
                .mixed => {},
            }
        } else {
            if (ok) {
                val.value_ptr.* = .always_true;
            } else {
                val.value_ptr.* = .always_false;
            }
        }
    }
}

const std = @import("std");
pub const config = @import("sometimes_config");
