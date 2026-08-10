const std = @import("std");

const zm = @import("zmath");
const zopengl = @import("zopengl");
const ogl = zopengl.wrapper;

const engine = @import("../engine.zig");

const Self = @This();

name: []const u8,
local_transform: zm.Mat,

mesh_indices: std.ArrayList(usize),

children: std.ArrayList(Self),

pub fn init(name: []const u8, local_transform: zm.Mat) !Self {
    return .{
        .name = name,
        .local_transform = local_transform,
        .mesh_indices = .empty,
        .children = .empty,
    };
}

pub fn deinit(self: *Self) void {
    for (self.children.items) |*child| {
        child.deinit();
    }

    self.children.deinit(engine.gpa);
    self.mesh_indices.deinit(engine.gpa);

    engine.gpa.free(self.name);
}

test {
    std.testing.refAllDecls(Self);
}
