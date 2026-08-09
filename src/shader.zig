const std = @import("std");
const zopengl = @import("zopengl");
const ogl = zopengl.wrapper;
const ctx = @import("ctx.zig");

pub const ShaderProgram = struct {
    id: ogl.Program,
    shaders: std.ArrayList(ogl.Shader),

    pub fn init() !@This() {
        return .{ .id = try ogl.createProgram(), .shaders = try std.ArrayList(ogl.Shader).initCapacity(ctx.gpa(), 4) };
    }

    pub fn deinit(self: *@This()) void {
        for (self.shaders.items) |shader| {
            var params = [_]i32{0};
            ogl.getShaderiv(shader, .delete_status, &params);
            if (params[0] == ogl.TRUE) continue;

            ogl.deleteShader(shader);
        }
        self.shaders.deinit(ctx.gpa());
    }

    pub fn compileShader(self: *@This(), name: []const u8, t: ogl.ShaderType) !void {
        const shader_code = try readShader(ctx.gpa(), name);
        defer ctx.gpa().free(shader_code);

        const shader = try ogl.createShader(t);

        ogl.shaderSourceSingle(shader, shader_code);
        ogl.compileShader(shader);

        try ensureShaderCompilation(shader);

        try self.shaders.append(ctx.gpa(), shader);
    }

    pub fn link(self: *@This()) !void {
        for (self.shaders.items) |shader| {
            ogl.attachShader(self.id, shader);
        }

        ogl.linkProgram(self.id);

        for (self.shaders.items) |shader| {
            ogl.deleteShader(shader);
        }

        try ensureProgramLink(self.id);
    }

    pub fn use(self: *@This()) void {
        ogl.useProgram(self.id);
    }

    pub fn setUniform(self: *@This(), name: [:0]const u8, value: anytype) !void {
        const t = @typeInfo(@TypeOf(value));
        const loc = ogl.getUniformLocation(self.id, name) orelse return error.BadUniformName;

        switch (t) {
            .bool => ogl.uniform1i(loc, @intFromBool(value)),
            .comptime_int => ogl.uniform1i(loc, @intCast(value)),
            .int => |info| switch (info.signedness) {
                .signed => ogl.uniform1i(loc, @intCast(value)),
                .unsigned => ogl.uniform1ui(loc, @intCast(value)),
            },
            .float, .comptime_float => {
                ogl.uniform1f(loc, @floatCast(value));
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
                            2 => ogl.uniform2fv(loc, 1, &values),
                            3 => ogl.uniform3fv(loc, 1, &values),
                            4 => ogl.uniform4fv(loc, 1, &values),
                            1 => ogl.uniform1fv(loc, 1, &values),
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
};

fn readShader(allocator: std.mem.Allocator, name: []const u8) ![]u8 {
    const path = try std.fmt.allocPrint(allocator, "shaders/{s}", .{name});
    defer allocator.free(path);

    const file = try std.Io.Dir.cwd().openFile(ctx.io(), path, .{});
    defer file.close(ctx.io());

    const stat = try file.stat(ctx.io());
    if (stat.size == 0) return &.{};

    const buffer = try ctx.gpa().alloc(u8, stat.size);
    errdefer allocator.free(buffer);

    _ = try file.readPositionalAll(ctx.io(), buffer, 0);

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
