const std = @import("std");

const zm = @import("zmath");

const engine = @import("../engine.zig");

const Self = @This();

position: zm.Vec = .{ 0, 0, 0, 1 },
front: zm.Vec = .{ 0, 0, -1, 0 },
up: zm.Vec = .{ 0, 1, 0, 0 },

yaw: f32 = -std.math.pi / 2.0,
pitch: f32 = 0.0,

view_to_clip: zm.Mat = zm.perspectiveFovRhGl(0.45 * std.math.pi, 1200.0 / 1200.0, 0.1, 100.0),
world_to_view: zm.Mat = zm.identity(),

pub fn init() Self {
    return .{};
}

pub fn recalcWorldToView(self: *Self) void {
    self.world_to_view = zm.lookAtRh(self.position, self.position + self.front, self.up);
}

pub fn move(self: *Self, dx: f32, dy: f32) void {
    const right = zm.normalize3(zm.cross3(self.front, self.up));

    if (dx != 0) {
        self.position += right * @as(zm.Vec, @splat(dx));
    }

    if (dy != 0) {
        self.position += self.front * @as(zm.Vec, @splat(dy));
    }

    self.recalcWorldToView();
}

pub fn rotate(self: *Self, delta_yaw: f32, delta_pitch: f32) void {
    const sensitivity: f32 = 0.0025;

    self.yaw += delta_yaw * sensitivity;
    self.pitch += delta_pitch * sensitivity;

    const max_pitch = std.math.pi / 2.0 - 0.001;
    self.pitch = std.math.clamp(self.pitch, -max_pitch, max_pitch);

    self.front = .{
        zm.cos(self.yaw) * zm.cos(self.pitch),
        zm.sin(self.pitch),
        zm.sin(self.yaw) * zm.cos(self.pitch),
        0.0,
    };

    self.front = zm.normalize3(self.front);

    self.recalcWorldToView();
}

pub fn listenMouse(self: *Self) !void {
    try engine.Singletone.Mouse.event_source.on(.change, self, onMouseChange);
}

fn onMouseChange(ctx: ?*anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(ctx.?));

    const delta = engine.Singletone.Mouse.getDelta();
    self.rotate(@floatCast(delta.x), @floatCast(-delta.y));
}
