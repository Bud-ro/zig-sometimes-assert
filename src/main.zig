//! Entry point, `sometimes.assert` should be stripped out for non-test builds

pub fn main() !void {
    var buffer: [4096]u8 = undefined;
    var output_writer: std.fs.File.Writer = std.fs.File.stdout().writer(&buffer);
    const writer: *std.Io.Writer = &output_writer.interface;

    try writer.writeAll("Hello World 1!\n");
    sometimes.assert(&@src(), true); // These both show up in the output
    sometimes.assert(&@src(), false); // Because they fail to cover the other case
    try writer.writeAll("Hello World 2!\n");
    try writer.flush();

    _ = myOtherFunc(true);
}

fn myFunc(dummy: bool) void {
    sometimes.assert(&@src(), dummy);
}

fn myOtherFunc(dummy: bool) bool {
    sometimes.assert(&@src(), dummy);
    return true;
}

test "test 1 myFunc" {
    myFunc(false);
}

test "test 2 myFunc" {
    myFunc(true);
}

test "myOtherFunc false" {
    try std.testing.expect(myOtherFunc(false)); // No need to test for the `true` case because `main` covers this for us!
}

test "comptime is ignored as part of function" {
    const returnValue = comptime myOtherFunc(false);
    try std.testing.expect(returnValue);
}

test "comptime is ignored when done directly" {
    comptime sometimes.assert(&@src(), true);
}

test "main test" {
    try main();
}

const std = @import("std");
const sometimes = @import("sometimes");
