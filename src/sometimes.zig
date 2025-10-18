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
