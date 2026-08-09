const std = @import("std");

var _io: ?std.Io = null;
var _gpa: ?std.mem.Allocator = null;

pub fn init(init_io: std.Io, init_gpa: std.mem.Allocator) void {
    _io = init_io;
    _gpa = init_gpa;
}

pub fn io() std.Io {
    std.debug.assert(_io != null);
    return _io.?;
}

pub fn gpa() std.mem.Allocator {
    std.debug.assert(_gpa != null);
    return _gpa.?;
}
