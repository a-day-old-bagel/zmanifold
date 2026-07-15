const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const options = .{
        .manifold_export = b.option(
            bool,
            "manifold_export",
            "Build mesh export (via assimp) utility library",
        ) orelse false,
        .manifold_parallel = b.option(
            bool,
            "manifold_parallel",
            "Enable Parallel backend",
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

    const manifoldc = b.addLibrary(.{
        .name = "manifoldc",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = null,
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .link_libcpp = true,
        }),
    });
    b.installArtifact(manifoldc);

    manifoldc.root_module.addIncludePath(b.path("libs/Clipper2/CPP/Clipper2Lib/include"));
    if (options.manifold_parallel) manifoldc.root_module.addIncludePath(b.path("libs/oneTBB/include"));

    manifoldc.root_module.addIncludePath(b.path("libs/manifold/include"));
    manifoldc.root_module.addIncludePath(b.path("libs/manifold/bindings/c"));
    manifoldc.root_module.addIncludePath(b.path("libs/manifold/bindings/c/include"));

    const cpp_flags: []const []const u8 = &.{
        "-std=c++17",
        "-fno-exceptions",
        if (options.manifold_export) "-DMANIFOLD_EXPORT" else "",
        if (options.manifold_parallel) "-DMANIFOLD_PAR=1" else "-DMANIFOLD_PAR=-1",
        if (options.manifold_parallel) "-DTBB_USE_DEBUG=0" else "",
    };

    manifoldc.root_module.addCSourceFiles(.{
        .files = &.{
            "libs/manifold/bindings/c/box.cpp",
            "libs/manifold/bindings/c/conv.cpp",
            "libs/manifold/bindings/c/cross.cpp",
            "libs/manifold/bindings/c/manifoldc.cpp",
            "libs/manifold/bindings/c/rect.cpp",

            "libs/manifold/src/cross_section/cross_section.cpp",

            "libs/manifold/src/boolean_result.cpp",
            "libs/manifold/src/boolean3.cpp",
            "libs/manifold/src/constructors.cpp",
            "libs/manifold/src/csg_tree.cpp",
            "libs/manifold/src/edge_op.cpp",
            "libs/manifold/src/face_op.cpp",
            "libs/manifold/src/impl.cpp",
            "libs/manifold/src/manifold.cpp",
            "libs/manifold/src/polygon.cpp",
            "libs/manifold/src/properties.cpp",
            "libs/manifold/src/quickhull.cpp",
            "libs/manifold/src/sdf.cpp",
            "libs/manifold/src/smoothing.cpp",
            "libs/manifold/src/sort.cpp",
            "libs/manifold/src/subdivision.cpp",
            "libs/manifold/src/tree2d.cpp",
        },
        .flags = cpp_flags,
    });
    if (options.manifold_export) manifoldc.root_module.addCSourceFiles(.{
        .files = &.{
            "libs/manifold/src/meshIO/meshIO.cpp",
            "libs/manifold/bindings/c/meshIOc.cpp",
        },
        .flags = cpp_flags,
    });
    if (options.manifold_parallel) manifoldc.root_module.addCSourceFiles(.{
        .files = &.{
            "libs/oneTBB/src/tbb/address_waiter.cpp",
            "libs/oneTBB/src/tbb/allocator.cpp",
            "libs/oneTBB/src/tbb/arena.cpp",
            "libs/oneTBB/src/tbb/arena_slot.cpp",
            "libs/oneTBB/src/tbb/concurrent_bounded_queue.cpp",
            "libs/oneTBB/src/tbb/dynamic_link.cpp",
            "libs/oneTBB/src/tbb/exception.cpp",
            "libs/oneTBB/src/tbb/global_control.cpp",
            "libs/oneTBB/src/tbb/governor.cpp",
            "libs/oneTBB/src/tbb/itt_notify.cpp",
            "libs/oneTBB/src/tbb/main.cpp",
            "libs/oneTBB/src/tbb/market.cpp",
            "libs/oneTBB/src/tbb/misc.cpp",
            "libs/oneTBB/src/tbb/misc_ex.cpp",
            "libs/oneTBB/src/tbb/observer_proxy.cpp",
            "libs/oneTBB/src/tbb/parallel_pipeline.cpp",
            "libs/oneTBB/src/tbb/private_server.cpp",
            "libs/oneTBB/src/tbb/profiling.cpp",
            "libs/oneTBB/src/tbb/queuing_rw_mutex.cpp",
            "libs/oneTBB/src/tbb/rml_tbb.cpp",
            "libs/oneTBB/src/tbb/rtm_mutex.cpp",
            "libs/oneTBB/src/tbb/rtm_rw_mutex.cpp",
            "libs/oneTBB/src/tbb/semaphore.cpp",
            "libs/oneTBB/src/tbb/small_object_pool.cpp",
            "libs/oneTBB/src/tbb/task.cpp",
            "libs/oneTBB/src/tbb/task_dispatcher.cpp",
            "libs/oneTBB/src/tbb/task_group_context.cpp",
            "libs/oneTBB/src/tbb/tbb.rc",
            "libs/oneTBB/src/tbb/tcm_adaptor.cpp",
            "libs/oneTBB/src/tbb/thread_dispatcher.cpp",
            "libs/oneTBB/src/tbb/thread_request_serializer.cpp",
            "libs/oneTBB/src/tbb/threading_control.cpp",
            "libs/oneTBB/src/tbb/version.cpp",
        },
        .flags = &.{ "-std=c++17", "-DTBB_USE_DEBUG=0" },
    });

    const clipper = b.addLibrary(.{
        .name = "clipper",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = null,
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .link_libcpp = true,
        }),
    });
    b.installArtifact(clipper);

    clipper.root_module.addIncludePath(b.path("libs/Clipper2/CPP/Clipper2Lib/include"));

    clipper.root_module.addCSourceFiles(.{
        .files = &.{
            "libs/Clipper2/CPP/Clipper2Lib/src/clipper.engine.cpp",
            "libs/Clipper2/CPP/Clipper2Lib/src/clipper.offset.cpp",
            "libs/Clipper2/CPP/Clipper2Lib/src/clipper.rectclip.cpp",
        },
        .flags = &.{
            "-std=c++17",
            "-fno-exceptions",
        },
    });

    manifoldc.root_module.linkLibrary(clipper);

    const test_step = b.step("test", "Run zmanifold tests");
    const tests = b.addTest(.{
        .name = "zmanifold-tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/zmanifold.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(tests);
    tests.root_module.addImport("zmanifold_options", options_module);
    tests.addIncludePath(b.path("libs/manifold/bindings/c/include"));
    tests.linkLibrary(manifoldc);
    test_step.dependOn(&b.addRunArtifact(tests).step);
}
