const std = @import("std");

pub fn build(b: *std.Build) void {
    const bits = b.dependency("Zig-BitHelper", .{}).module("bits");

    const compress = b.addModule("rom-compress", .{
        .source_file = .{ .path = "compress.zig" },
        .dependencies = &.{
            .{ .name = "bits", .module = bits },
        },
    });

    const decompress = b.addModule("rom-decompress", .{
        .source_file = .{ .path = "decompress.zig" },
        .dependencies = &.{
            .{ .name = "bits", .module = bits },
        },
    });

    const tests = b.addTest(.{
        .root_source_file = .{ .path = "tests.zig"},
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    });
    tests.addModule("rom-compress", compress);
    tests.addModule("rom-decompress", decompress);
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_tests.step);

}
