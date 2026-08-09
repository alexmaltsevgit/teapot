const std = @import("std");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
const ogl = zopengl.wrapper;
const ctx = @import("ctx.zig");
const shader = @import("shader.zig");

const gl_version_major: u16 = 4;
const gl_version_minor: u16 = 0;

pub var window: *glfw.Window = undefined;

pub fn init_window() !void {
    window = try glfw.Window.create(600, 600, "teapot", null, null);
    glfw.makeContextCurrent(window);
    glfw.swapInterval(1);
}

pub fn deinit() void {
    window.destroy();
}

pub fn updateAndRender() void {
    glfw.pollEvents();

    ogl.clearColor(0.2, 0.2, 0.2, 1.0);
    ogl.clear(.{ .color = true });

    window.swapBuffers();
}

const vertices = [_]f32{
    -0.5, -0.5, 0.0, // 0: левый нижний
    0.5, -0.5, 0.0, // 1: правый нижний
    0.5, 0.5, 0.0, // 2: правый верхний
    -0.5, 0.5, 0.0, // 3: левый верхний
};

const indices = [_]u8{ 0, 1, 3, 1, 2, 3 };

pub fn main(init: std.process.Init) !void {
    ctx.init(init.io, init.gpa);

    try glfw.init();
    defer glfw.terminate();

    glfw.windowHint(.client_api, .opengl_api);
    glfw.windowHint(.context_version_major, gl_version_major);
    glfw.windowHint(.context_version_minor, gl_version_minor);
    glfw.windowHint(.opengl_profile, .opengl_core_profile);
    glfw.windowHint(.opengl_forward_compat, true);
    glfw.windowHint(.doublebuffer, true);

    try init_window();
    defer deinit();

    _ = glfw.setFramebufferSizeCallback(window, struct {
        fn lambda(_: *glfw.Window, w: c_int, h: c_int) callconv(.c) void {
            updateAndRender();
            ogl.viewport(0, 0, @intCast(w), @intCast(h));
        }
    }.lambda);

    _ = window.setKeyCallback(struct {
        fn lambda(_: *glfw.Window, key: glfw.Key, _: c_int, _: glfw.Action, _: glfw.Mods) callconv(.c) void {
            switch (key) {
                .escape => window.setShouldClose(true),
                else => {},
            }
        }
    }.lambda);

    try zopengl.loadCoreProfile(glfw.getProcAddress, gl_version_major, gl_version_minor);

    std.log.debug("{s}", .{ogl.getString(.version).?});

    var shader_program = try shader.ShaderProgram.init();
    defer shader_program.deinit();

    try shader_program.compileShader("vertex.glsl", .vertex);
    try shader_program.compileShader("fragment.glsl", .fragment);

    try shader_program.link();

    // VAO
    var vao: ogl.VertexArray = undefined;
    ogl.genVertexArray(&vao);
    ogl.bindVertexArray(vao);
    defer ogl.deleteVertexArray(&vao);

    // VBO
    var vbo: ogl.Buffer = undefined;
    ogl.genBuffer(&vbo);
    ogl.bindBuffer(.array_buffer, vbo);
    ogl.bufferData(.array_buffer, std.mem.sliceAsBytes(&vertices), .static_draw);
    defer ogl.deleteBuffer(&vbo);

    // EBO
    var ebo: ogl.Buffer = undefined;
    ogl.genBuffer(&ebo);
    ogl.bindBuffer(.element_array_buffer, ebo);
    ogl.bufferData(.element_array_buffer, &indices, .static_draw);
    defer ogl.deleteBuffer(&ebo);

    ogl.vertexAttribPointer(@enumFromInt(0), .three, .float, false, 3 * @sizeOf(f32), 0);
    ogl.enableVertexAttribArray(@enumFromInt(0));

    ogl.bindBuffer(.array_buffer, .invalid);
    ogl.bindVertexArray(.invalid);

    while (!window.shouldClose()) {
        ogl.clearColor(0.2, 0.2, 0.2, 1.0);
        ogl.clear(.{ .color = true });

        shader_program.use();

        ogl.bindVertexArray(vao);
        ogl.drawElements(.triangles, 6, .unsigned_byte, 0);

        window.swapBuffers();
        glfw.pollEvents();
    }
}
