const std = @import("std");

const glfw = @import("zglfw");
const zm = @import("zmath");
const zopengl = @import("zopengl");
const ogl = zopengl.wrapper;
const zstbi = @import("zstbi");

const engine = @import("../engine.zig");

const Self = @This();

models: std.ArrayList(engine.Model),

previous_time: f64,

fps_accum: u16 = 0,
fps_time_accum: f32 = 0,

pub fn init() !Self {
    try zopengl.loadCoreProfile(glfw.getProcAddress, engine.Singletone.Window.gl_version_major, engine.Singletone.Window.gl_version_minor);
    ogl.enable(.depth_test);
    ogl.enable(.stencil_test);
    ogl.enable(.cull_face);

    std.log.debug("{s}", .{ogl.getString(.version).?});

    var models = try std.ArrayList(engine.Model).initCapacity(engine.gpa, 1);
    errdefer models.deinit(engine.gpa);

    const model: *engine.Model = models.addOneAssumeCapacity();
    model.* = try engine.Model.init("res/chair/source/Daytime_Lighting_Scene.fbx");
    // model.* = try engine.Model.init("res/Survival_BackPack_2.fbx");
    // model.* = try engine.Model.init("res/backpack.obj");
    // model.transform.scaleBy(0.01, 0.01, 0.01);
    // model.transform.scaleBy(1, 1, 1);

    try glfw.setInputMode(engine.Singletone.Window.window, .cursor, .disabled);

    return .{
        .models = models,
        .previous_time = glfw.getTime(),
    };
}

pub fn deinit(self: *Self) void {
    for (self.models.items) |*value| {
        value.deinit();
    }
    self.models.deinit(engine.gpa);
}

pub fn loop(self: *Self) !void {
    while (!engine.Singletone.Window.window.shouldClose()) {
        try self.cycle();
    }
}

pub fn cycle(self: *Self) !void {
    const current_time = glfw.getTime();
    const dt: f32 = @floatCast(current_time - self.previous_time);

    self.fps_accum += 1;
    self.fps_time_accum += dt;
    // std.log.debug("dt {d}", .{dt});
    if (self.fps_time_accum > 1) {
        std.log.info("FPS {d}", .{@round(self.fps_accum / self.fps_time_accum)});
        self.fps_accum = 0;
        self.fps_time_accum = 0;
    }

    self.previous_time = current_time;

    ogl.clearColor(0.2, 0.2, 0.2, 1.0);
    ogl.clear(.{ .color = true, .depth = true, .stencil = true });

    for (self.models.items) |*model| {
        try model.draw();
    }

    const w = 10 * @as(f32, @floatFromInt(@intFromEnum(engine.Singletone.Keyboard.getKey(.w))));
    const s = -10 * @as(f32, @floatFromInt(@intFromEnum(engine.Singletone.Keyboard.getKey(.s))));
    const a = -10 * @as(f32, @floatFromInt(@intFromEnum(engine.Singletone.Keyboard.getKey(.a))));
    const d = 10 * @as(f32, @floatFromInt(@intFromEnum(engine.Singletone.Keyboard.getKey(.d))));

    engine.camera.move(dt * (a + d), dt * (w + s));

    engine.Singletone.Window.window.swapBuffers();
    glfw.pollEvents();
}
