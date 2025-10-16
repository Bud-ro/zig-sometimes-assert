//! Entry point, `sometimes.assert` should be stripped out for non-test builds

pub fn main() !void {
    var buffer: [4096]u8 = undefined;
    var output_writer: std.fs.File.Writer = std.fs.File.stdout().writer(&buffer);
    const writer: *std.Io.Writer = &output_writer.interface;

    try writer.writeAll("Hello World 1!\n");
    sometimes.assert(&@src(), false);
    try writer.writeAll("Hello World 2!\n");
    try writer.flush();
}

test "simple test" {
    var list: std.ArrayList(i32) = try .initCapacity(std.testing.allocator, 10);
    defer list.deinit(std.testing.allocator);

    sometimes.assert(&@src(), false);

    try list.append(std.testing.allocator, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

fn myFunc(dummy: bool) void {
    sometimes.assert(&@src(), dummy);
}

test "test 1 myFunc" {
    myFunc(false);
}

test "test 2 myFunc" {
    myFunc(true);
}

const std = @import("std");
const sometimes = @import("sometimes");
