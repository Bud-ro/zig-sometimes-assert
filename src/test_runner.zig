// Note that this was copied from https://gist.github.com/karlseguin/c6bea5b35e4e8d26af6f81c22cb5d76b
// And modified to suit my needs. MIT licensed: https://gist.github.com/karlseguin/c6bea5b35e4e8d26af6f81c22cb5d76b?permalink_comment_id=5423851#gistcomment-5423851
// Modifications are also provided under the MIT license

// in your build.zig, you can specify a custom test runner:
// const tests = b.addTest(.{
//    .root_module = $MODULE_BEING_TESTED,
//    .test_runner = .{ .path = b.path("test_runner.zig"), .mode = .simple },
// });

const std = @import("std");
const sometimes = @import("sometimes");
const sometimes_config = sometimes.config;
const builtin = @import("builtin");

const Allocator = std.mem.Allocator;

const BORDER = "=" ** 80;

// use in custom panic handler
var current_test: ?[]const u8 = null;

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const env = Env.init(init.environ_map);

    var slowest = SlowTracker.init(allocator, init.io, 5);
    defer slowest.deinit(allocator);

    var pass: usize = 0;
    var fail: usize = 0;
    var skip: usize = 0;
    var leak: usize = 0;

    sometimes.info = .init(allocator);
    defer sometimes.info.deinit();

    Printer.fmt("\r\x1b[0K", .{}); // beginning of line and clear to end of line

    for (builtin.test_functions) |t| {
        var status = Status.pass;
        slowest.startTiming();

        const is_unnamed_test = isUnnamed(t);
        if (env.filter) |f| {
            if (!is_unnamed_test and std.mem.indexOf(u8, t.name, f) == null) {
                continue;
            }
        }

        const friendly_name = blk: {
            const name = t.name;
            var it = std.mem.splitScalar(u8, name, '.');
            while (it.next()) |value| {
                if (std.mem.eql(u8, value, "test")) {
                    const rest = it.rest();
                    break :blk if (rest.len > 0) rest else name;
                }
            }
            break :blk name;
        };

        current_test = friendly_name;
        std.testing.allocator_instance = .{};
        const result = t.func();
        current_test = null;

        const ns_taken = slowest.endTiming(allocator, friendly_name);

        if (std.testing.allocator_instance.deinit() == .leak) {
            leak += 1;
            Printer.status(.fail, "\n{s}\n\"{s}\" - Memory Leak\n{s}\n", .{ BORDER, friendly_name, BORDER });
        }

        if (result) |_| {
            pass += 1;
        } else |err| switch (err) {
            error.SkipZigTest => {
                skip += 1;
                status = .skip;
            },
            else => {
                status = .fail;
                fail += 1;
                Printer.status(.fail, "\n{s}\n\"{s}\" - {s}\n{s}\n", .{ BORDER, friendly_name, @errorName(err), BORDER });
                if (@errorReturnTrace()) |trace| {
                    std.debug.dumpErrorReturnTrace(trace);
                }
            },
        }

        if (env.verbose) {
            const ms = @as(f64, @floatFromInt(ns_taken)) / 1_000_000.0;
            Printer.status(status, "{s} ({d:.2}ms)\n", .{ friendly_name, ms });
        } else {
            Printer.status(status, ".", .{});
        }
    }

    var failed_sometimes: usize = 0;
    if (sometimes_config.enable_sometimes) {
        var it = sometimes.info.iterator();
        while (it.next()) |c| {
            if (c.value_ptr.* != .mixed) {
                const ctx = c.key_ptr.*;
                if (c.value_ptr.* == .always_false) {
                    Printer.status(.fail, "Sometimes assert was always false: {s}:{}:{}\n", .{ ctx.file, ctx.line, ctx.column });
                } else if (c.value_ptr.* == .always_true) {
                    Printer.status(.fail, "Sometimes assert was always true: {s}:{}:{}\n", .{ ctx.file, ctx.line, ctx.column });
                }
                failed_sometimes += 1;
            }
        }
    }

    const total_tests = pass + fail;
    const status = if (fail == 0) Status.pass else Status.fail;
    Printer.status(status, "\n{d} of {d} test{s} passed\n", .{ pass, total_tests, if (total_tests != 1) "s" else "" });
    if (skip > 0) {
        Printer.status(.skip, "{d} test{s} skipped\n", .{ skip, if (skip != 1) "s" else "" });
    }
    if (leak > 0) {
        Printer.status(.fail, "{d} test{s} leaked\n", .{ leak, if (leak != 1) "s" else "" });
    }
    if (failed_sometimes > 0) {
        Printer.status(.fail, "{d} sometimes assertion{s} not covered\n", .{ failed_sometimes, if (failed_sometimes != 1) "s" else "" });
    }
    Printer.fmt("\n", .{});
    try slowest.display();
    Printer.fmt("\n", .{});
    std.process.exit(if (fail == 0 and failed_sometimes == 0) 0 else 1);
}

const Printer = struct {
    fn fmt(comptime format: []const u8, args: anytype) void {
        std.debug.print(format, args);
    }

    fn status(s: Status, comptime format: []const u8, args: anytype) void {
        switch (s) {
            .pass => std.debug.print("\x1b[32m", .{}),
            .fail => std.debug.print("\x1b[31m", .{}),
            .skip => std.debug.print("\x1b[33m", .{}),
            else => {},
        }
        std.debug.print(format ++ "\x1b[0m", args);
    }
};

const Status = enum {
    pass,
    fail,
    skip,
    text,
};

const SlowTracker = struct {
    const SlowestQueue = std.PriorityDequeue(TestInfo, void, compareTiming);
    max: usize,
    slowest: SlowestQueue,
    start_ts: std.Io.Timestamp,
    io: std.Io,

    fn init(allocator: Allocator, io: std.Io, count: u32) SlowTracker {
        var slowest: SlowestQueue = .initContext({});
        slowest.ensureTotalCapacity(allocator, count) catch @panic("OOM");
        return .{
            .max = count,
            .start_ts = std.Io.Timestamp.now(io, .awake),
            .slowest = slowest,
            .io = io,
        };
    }

    const TestInfo = struct {
        ns: u64,
        name: []const u8,
    };

    fn deinit(self: *SlowTracker, allocator: Allocator) void {
        self.slowest.deinit(allocator);
    }

    fn startTiming(self: *SlowTracker) void {
        self.start_ts = std.Io.Timestamp.now(self.io, .awake);
    }

    fn endTiming(self: *SlowTracker, allocator: Allocator, test_name: []const u8) u64 {
        const elapsed = self.start_ts.durationTo(std.Io.Timestamp.now(self.io, .awake));
        const ns: u64 = @intCast(elapsed.nanoseconds);

        var slowest = &self.slowest;

        if (slowest.count() < self.max) {
            slowest.push(allocator, TestInfo{ .ns = ns, .name = test_name }) catch @panic("failed to track test timing");
            return ns;
        }

        {
            const fastest_of_the_slow = slowest.peekMin() orelse unreachable;
            if (fastest_of_the_slow.ns > ns) {
                return ns;
            }
        }

        _ = slowest.popMin();
        slowest.push(allocator, TestInfo{ .ns = ns, .name = test_name }) catch @panic("failed to track test timing");
        return ns;
    }

    fn display(self: *SlowTracker) !void {
        var slowest = self.slowest;
        const count = slowest.count();
        Printer.fmt("Slowest {d} test{s}: \n", .{ count, if (count != 1) "s" else "" });
        while (slowest.popMin()) |info| {
            const ms = @as(f64, @floatFromInt(info.ns)) / 1_000_000.0;
            Printer.fmt("  {d:.2}ms\t{s}\n", .{ ms, info.name });
        }
    }

    fn compareTiming(context: void, a: TestInfo, b: TestInfo) std.math.Order {
        _ = context;
        return std.math.order(a.ns, b.ns);
    }
};

const Env = struct {
    verbose: bool,
    filter: ?[]const u8,

    fn init(environ_map: *std.process.Environ.Map) Env {
        return .{
            .verbose = if (environ_map.get("TEST_VERBOSE")) |v|
                std.ascii.eqlIgnoreCase(v, "true")
            else
                false,
            .filter = environ_map.get("TEST_FILTER"),
        };
    }
};

pub const panic = std.debug.FullPanic(struct {
    pub fn panicFn(msg: []const u8, first_trace_addr: ?usize) noreturn {
        if (current_test) |ct| {
            std.debug.print("\x1b[31m{s}\npanic running \"{s}\"\n{s}\x1b[0m\n", .{ BORDER, ct, BORDER });
        }
        std.debug.defaultPanic(msg, first_trace_addr);
    }
}.panicFn);

fn isUnnamed(t: std.builtin.TestFn) bool {
    const marker = ".test_";
    const test_name = t.name;
    const index = std.mem.indexOf(u8, test_name, marker) orelse return false;
    _ = std.fmt.parseInt(u32, test_name[index + marker.len ..], 10) catch return false;
    return true;
}
