const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const shared_mod = b.addModule("shared_mod", .{
        .root_source_file = b.path("../shared/shared_mod.zig"),
        .target = target,
        .optimize = optimize,
    });

    // deps/ is populated by the Dockerfile. Modules are wired directly because
    // zinc's own build.zig uses a Zig dev-only API that 0.17.0 dropped.
    const aio = b.createModule(.{
        .root_source_file = b.path("deps/aio/src/aio.zig"),
        .target = target,
        .optimize = optimize,
    });
    const url = b.createModule(.{
        .root_source_file = b.path("deps/url/src/url.zig"),
        .target = target,
        .optimize = optimize,
    });
    const zinc = b.createModule(.{
        .root_source_file = b.path("deps/zinc/src/zinc.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "aio", .module = aio },
            .{ .name = "url", .module = url },
        },
    });

    const exe = b.addExecutable(.{
        .name = "bench_zinc",
        .root_module = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "shared_mod", .module = shared_mod },
                .{ .name = "zinc", .module = zinc },
            },
        }),
    });
    b.installArtifact(exe);
}
