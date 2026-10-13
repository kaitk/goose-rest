// goose-http's bench/dusty build.zig, for the REST server with a route per
// path (NOTES.md). The binary keeps goose-http's entry's name.
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseFast });

    const dusty_dep = b.dependency("dusty", .{
        .target = target,
        .optimize = optimize,
    });
    const dusty_mod = dusty_dep.module("dusty");

    const zio_dep = b.dependency("zio", .{
        .target = target,
        .optimize = optimize,
    });
    const zio_mod = zio_dep.module("zio");

    dusty_mod.addImport("zio", zio_mod);

    const exe = b.addExecutable(.{
        .name = "rest-dusty",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .strip = true,
        }),
    });
    exe.root_module.addImport("dusty", dusty_mod);
    exe.root_module.addImport("zio", zio_mod);
    b.installArtifact(exe);
}
