const std = @import("std");

const zm = @import("zmath");
const zopengl = @import("zopengl");
const ogl = zopengl.wrapper;

const engine = @import("../engine.zig");

var map: std.StringHashMap(*engine.ShaderProgram) = undefined;

const ShaderOpts = struct {
    path: []const u8,
    defines: []const []const u8,
};

const Shaders = struct {
    vertex: ShaderOpts,
    fragment: ShaderOpts,
};

pub fn init() void {
    map = .init(engine.gpa);
}

pub fn deinit() void {
    var it = map.iterator();

    while (it.next()) |entry| {
        engine.gpa.free(entry.key_ptr.*);
        entry.value_ptr.*.deinit();
        engine.gpa.destroy(entry.value_ptr.*);
    }

    map.deinit();
}

pub fn get(opts: *const Shaders) ?*engine.ShaderProgram {
    return map.get(std.mem.asBytes(opts));
}

// if program doesn't exist, try making it
pub fn getForce(opts: *const Shaders) !*engine.ShaderProgram {
    const key = try makeKey(opts);
    const res = try map.getOrPut(key);

    if (!res.found_existing) {
        errdefer _ = map.remove(std.mem.asBytes(opts));
        res.value_ptr.* = try makeProgram(opts);
    } else {
        engine.gpa.free(key);
    }

    return res.value_ptr.*;
}

fn makeProgram(opts: *const Shaders) !*engine.ShaderProgram {
    var shader_program = try engine.gpa.create(engine.ShaderProgram);
    shader_program.* = try engine.ShaderProgram.init();

    try shader_program.compileShader(opts.vertex.path, .vertex, opts.vertex.defines);
    try shader_program.compileShader(opts.fragment.path, .fragment, opts.fragment.defines);

    try shader_program.link();

    return shader_program;
}

fn makeKey(opts: *const Shaders) ![]u8 {
    var key: std.ArrayList(u8) = .empty;
    errdefer key.deinit(engine.gpa);

    inline for (.{ opts.vertex, opts.fragment }) |shader| {
        try key.appendSlice(engine.gpa, shader.path);
        try key.append(engine.gpa, 0);

        for (shader.defines) |define| {
            try key.appendSlice(engine.gpa, define);
            try key.append(engine.gpa, 0);
        }

        try key.append(engine.gpa, 0xff);
    }

    return key.toOwnedSlice(engine.gpa);
}

pub fn exists(opts: *const Shaders) bool {
    return map.contains(std.mem.asBytes(opts));
}

test {
    std.testing.refAllDecls(@This());
}
