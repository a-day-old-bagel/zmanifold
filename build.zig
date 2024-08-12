const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const options = .{
        .manifold_export = b.option(
            bool,
            "manifold_export",
            "Compile with MeshIO",
        ) orelse false,
    };

    const options_step = b.addOptions();
    inline for (std.meta.fields(@TypeOf(options))) |field| {
        options_step.addOption(field.type, field.name, @field(options, field.name));
    }

    const options_module = options_step.createModule();

    const zmanifold = b.addModule("root", .{
        .root_source_file = b.path("src/zmanifold.zig"),
        .imports = &.{
            .{ .name = "zmanifold_options", .module = options_module },
        },
    });
    zmanifold.addIncludePath(b.path("libs/manifold/bindings/c/include"));

    const clipper = b.addStaticLibrary(.{
        .name = "clipper",
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(clipper);

    clipper.addIncludePath(b.path("libs/Clipper2/CPP/Clipper2Lib/include"));
    clipper.linkLibC();
    if (target.result.abi != .msvc)
        clipper.linkLibCpp();

    clipper.addCSourceFiles(.{
        .files = &.{
            "libs/Clipper2/CPP/Clipper2Lib/src/clipper.engine.cpp",
            "libs/Clipper2/CPP/Clipper2Lib/src/clipper.offset.cpp",
            "libs/Clipper2/CPP/Clipper2Lib/src/clipper.rectclip.cpp",
        },
        .flags = &.{
            "-std=c++17",
        },
    });

    const manifoldc = b.addStaticLibrary(.{
        .name = "manifoldc",
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(manifoldc);

    manifoldc.addIncludePath(b.path("libs/glm"));
    manifoldc.addIncludePath(b.path("libs/Clipper2/CPP/Clipper2Lib/include"));
    manifoldc.addIncludePath(b.path("libs/manifold/bindings/c"));
    manifoldc.addIncludePath(b.path("libs/manifold/bindings/c/include"));
    manifoldc.addIncludePath(b.path("libs/manifold/src/collider/include"));
    manifoldc.addIncludePath(b.path("libs/manifold/src/cross_section/include"));
    manifoldc.addIncludePath(b.path("libs/manifold/src/manifold/include"));
    manifoldc.addIncludePath(b.path("libs/manifold/src/polygon/include"));
    manifoldc.addIncludePath(b.path("libs/manifold/src/utilities/include"));
    manifoldc.addIncludePath(b.path("libs/manifold/meshIO/include"));
    manifoldc.linkLibC();
    if (target.result.abi != .msvc)
        manifoldc.linkLibCpp();
    manifoldc.linkLibrary(clipper);

    manifoldc.addCSourceFiles(.{
        .files = &.{
            "libs/manifold/bindings/c/box.cpp",
            "libs/manifold/bindings/c/conv.cpp",
            "libs/manifold/bindings/c/cross.cpp",
            "libs/manifold/bindings/c/manifoldc.cpp",
            "libs/manifold/bindings/c/rect.cpp",

            "libs/manifold/src/manifold/src/boolean_result.cpp",
            "libs/manifold/src/manifold/src/boolean3.cpp",
            "libs/manifold/src/manifold/src/constructors.cpp",
            "libs/manifold/src/manifold/src/csg_tree.cpp",
            "libs/manifold/src/manifold/src/edge_op.cpp",
            "libs/manifold/src/manifold/src/face_op.cpp",
            "libs/manifold/src/manifold/src/impl.cpp",
            "libs/manifold/src/manifold/src/manifold.cpp",
            "libs/manifold/src/manifold/src/properties.cpp",
            "libs/manifold/src/manifold/src/quickhull.cpp",
            "libs/manifold/src/manifold/src/sdf.cpp",
            "libs/manifold/src/manifold/src/smoothing.cpp",
            "libs/manifold/src/manifold/src/sort.cpp",
            "libs/manifold/src/manifold/src/subdivision.cpp",

            "libs/manifold/src/cross_section/src/cross_section.cpp",
            "libs/manifold/src/polygon/src/polygon.cpp",
        },
        .flags = &.{
            "-std=c++17",
            if (options.manifold_export) "-DMANIFOLD_EXPORT" else "",
        },
    });
    if (options.manifold_export) manifoldc.addCSourceFiles(.{
        .files = &.{
            "libs/manifold/bindings/c/manifoldc.cpp",
            "libs/manifold/meshIO/src/meshIO.cpp",
        },
        .flags = &.{ "-std=c++17", "-DMANIFOLD_EXPORT" },
    });

    const test_step = b.step("test", "Run zmanifold tests");

    const tests = b.addTest(.{
        .name = "zmanifold-tests",
        .root_source_file = b.path("src/zmanifold.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(tests);
    tests.root_module.addImport("zmanifold_options", options_module);
    tests.addIncludePath(b.path("libs/manifold/bindings/c/include"));
    tests.linkLibrary(manifoldc);
    test_step.dependOn(&b.addRunArtifact(tests).step);
}