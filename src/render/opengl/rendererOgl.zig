const zopengl = @import("zopengl");
const std = @import("std");
const glfw = @import("zglfw");
const engine = @import("../../engine.zig");
const ogl = zopengl.wrapper;
const zm = @import("zmath");

const Self = @This();

pub fn init() Self {
    return .{};
}

pub fn deinit(self: *Self) void {
    _ = self; // autofix
}

pub fn setup(self: *Self) !void {
    _ = self; // autofix

    try zopengl.loadCoreProfile(
        glfw.getProcAddress,
        engine.Singletone.Window.gl_version_major,
        engine.Singletone.Window.gl_version_minor,
    );

    ogl.enable(.depth_test);
    ogl.enable(.stencil_test);
    ogl.enable(.cull_face);

    std.log.info("{s}", .{ogl.getString(.version).?});
}

pub fn render(self: *Self, model: *const engine.Model) !void {
    _ = self; // autofix

    const root_node = model.root orelse return error.NoModelRootNode;
    try renderNodeOfModel(&root_node, model, zm.identity());
}

fn renderNodeOfModel(
    node: *const engine.Node,
    model: *const engine.Model,
    parent_world: zm.Mat,
) !void {
    const world: zm.Mat = zm.mul(parent_world, node.local_transform);

    for (node.mesh_indices.items) |mesh_index| {
        const mesh: *engine.Mesh = @constCast(&model.meshes.items[mesh_index]);
        try drawMesh(mesh, world, &model.materials, &model.textures);
    }

    for (node.children.items) |*child| {
        try renderNodeOfModel(child, model, world);
    }
}

fn drawMesh(
    mesh: *const engine.Mesh,
    world: zm.Mat,
    materials: *const std.ArrayList(engine.Material),
    textures: *const std.ArrayList(engine.Texture),
) !void {
    if (mesh.indices.items.len == 0) return;

    const material = if (mesh.material_idx != null and mesh.material_idx.? < materials.items.len) &materials.items[mesh.material_idx.?] else &mesh.fallback_material;

    var texture_count: u32 = 0;

    var it = material.textures.iterator();
    while (it.next()) |entry| {
        const texture_type = entry.key_ptr.*;
        const texture_indices = entry.value_ptr.*;

        if (texture_indices.items.len == 0) continue;
        if (texture_count >= 32) break;

        const texture_idx = texture_indices.items[0];

        ogl.activeTexture(@enumFromInt(@intFromEnum(ogl.TextureUnit.texture_0) + texture_count));
        ogl.bindTexture(.texture_2d, textures.items[texture_idx].id);

        const uniform_name = texture_type.toString(engine.gpa);
        defer engine.gpa.free(uniform_name);

        try mesh.shader.setUniform(uniform_name, @as(i32, @intCast(texture_count)));

        texture_count += 1;
    }

    try mesh.shader.setUniform("u_model", world);
    try mesh.shader.setUniform("u_view", engine.camera.world_to_view);
    try mesh.shader.setUniform("u_proj", engine.camera.view_to_clip);

    try mesh.shader.setUniform("u_base_color_factor", material.base_color_factor);
    try mesh.shader.setUniform("u_specular_factor", material.specular_factor);
    try mesh.shader.setUniform("u_shininess", material.shininess);

    try mesh.shader.setUniform("u_light_pos", [_]f32{ -2, 0, 0 });
    try mesh.shader.setUniform("u_light_color", [_]f32{ 1, 1, 1 });
    try mesh.shader.setUniform("u_ambient_color", [_]f32{ 0.0, 0, 0 });

    ogl.bindVertexArray(mesh.vao);

    ogl.drawElements(
        .triangles,
        @intCast(mesh.indices_count),
        .unsigned_int,
        0,
    );

    ogl.bindVertexArray(.invalid);
}

test {
    std.testing.refAllDecls(Self);
}
