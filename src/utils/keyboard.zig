const std = @import("std");

const glfw = @import("zglfw");

const engine = @import("../engine.zig");

const c_int_bitsize = @bitSizeOf(c_int);
const Key = @Int(.signed, 2 * c_int_bitsize);

const Callback = *const fn (?*anyopaque) void;

var event_source: engine.utils.EventSource(Key) = undefined;

pub fn init() void {
    event_source = engine.utils.EventSource(Key).init(engine.gpa);
}

pub fn deinit() void {
    event_source.deinit();
}

pub fn on(input: glfw.Key, action: glfw.Action, callback: Callback) !void {
    const key = makeHandlerKey(input, action);
    try event_source.on(key, null, callback);
}

pub fn off(input: glfw.Key, action: glfw.Action, callback: Callback) !void {
    const key = makeHandlerKey(input, action);
    try event_source.off(key, callback);
}

pub fn invoke(input: glfw.Key, action: glfw.Action) void {
    event_source.invoke(makeHandlerKey(input, action));
}

pub fn getKey(key: glfw.Key) glfw.Action {
    return glfw.getKey(engine.Singletone.Window.window, key);
}

fn makeHandlerKey(input: glfw.Key, action: glfw.Action) i64 {
    return (@as(Key, @intCast(@intFromEnum(input))) << c_int_bitsize) | @as(Key, @intCast(@intFromEnum(action)));
}

fn handlerKeyToEnums(key: Key) struct { input: glfw.Key, action: glfw.Action } {
    return .{
        .action = @truncate(key),
        .input = @truncate(key >> c_int_bitsize),
    };
}
