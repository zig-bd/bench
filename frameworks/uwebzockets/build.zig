const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const shared_mod = b.addModule("shared_mod", .{
        .root_source_file = b.path("../shared/shared_mod.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "bench_uwebzockets",
        .root_module = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "shared_mod", .module = shared_mod },
            },
        }),
    });

    const uz = b.dependency("uWebZockets", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("uWebZockets", uz.module("uWebZockets"));
    b.installArtifact(exe);
}
