const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "teapot",
        .root_module = b.createModule(.{
            .root_source_file = b.path(b.pathJoin(&.{"src/main.zig"})),
            .target = target,
            .optimize = optimize,
        }),
    });

    const zglfw = b.dependency("zglfw", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("zglfw", zglfw.module("root"));

    const zopengl = b.dependency("zopengl", .{});
    exe.root_module.addImport("zopengl", zopengl.module("root"));

    const zstbi = b.dependency("zstbi", .{});
    exe.root_module.addImport("zstbi", zstbi.module("root"));

    const zmath = b.dependency("zmath", .{});
    exe.root_module.addImport("zmath", zmath.module("root"));

    const interface_dep = b.dependency("interface", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("interface", interface_dep.module("interface"));

    if (target.result.os.tag != .emscripten) {
        exe.root_module.linkLibrary(zglfw.artifact("glfw"));
    }

    const assimp_dep = b.dependency("zig_assimp", .{ .formats = "Obj,STL,glTF,FBX" });
    const assimp_mod = assimp_dep.module("assimp");
    const assimp_lib = assimp_dep.artifact("assimp");

    exe.root_module.addImport("assimp", assimp_mod);
    exe.root_module.linkLibrary(assimp_lib);
    exe.root_module.link_libc = true;
    exe.root_module.link_libcpp = true;

    const run_cmd = b.addRunArtifact(exe);
    b.step("run", "Run the app").dependOn(&run_cmd.step);

    b.installArtifact(exe);

    // const exe_check = b.addExecutable(.{
    //     .name = "foo",
    //     .root_module = exe_mod,
    // });

    // const check = b.step("check", "Check if foo compiles");
    // check.dependOn(&exe_check.step);
}
