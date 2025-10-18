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
        if (info.get(src)) |v| {
            switch (v) {
                .always_false => {
                    if (ok) {
                        info.put(src, .mixed) catch @panic("Out of memory");
                    }
                },
                .always_true => {
                    if (!ok) {
                        info.put(src, .mixed) catch @panic("Out of memory");
                    }
                },
                .mixed => {},
            }
        } else {
            if (ok) {
                info.put(src, .always_true) catch @panic("Out of memory");
            } else {
                info.put(src, .always_false) catch @panic("Out of memory");
            }
        }
    }
}

const std = @import("std");
const config = @import("config");
