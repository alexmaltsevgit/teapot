const std = @import("std");

pub const Camera = @import("utils/camera.zig");
pub const MainLoop = @import("utils/mainLoop.zig");
pub const Material = @import("utils/material.zig");
pub const Mesh = @import("utils/mesh.zig");
pub const Model = @import("utils/model.zig");
pub const Node = @import("utils/node.zig");
pub const ShaderProgram = @import("utils/shaderProgram.zig");
pub const Texture = @import("utils/texture.zig");
pub const Transform = @import("utils/transform.zig");
pub const Renderer = @import("render/renderer.zig");
pub const ModelRepo = @import("model/ModelRepo.zig");
pub const utils = @import("utils/utils.zig");

pub var io: std.Io = undefined;
pub var gpa: std.mem.Allocator = undefined;

pub const Singletone = struct {
    pub const Window = @import("utils/window.zig");
    pub const ShadersMap = @import("utils/shadersMap.zig");
    pub const Keyboard = @import("utils/keyboard.zig");
    pub const Mouse = @import("utils/mouse.zig");
};

pub var camera: Camera = undefined;

pub fn init(init_io: std.Io, init_gpa: std.mem.Allocator) !void {
    io = init_io;
    gpa = init_gpa;

    camera = Camera.init();

    inline for (comptime std.meta.declarations(Singletone)) |decl| {
        const Module = @field(Singletone, decl.name);

        if (comptime @hasDecl(Module, "init")) {
            const ReturnType = comptime @typeInfo(@TypeOf(Module.init)).@"fn".return_type.?;
            if (comptime @typeInfo(ReturnType) == .error_union) {
                try Module.init();
            } else {
                Module.init();
            }
        }
    }
}

pub fn deinit() void {
    inline for (comptime std.meta.declarations(Singletone)) |decl| {
        const Module = @field(Singletone, decl.name);

        if (comptime @hasDecl(Module, "deinit")) {
            Module.deinit();
        }
    }
}
