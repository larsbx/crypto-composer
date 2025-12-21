const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "crypto-composer",
        .root_source_file = .{ .path = "src/lib.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "crypto-compose",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("composer", lib.root_module);
    b.installArtifact(exe);

    const tests = b.addTest(.{
        .root_source_file = .{ .path = "test/all_tests.zig" },
        .target = target,
        .optimize = optimize,
    });
    tests.root_module.addImport("composer", lib.root_module);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&tests.step);
}
