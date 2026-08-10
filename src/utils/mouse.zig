const std = @import("std");

const glfw = @import("zglfw");

const engine = @import("../engine.zig");

const Position = struct { x: f64 = 0, y: f64 = 0 };

var pos: Position = undefined;
var prev: Position = undefined;

pub const Event = enum { change };

pub var event_source: engine.utils.EventSource(Event) = undefined;

pub fn init() void {
    event_source = engine.utils.EventSource(Event).init(engine.gpa);

    const cursor = engine.Singletone.Window.window.getCursorPos();
    pos.x = cursor[0];
    pos.y = cursor[1];

    prev = pos;

    _ = engine.Singletone.Window.window.setCursorPosCallback(onChange);
}

pub fn deinit() void {
    event_source.deinit();
}

pub fn set(x: ?f64, y: ?f64) void {
    setPure(x, y);
    glfw.setCursorPos(engine.Window.window, pos.x, pos.y);
}

pub fn getPos() Position {
    return pos;
}

pub fn getPrev() Position {
    return prev;
}

pub fn getDelta() Position {
    return .{
        .x = pos.x - prev.x,
        .y = pos.y - prev.y,
    };
}

fn onChange(_: *glfw.Window, x: f64, y: f64) callconv(.c) void {
    setPure(x, y);
    event_source.invoke(.change);
}

fn setPure(x: ?f64, y: ?f64) void {
    prev = pos;

    if (x != null) {
        pos.x = x.?;
    }

    if (y != null) {
        pos.y = y.?;
    }
}
