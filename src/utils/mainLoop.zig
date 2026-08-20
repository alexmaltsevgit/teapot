const std = @import("std");

const glfw = @import("zglfw");
const zm = @import("zmath");
const zopengl = @import("zopengl");
const ogl = zopengl.wrapper;
const zstbi = @import("zstbi");

const engine = @import("../engine.zig");

const Self = @This();

renderer: engine.Renderer,
model_repo: engine.ModelRepo,

previous_time: f64,

fps_accum: u16 = 0,
fps_time_accum: f32 = 0,

pub fn init() !Self {
    var renderer_ogl = engine.Renderer.impls.RendererOgl.init();
    try renderer_ogl.setup();

    var model_repo_ogl = engine.ModelRepo.impls.ModelRepoOgl.init();

    var models = try std.ArrayList(engine.Model).initCapacity(engine.gpa, 1);
    errdefer models.deinit(engine.gpa);

    // model.* = try engine.Model.init("res/chair/source/Daytime_Lighting_Scene.fbx");
    // try engine.Renderer.impls.RendererOgl.prepareModel(model);
    // model.* = try engine.Model.init("res/Survival_BackPack_2.fbx");
    // model.* = try engine.Model.init("res/backpack.obj");
    // model.transform.scaleBy(0.01, 0.01, 0.01);
    // model.transform.scaleBy(1, 1, 1);

    try glfw.setInputMode(engine.Singletone.Window.window, .cursor, .disabled);

    try model_repo_ogl.load("res/chair/source/Daytime_Lighting_Scene.fbx");

    return .{
        .renderer = engine.Renderer.Renderer.from(&renderer_ogl),
        .model_repo = engine.ModelRepo.ModelRepo.from(&model_repo_ogl),
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
        try self.renderer.render(model);
    }

    const w = 10 * @as(f32, @floatFromInt(@intFromEnum(engine.Singletone.Keyboard.getKey(.w))));
    const s = -10 * @as(f32, @floatFromInt(@intFromEnum(engine.Singletone.Keyboard.getKey(.s))));
    const a = -10 * @as(f32, @floatFromInt(@intFromEnum(engine.Singletone.Keyboard.getKey(.a))));
    const d = 10 * @as(f32, @floatFromInt(@intFromEnum(engine.Singletone.Keyboard.getKey(.d))));

    engine.camera.move(dt * (a + d), dt * (w + s));

    engine.Singletone.Window.window.swapBuffers();
    glfw.pollEvents();
}
