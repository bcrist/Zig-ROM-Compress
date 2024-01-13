const std = @import("std");

pub fn build(b: *std.Build) void {
    const bits = b.dependency("Zig-BitHelper", .{}).module("bits");

    const compress = b.addModule("rom-compress", .{
        .root_source_file = .{ .path = "compress.zig" },
    });
    compress.addImport("bits", bits);

    const decompress = b.addModule("rom-decompress", .{
        .root_source_file = .{ .path = "decompress.zig" },
    });
    decompress.addImport("bits", bits);

    const tests = b.addTest(.{
        .root_source_file = .{ .path = "tests.zig"},
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    });
    tests.root_module.addImport("rom-compress", compress);
    tests.root_module.addImport("rom-decompress", decompress);
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_tests.step);

}
