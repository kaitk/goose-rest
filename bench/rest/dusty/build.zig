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

    // Tier R's routes, embedded by a module of their own: @embedFile reaches
    // only files inside the module that embeds them. A build from a copy
    // outside the repository passes -Dgithub.
    const github_txt = b.option([]const u8, "github", "tier R's github.txt") orelse
        b.pathFromRoot("../tiers/github.txt");
    const wf = b.addWriteFiles();
    _ = wf.addCopyFile(.{ .cwd_relative = github_txt }, "github.txt");
    const github_zig = wf.add("github.zig", "pub const text = @embedFile(\"github.txt\");\n");
    exe.root_module.addImport("github", b.createModule(.{ .root_source_file = github_zig }));

    b.installArtifact(exe);
}
