const std = @import("std");

const zm = @import("zmath");
const zopengl = @import("zopengl");
const ogl = zopengl.wrapper;

const engine = @import("../engine.zig");

const ShaderProgram = @This();

id: ogl.Program,
shaders: std.ArrayList(ogl.Shader),

locations: std.StringHashMap(ogl.UniformLocation),

version: u16 = 450,

pub fn init() !@This() {
    return .{
        .id = try ogl.createProgram(),
        .shaders = try .initCapacity(engine.gpa, 2),
        .locations = .init(engine.gpa),
    };
}

pub fn deinit(self: *@This()) void {
    for (self.shaders.items) |shader| {
        ogl.deleteShader(shader);
    }

    var it = self.locations.iterator();
    while (it.next()) |entry| {
        engine.gpa.free(entry.key_ptr.*);
    }

    self.shaders.deinit(engine.gpa);
    self.locations.deinit();
    ogl.deleteProgram(self.id);
}

pub fn compileShader(self: *@This(), name: []const u8, t: ogl.ShaderType, defines: []const []const u8) !void {
    const shader_code = try readShader(engine.gpa, name);
    defer engine.gpa.free(shader_code);

    const shader = try ogl.createShader(t);

    const version_str = try std.fmt.allocPrint(engine.gpa, "#version {d} core\n", .{self.version});
    defer engine.gpa.free(version_str);

    const prepend = "#define ";
    var defs = try std.ArrayList(u8).initCapacity(engine.gpa, 16);
    defer defs.deinit(engine.gpa);

    for (defines, 0..) |def, i| {
        if (i > 0) {
            try defs.append(engine.gpa, '\n');
        }

        const append = try std.fmt.allocPrint(engine.gpa, "{s} 1\n", .{def});
        defer engine.gpa.free(append);

        try defs.appendSlice(engine.gpa, prepend);
        try defs.appendSlice(engine.gpa, append);
    }

    const defs_slice = try defs.toOwnedSlice(engine.gpa);
    defer engine.gpa.free(defs_slice);

    ogl.shaderSourceMany(
        shader,
        &.{ version_str.ptr, defs_slice.ptr, shader_code.ptr },
        &.{ @truncate(version_str.len), @truncate(defs_slice.len), @truncate(shader_code.len) },
    );

    ogl.compileShader(shader);

    try ensureShaderCompilation(shader);

    try self.shaders.append(engine.gpa, shader);
}

pub fn link(self: *@This()) !void {
    for (self.shaders.items) |shader| {
        ogl.attachShader(self.id, shader);
    }

    ogl.linkProgram(self.id);

    try ensureProgramLink(self.id);

    for (self.shaders.items) |shader| {
        ogl.deleteShader(shader);
    }

    self.shaders.clearRetainingCapacity();
}

pub fn use(self: *const @This()) void {
    ogl.useProgram(self.id);
}

pub fn setUniform(self: *@This(), name: []const u8, value: anytype) !void {
    self.use();

    const T = @TypeOf(value);

    var c_name: [:0]const u8 = undefined;

    var maybe_loc: ?ogl.UniformLocation = self.locations.get(name);
    var loc: ogl.UniformLocation = maybe_loc orelse undefined;

    if (maybe_loc == null) {
        c_name = try engine.gpa.dupeSentinel(u8, name, 0);
        defer engine.gpa.free(c_name);

        maybe_loc = ogl.getUniformLocation(self.id, c_name);
        if (maybe_loc == null) {
            return;
        }

        const key = try engine.gpa.dupe(u8, name);

        loc = maybe_loc.?;

        try self.locations.put(key, loc);
    }

    if (T == zm.Mat) {
        const mat: zm.Mat = value;
        ogl.uniformMatrix4fv(
            loc,
            1,
            false,
            zm.arrNPtr(&mat)[0..16],
        );
        return;
    }

    // todo: refactor slice/array
    switch (@typeInfo(T)) {
        .bool => ogl.uniform1i(loc, @intFromBool(value)),
        .comptime_int => ogl.uniform1i(loc, @intCast(value)),
        .int => |info| switch (info.signedness) {
            .signed => ogl.uniform1i(loc, @intCast(value)),
            .unsigned => ogl.uniform1ui(loc, @intCast(value)),
        },
        .float, .comptime_float => {
            ogl.uniform1f(loc, @floatCast(value));
        },
        .array => |info| {
            if (info.len < 1 or info.len > 4)
                return error.BadUniformLength;

            const array = value;

            switch (@typeInfo(info.child)) {
                .bool => {
                    const values: [4]i32 = .{
                        @intFromBool(array[0]),
                        if (array.len > 1) @intFromBool(array[1]) else 0,
                        if (array.len > 2) @intFromBool(array[2]) else 0,
                        if (array.len > 3) @intFromBool(array[3]) else 0,
                    };

                    switch (array.len) {
                        1 => ogl.uniform1iv(loc, 1, &values),
                        2 => ogl.uniform2iv(loc, 1, &values),
                        3 => ogl.uniform3iv(loc, 1, &values),
                        4 => ogl.uniform4iv(loc, 1, &values),
                        else => return error.BadUniformLength,
                    }
                },
                .int => |child_info| {
                    switch (child_info.signedness) {
                        .signed => {
                            const values: [4]i32 = .{
                                @intCast(array[0]),
                                if (array.len > 1) @intCast(array[1]) else 0,
                                if (array.len > 2) @intCast(array[2]) else 0,
                                if (array.len > 3) @intCast(array[3]) else 0,
                            };

                            switch (array.len) {
                                1 => ogl.uniform1iv(loc, 1, &values),
                                2 => ogl.uniform2iv(loc, 1, &values),
                                3 => ogl.uniform3iv(loc, 1, &values),
                                4 => ogl.uniform4iv(loc, 1, &values),
                                else => return error.BadUniformLength,
                            }
                        },
                        .unsigned => {
                            const values: [4]u32 = .{
                                @intCast(array[0]),
                                if (array.len > 1) @intCast(array[1]) else 0,
                                if (array.len > 2) @intCast(array[2]) else 0,
                                if (array.len > 3) @intCast(array[3]) else 0,
                            };

                            switch (array.len) {
                                1 => ogl.uniform1uiv(loc, 1, &values),
                                2 => ogl.uniform2uiv(loc, 1, &values),
                                3 => ogl.uniform3uiv(loc, 1, &values),
                                4 => ogl.uniform4uiv(loc, 1, &values),
                                else => return error.BadUniformLength,
                            }
                        },
                    }
                },
                .float => {
                    // const values: [4]f32 = .{
                    //     @floatCast(array[0]),
                    //     if (array.len > 1) @floatCast(array[1]) else 0,
                    //     if (array.len > 2) @floatCast(array[2]) else 0,
                    //     if (array.len > 3) @floatCast(array[3]) else 0,
                    // };

                    switch (array.len) {
                        1 => ogl.uniform1fv(loc, 1, &value),
                        2 => ogl.uniform2fv(loc, 1, &value),
                        3 => ogl.uniform3fv(loc, 1, &value),
                        4 => ogl.uniform4fv(loc, 1, &value),
                        else => return error.BadUniformLength,
                    }
                },
                else => {
                    @compileError("Unsupported uniform array element type");
                },
            }
        },
        .pointer => |info| {
            if (info.size != .slice) @compileError("Unsupported uniform type");

            const slice: []const info.child = value;

            if (slice.len < 1 or slice.len > 4)
                return error.BadUniformLength;

            switch (@typeInfo(info.child)) {
                .bool => {
                    const values: [4]i32 = .{
                        @intFromBool(slice[0]),
                        if (slice.len > 1) @intFromBool(slice[1]) else 0,
                        if (slice.len > 2) @intFromBool(slice[2]) else 0,
                        if (slice.len > 3) @intFromBool(slice[3]) else 0,
                    };

                    switch (slice.len) {
                        1 => ogl.uniform1iv(loc, 1, &values),
                        2 => ogl.uniform2iv(loc, 1, &values),
                        3 => ogl.uniform3iv(loc, 1, &values),
                        4 => ogl.uniform4iv(loc, 1, &values),
                        else => return error.BadUniformLength,
                    }
                },
                .int => |child_info| {
                    switch (child_info.signedness) {
                        .signed => {
                            const values: [4]i32 = .{
                                @intCast(slice[0]),
                                if (slice.len > 1) @intCast(slice[1]) else 0,
                                if (slice.len > 2) @intCast(slice[2]) else 0,
                                if (slice.len > 3) @intCast(slice[3]) else 0,
                            };

                            switch (slice.len) {
                                1 => ogl.uniform1iv(loc, 1, &values),
                                2 => ogl.uniform2iv(loc, 1, &values),
                                3 => ogl.uniform3iv(loc, 1, &values),
                                4 => ogl.uniform4iv(loc, 1, &values),
                                else => return error.BadUniformLength,
                            }
                        },
                        .unsigned => {
                            const values: [4]u32 = .{
                                @intCast(slice[0]),
                                if (slice.len > 1) @intCast(slice[1]) else 0,
                                if (slice.len > 2) @intCast(slice[2]) else 0,
                                if (slice.len > 3) @intCast(slice[3]) else 0,
                            };

                            switch (slice.len) {
                                1 => ogl.uniform1uiv(loc, 1, &values),
                                2 => ogl.uniform2uiv(loc, 1, &values),
                                3 => ogl.uniform3uiv(loc, 1, &values),
                                4 => ogl.uniform4uiv(loc, 1, &values),
                                else => return error.BadUniformLength,
                            }
                        },
                    }
                },
                .float => {
                    const values: [4]f32 = .{
                        @floatCast(slice[0]),
                        if (slice.len > 1) @floatCast(slice[1]) else 0,
                        if (slice.len > 2) @floatCast(slice[2]) else 0,
                        if (slice.len > 3) @floatCast(slice[3]) else 0,
                    };

                    switch (slice.len) {
                        1 => ogl.uniform1fv(loc, 1, &values),
                        2 => ogl.uniform2fv(loc, 1, &values),
                        3 => ogl.uniform3fv(loc, 1, &values),
                        4 => ogl.uniform4fv(loc, 1, &values),
                        else => return error.BadUniformLength,
                    }
                },
                else => {
                    @compileError("Unsupported uniform slice element type");
                },
            }
        },
        else => {
            @compileError("Unsupported uniform type");
        },
    }
}

fn readShader(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const file = try std.Io.Dir.cwd().openFile(engine.io, path, .{});
    defer file.close(engine.io);

    const stat = try file.stat(engine.io);
    if (stat.size == 0) return &.{};

    const buffer = try engine.gpa.alloc(u8, stat.size);
    errdefer allocator.free(buffer);

    _ = try file.readPositionalAll(engine.io, buffer, 0);

    return buffer;
}

fn ensureShaderCompilation(shader: ogl.Shader) !void {
    var success = [_]i32{0};
    ogl.getShaderiv(shader, .compile_status, &success);
    if (success[0] == 1) return;

    var buffer = std.mem.zeroes([512:0]u8);
    _ = ogl.getShaderInfoLog(shader, &buffer);

    std.log.err("Shader compilation error {}: {s}", .{ success[0], buffer });

    return error.ShaderCompilationError;
}

fn ensureProgramLink(program: ogl.Program) !void {
    var success = [_]i32{0};
    ogl.getProgramiv(program, .link_status, &success);
    if (success[0] == 1) return;

    var buffer = std.mem.zeroes([512:0]u8);
    _ = ogl.getProgramInfoLog(program, &buffer);

    std.log.err("Program link error {}: {s}", .{ success[0], buffer });

    return error.ProgramLinkError;
}
