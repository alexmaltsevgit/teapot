const std = @import("std");

const zm = @import("zmath");
const zopengl = @import("zopengl");
const ogl = zopengl.wrapper;

const engine = @import("../engine.zig");

const Self = @This();

pub const MeshFeatures = packed struct(u8) {
    has_normals: bool = false,
    has_uv0: bool = false,
    has_tangents: bool = false,

    _padding: u5 = 0,

    pub fn makeShaderDefines(self: *@This(), material: *const engine.Material) ![]const []const u8 {
        var out = try std.ArrayList([]const u8).initCapacity(engine.gpa, 3);

        if (self.has_normals) try out.append(engine.gpa, "HAS_NORMALS");
        if (self.has_uv0) try out.append(engine.gpa, "HAS_UV0");
        if (self.has_tangents) try out.append(engine.gpa, "HAS_TANGENTS");

        if (hasTexture(material, .diffuse)) try out.append(engine.gpa, "HAS_DIFFUSE");
        if (hasTexture(material, .specular)) try out.append(engine.gpa, "HAS_SPECULAR");
        if (hasTexture(material, .ambient)) try out.append(engine.gpa, "HAS_AMBIENT");
        if (hasTexture(material, .emissive)) try out.append(engine.gpa, "HAS_EMISSIVE");
        if (hasTexture(material, .opacity)) try out.append(engine.gpa, "HAS_OPACITY");
        if (hasTexture(material, .normals)) try out.append(engine.gpa, "HAS_NORMALS");

        return out.toOwnedSlice(engine.gpa);
    }

    pub fn hasTexture(material: *const engine.Material, t: engine.Texture.Type) bool {
        return material.textures.contains(t);
    }
};

pub const Vertex = extern struct {
    position: [3]f32,
    normal: [3]f32 = .{ 0, 0, 0 },
    tex_coords: [2]f32 = .{ 0, 0 },
    tangent: [3]f32 = .{ 0, 0, 0 },
};

features: MeshFeatures = .{
    .has_normals = false,
    .has_uv0 = false,
    .has_tangents = false,
},

vertices: std.ArrayList(Vertex),
indices: std.ArrayList(u32),

material_idx: ?usize,
fallback_material: engine.Material,

vao: ogl.VertexArray = undefined,
vbo: ogl.Buffer = undefined,
ebo: ogl.Buffer = undefined,

shader: *engine.ShaderProgram = undefined,
camera: *const engine.Camera = undefined,

// have we cleared vertices and indices after setup?
cleared: bool = false,
// save indices count after clear
indices_count: usize = undefined,

pub fn init(opts: struct { vertices_num: usize = 0, indices_num: usize = 0, material_idx: ?usize = null }) !Self {
    return .{
        .vertices = try .initCapacity(engine.gpa, opts.vertices_num),
        .indices = try .initCapacity(engine.gpa, opts.indices_num),
        .material_idx = opts.material_idx,
        // optimize by reusing material instead of initializing new on every new mesh
        .fallback_material = engine.Material.init(),
    };
}

pub fn setup(
    self: *Self,
    materials: std.MultiArrayList(engine.Material).Slice,
) !void {
    if (self.cleared) return error.SetupCalledTwice;

    ogl.genVertexArray(&self.vao);
    ogl.genBuffer(&self.vbo);
    ogl.genBuffer(&self.ebo);

    const stride = @sizeOf(Vertex);

    ogl.bindVertexArray(self.vao);

    ogl.bindBuffer(.array_buffer, self.vbo);
    ogl.bufferData(.array_buffer, std.mem.sliceAsBytes(self.vertices.items), .static_draw);

    ogl.bindBuffer(.element_array_buffer, self.ebo);
    ogl.bufferData(.element_array_buffer, std.mem.sliceAsBytes(self.indices.items), .static_draw);

    ogl.vertexAttribPointer(@enumFromInt(0), .three, .float, false, stride, @offsetOf(Vertex, "position"));
    ogl.enableVertexAttribArray(@enumFromInt(0));

    ogl.vertexAttribPointer(@enumFromInt(1), .three, .float, false, stride, @offsetOf(Vertex, "normal"));
    ogl.enableVertexAttribArray(@enumFromInt(1));

    ogl.vertexAttribPointer(@enumFromInt(2), .two, .float, false, stride, @offsetOf(Vertex, "tex_coords"));
    ogl.enableVertexAttribArray(@enumFromInt(2));

    ogl.vertexAttribPointer(@enumFromInt(3), .three, .float, false, stride, @offsetOf(Vertex, "tangent"));
    ogl.enableVertexAttribArray(@enumFromInt(3));

    ogl.bindVertexArray(.invalid);

    const material = if (self.material_idx != null and self.material_idx.? < materials.len) &materials.get(self.material_idx.?) else &self.fallback_material;

    const defines = try self.features.makeShaderDefines(material);
    defer engine.gpa.free(defines);

    self.shader = try engine.Singletone.ShadersMap.getForce(&.{
        .vertex = .{
            .path = "shaders/vertex.glsl",
            .defines = defines,
        },
        .fragment = .{
            .path = "shaders/fragment.glsl",
            .defines = defines,
        },
    });

    self.vertices.deinit(engine.gpa);
    self.indices_count = self.indices.items.len;
    self.indices.deinit(engine.gpa);

    self.cleared = true;
}

pub fn deinit(self: *Self) void {
    ogl.deleteVertexArray(&self.vao);
    ogl.deleteBuffer(&self.vbo);
    ogl.deleteBuffer(&self.ebo);

    if (!self.cleared) {
        self.vertices.deinit(engine.gpa);
        self.indices.deinit(engine.gpa);
    }
}

pub fn draw(
    self: *Self,
    world: zm.Mat,
    materials: std.MultiArrayList(engine.Material).Slice,
    textures: std.MultiArrayList(engine.Texture).Slice,
) !void {
    if (self.indices.items.len == 0) return;

    const material = if (self.material_idx != null and self.material_idx.? < materials.len) &materials.get(self.material_idx.?) else &self.fallback_material;

    var texture_count: u32 = 0;

    var it = material.textures.iterator();
    while (it.next()) |entry| {
        const texture_type = entry.key_ptr.*;
        const texture_indices = entry.value_ptr.*;

        if (texture_indices.items.len == 0) continue;
        if (texture_count >= 32) break;

        const texture_idx = texture_indices.items[0];

        ogl.activeTexture(@enumFromInt(@intFromEnum(ogl.TextureUnit.texture_0) + texture_count));
        ogl.bindTexture(.texture_2d, textures.get(texture_idx).id);

        const uniform_name = texture_type.toString(engine.gpa);
        defer engine.gpa.free(uniform_name);

        try self.shader.setUniform(uniform_name, @as(i32, @intCast(texture_count)));

        texture_count += 1;
    }

    try self.shader.setUniform("u_model", world);
    try self.shader.setUniform("u_view", engine.camera.world_to_view);
    try self.shader.setUniform("u_proj", engine.camera.view_to_clip);

    try self.shader.setUniform("u_base_color_factor", material.base_color_factor);
    try self.shader.setUniform("u_specular_factor", material.specular_factor);
    try self.shader.setUniform("u_shininess", material.shininess);

    try self.shader.setUniform("u_light_pos", [_]f32{ -2, 0, 0 });
    try self.shader.setUniform("u_light_color", [_]f32{ 1, 1, 1 });
    try self.shader.setUniform("u_ambient_color", [_]f32{ 0.0, 0, 0 });

    ogl.bindVertexArray(self.vao);

    ogl.drawElements(
        .triangles,
        @intCast(self.indices_count),
        .unsigned_int,
        0,
    );

    ogl.bindVertexArray(.invalid);
}

test {
    std.testing.refAllDecls(Self);
}
