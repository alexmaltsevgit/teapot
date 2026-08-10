const glfw = @import("zglfw");

// dummy interface to init and deinit window
// useful for setup and for global access to glfw window object,
// especially in callbacks
// in other cases use glfw library directly

pub var window: *glfw.Window = undefined;

pub const gl_version_major: u16 = 4;
pub const gl_version_minor: u16 = 0;

pub fn init() !void {
    try glfw.init();

    glfw.windowHint(.client_api, .opengl_api);
    glfw.windowHint(.context_version_major, gl_version_major);
    glfw.windowHint(.context_version_minor, gl_version_minor);
    glfw.windowHint(.opengl_profile, .opengl_core_profile);
    glfw.windowHint(.opengl_forward_compat, true);
    glfw.windowHint(.doublebuffer, true);

    window = try glfw.Window.create(1200, 1200, "teapot", null, null);
    glfw.makeContextCurrent(window);
    glfw.swapInterval(0);
}

pub fn deinit() void {
    window.destroy();
    glfw.terminate();
}
