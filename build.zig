const std = @import("std");

pub fn build(b: *std.Build) void {
    const bits = b.dependency("bit_helper", .{}).module("bits");

    const compress = b.addModule("rom_compress", .{
        .root_source_file = b.path("compress.zig"),
        .imports = &.{
            .{ .name = "bits", .module = bits },
        },
    });

    const decompress = b.addModule("rom_decompress", .{
        .root_source_file = b.path("decompress.zig"),
        .imports = &.{
            .{ .name = "bits", .module = bits },
        },
    });

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests.zig"),
            .target = b.standardTargetOptions(.{}),
            .optimize = b.standardOptimizeOption(.{}),
            .imports = &.{
                .{ .name = "rom_compress", .module = compress },
                .{ .name = "rom_decompress", .module = decompress },
            },
        }),
    });

    b.step("test", "Run all tests").dependOn(&b.addRunArtifact(tests).step);

}
