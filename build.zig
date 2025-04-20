const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const some_mod = b.createModule(.{
        .root_source_file = b.path("src/some.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("some", some_mod);

    const exe = b.addExecutable(.{
        .name = "assert_sometimes",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);

    const enable_assert_sometimes = b.option(bool, "enable_sometimes", "Enable the effect of assert_sometimes") orelse false;

    const options = b.addOptions();
    options.addOption(bool, "enable_sometimes", enable_assert_sometimes);

    const options_mod = options.createModule();
    exe_mod.addImport("config", options_mod);
    some_mod.addImport("config", options_mod);

    const tests = b.addTest(.{
        .root_module = exe_mod,
        .test_runner = .{
            .path = b.path("src/test_runner.zig"),
            .mode = .simple,
        },
    });

    const run_tests = b.addRunArtifact(tests);
    const tests_artifact = b.addInstallArtifact(tests, .{ .dest_dir = .{ .override = .{ .custom = "test" } } });

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    run_tests.step.dependOn(&tests_artifact.step);
}
