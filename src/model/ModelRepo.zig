const std = @import("std");
const Interface = @import("interface").Interface;
const engine = @import("../engine.zig");

pub const ModelRepo = Interface(.{
    .load = fn () anyerror!void,
    .unload = fn () void,
}, null);

pub const impls = struct {
    pub const ModelRepoOgl = @import("./opengl/ModelRepoOgl.zig");
};
