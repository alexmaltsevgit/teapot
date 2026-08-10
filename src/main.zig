const std = @import("std");

const glfw = @import("zglfw");
const zm = @import("zmath");
const zopengl = @import("zopengl");
const ogl = zopengl.wrapper;
const zstbi = @import("zstbi");

const engine = @import("engine.zig");

pub fn updateAndRender() void {
    glfw.pollEvents();

    ogl.clearColor(0.2, 0.2, 0.2, 1.0);
    ogl.clear(.{ .color = true });

    engine.window.swapBuffers();
}

var main_loop: engine.MainLoop = undefined;

fn keyCallback(_: *glfw.Window, key: glfw.Key, scancode: c_int, action: glfw.Action, mods: glfw.Mods) callconv(.c) void {
    _ = scancode;
    _ = mods;

    engine.Singletone.Keyboard.invoke(key, action);
}

pub fn main(init: std.process.Init) !void {
    var debug_gpa: std.heap.DebugAllocator(.{ .stack_trace_frames = 16 }) = .init;
    defer _ = debug_gpa.deinit();
    const gpa = debug_gpa.allocator();

    try engine.init(init.io, gpa);
    defer engine.deinit();

    zstbi.init(engine.io, engine.gpa);
    zstbi.setFlipVerticallyOnLoad(true);
    defer zstbi.deinit();

    _ = engine.Singletone.Window.window.setKeyCallback(keyCallback);

    engine.camera.listenMouse() catch {
        std.log.warn("Camera can't listen mouse", .{});
    };

    main_loop = try engine.MainLoop.init();
    defer main_loop.deinit();

    _ = glfw.setFramebufferSizeCallback(engine.Singletone.Window.window, struct {
        fn cb(_: *glfw.Window, w: c_int, h: c_int) callconv(.c) void {
            ogl.viewport(0, 0, @intCast(w), @intCast(h));
            main_loop.cycle() catch |e| {
                std.log.debug("Main Loop error: {any}", .{e});
            };
        }
    }.cb);

    try engine.Singletone.Keyboard.on(.escape, .press, struct {
        fn cb(_: ?*anyopaque) void {
            engine.Singletone.Window.window.setShouldClose(true);
        }
    }.cb);

    try main_loop.loop();
}
