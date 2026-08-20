const zopengl = @import("zopengl");
const std = @import("std");
const glfw = @import("zglfw");
const engine = @import("../../engine.zig");
const ogl = zopengl.wrapper;
const zm = @import("zmath");
const ai = @import("assimp");
const zstbi = @import("zstbi");

const Self = @This();

models: std.array_hash_map.Auto(u64, *engine.Model) = .empty,
next_handle: std.atomic.Value(u64) = .init(0),

pub fn init() Self {
    return .{};
}

pub fn deinit(self: *Self) void {
    defer self.* = undefined;

    var it = self.models.iterator();
    // for (self.textures.items) |*texture| {
    //     ogl.deleteTexture(&texture.id);
    // }

    while (it.next()) |entry| {
        engine.gpa.destroy(entry.value_ptr.*);
    }
    self.models.deinit(engine.gpa);
}

pub fn load(self: *Self, path: []const u8) !void {
    var importer = ai.Importer.init(engine.gpa);
    defer importer.deinit();

    const c_path: [:0]const u8 = try engine.gpa.dupeSentinel(u8, path, 0);
    defer engine.gpa.free(c_path);

    var profiler = engine.utils.SimpleProfiler.start();

    const scene = importer.importFile(c_path, .{
        .triangulate = true,
        .gen_normals = true,
        .gen_uv_coords = true,
        .calc_tangent_space = true,
        .flip_uvs = true,
        .optimize_meshes = true,
        .optimize_graph = true,
    }) catch |err| {
        std.log.err("Import error: {s}", .{ai.Importer.getErrorString()});
        return err;
    };

    defer importer.releaseScene();

    profiler.logCheckpointUpdated("Assimp import");

    const root_ai_node = scene.mRootNode orelse return error.NoRootNode;

    const dir = try engine.gpa.dupe(
        u8,
        std.fs.path.dirname(path) orelse "",
    );

    var model = try engine.gpa.create(engine.Model);
    model.* = engine.Model{
        .textures_cache = .init(engine.gpa),
        .dir = dir,
    };
    errdefer model.deinit();

    try loadMaterials(model, scene);
    profiler.logCheckpointUpdated("Materials loaded");

    try loadMeshes(model, scene);
    profiler.logCheckpointUpdated("Meshes loaded");

    model.root = try parseNode(model, root_ai_node);

    self.models.putNoClobber(engine.gpa, self.next_handle.load(.acq_rel), model);
    self.next_handle.fetchAdd(1, .acq_rel);
}

fn parseNode(
    model: *engine.Model,
    ai_node: *const ai.aiNode,
) !engine.Node {
    const name = try engine.gpa.dupe(
        u8,
        ai_node.mName.toSlice(),
    );
    errdefer engine.gpa.free(name);

    var node = try engine.Node.init(
        name,
        aiMatToZmMat(ai_node.mTransformation),
    );
    errdefer node.deinit();

    for (ai.nodeMeshIndices(ai_node)) |source_mesh_index| {
        const mesh_index: usize = @intCast(source_mesh_index);

        if (mesh_index >= model.meshes.items.len) {
            return error.InvalidMeshIndex;
        }

        try node.mesh_indices.append(
            engine.gpa,
            @intCast(mesh_index),
        );
    }

    for (ai.nodeChildren(ai_node)) |maybe_ai_child| {
        const ai_child = maybe_ai_child orelse return error.NullNode;

        var child = try parseNode(model, ai_child);
        errdefer child.deinit();

        try node.children.append(engine.gpa, child);
    }

    return node;
}

fn loadMaterials(model: *engine.Model, ai_scene: *const ai.aiScene) !void {
    const materials = ai.sceneMaterials(ai_scene);

    try model.materials.ensureTotalCapacity(engine.gpa, materials.len);

    for (materials) |maybe_material| {
        const ai_material = maybe_material orelse return error.NullMaterial;

        var material = try processMaterial(model, ai_material);
        errdefer material.deinit();

        try model.materials.append(engine.gpa, material);
    }
}

fn loadMeshes(model: *engine.Model, ai_scene: *const ai.aiScene) !void {
    const source_meshes = ai.sceneMeshes(ai_scene);

    try model.meshes.ensureTotalCapacity(engine.gpa, source_meshes.len);

    for (source_meshes) |maybe_mesh| {
        const ai_mesh = maybe_mesh orelse return error.NullMesh;

        var mesh = try parseMesh(ai_mesh, ai_scene);
        // try mesh.setup(model.materials);
        errdefer mesh.deinit();

        try model.meshes.append(engine.gpa, mesh);
    }
}

fn parseMesh(
    ai_mesh: *const ai.aiMesh,
    ai_scene: *const ai.aiScene,
) !engine.Mesh {
    const vertices = ai.meshVertices(ai_mesh) orelse return error.MeshHasNoVertices;
    const faces = ai.meshFaces(ai_mesh) orelse return error.MeshHasNoFaces;

    var indices_num: usize = 0;
    for (faces) |face| {
        indices_num += ai.faceIndices(&face).len;
    }

    var mesh = try engine.Mesh.init(.{
        .vertices_num = vertices.len,
        .indices_num = indices_num,
        .material_idx = ai_mesh.mMaterialIndex,
    });

    for (faces) |face| {
        const face_indices = ai.faceIndices(&face);
        mesh.indices.appendSliceAssumeCapacity(face_indices);
    }

    const normals = ai.meshNormals(ai_mesh);
    const tangents = ai.meshTangents(ai_mesh);
    const tex_coords = ai.meshTexCoords(ai_mesh, 0);

    for (vertices, 0..) |v, vertex_index| {
        var vertex: engine.Mesh.Vertex = .{
            .position = .{ v.x, v.y, v.z },
        };

        if (normals) |items| {
            const item = items[vertex_index];
            vertex.normal = .{ item.x, item.y, item.z };
            mesh.features.has_normals = true;
        }

        if (tangents) |items| {
            const item = items[vertex_index];
            vertex.tangent = .{ item.x, item.y, item.z };
            mesh.features.has_tangents = true;
        }

        if (tex_coords) |items| {
            const item = items[vertex_index];
            vertex.tex_coords = .{ item.x, item.y };
            mesh.features.has_uv0 = true;
        }

        try mesh.vertices.append(engine.gpa, vertex);
    }

    const materials = ai.sceneMaterials(ai_scene);
    const material_index: usize = @intCast(ai_mesh.mMaterialIndex);

    mesh.material_idx = if (material_index >= materials.len) null else material_index;

    const mat = ai.sceneMaterials(ai_scene)[ai_mesh.mMaterialIndex].?;
    const props = if (mat.mProperties) |p| p else return mesh;
    for (0..mat.mNumProperties) |i| {
        const prop = if (props[i]) |p| p else continue;
        // ai.getMaterialProperty(mat, prop.mKey, prop.mType, index: c_uint, prop_out: *?*const aiMaterialProperty)
        // const in = if (prop.mType == .Integer) ai.materialGetInteger(mat, try engine.gpa.dupeSentinel(u8, prop.mKey.toSlice(), 0), @intCast(prop.mSemantic), prop.mIndex) else null;
        // const f = if (prop.mType == .Float) ai.materialGetFloat(mat, try engine.gpa.dupeSentinel(u8, prop.mKey.toSlice(), 0), @intCast(prop.mSemantic), prop.mIndex) else null;
        // const s = if (prop.mType == .String) ai.materialGetString(mat, try engine.gpa.dupeSentinel(u8, prop.mKey.toSlice(), 0), @intCast(prop.mSemantic), prop.mIndex) else null;

        const key = std.meta.stringToEnum(engine.Material.AssimpMatKey, prop.mKey.toSlice()) orelse continue;

        switch (key) {
            .@"$mat.name" => {},
            else => {},
        }

        // const F = @Enum(u16, .exhaustive, [], comptime field_values: *const [field_names.len]TagInt)
        // const F = enum {
        //      @ ai.AI_MATKEY_NAME,
        // };
        // switch (prop.mKey.toSlice()) {
        //     ai.AI_MATKEY_NAME => {},
        //     else => {},
        // }
        // switch (prop.mType) {
        //     .Integer => std.log.debug("{s} {d}", .{ prop.mKey.toSlice(), in.? }),
        //     .Float, .Double => std.log.debug("{s} {d}", .{ prop.mKey.toSlice(), f.? }),
        //     .String => std.log.debug("{s} {s}", .{ prop.mKey.toSlice(), s.?.toSlice() }),
        //     else => {},
        // }
    }

    std.log.debug("-------", .{});
    std.log.debug("-------", .{});

    return mesh;
}

fn processMaterial(
    model: *engine.Model,
    ai_material: *const ai.aiMaterial,
) !engine.Material {
    var material = engine.Material.init();

    for (std.enums.values(ai.aiTextureType)) |t_type| {
        const texture_count = ai.getMaterialTextureCount(ai_material, t_type);

        for (0..texture_count) |texture_index| {
            const info = ai.materialGetTextureInfo(
                ai_material,
                t_type,
                @truncate(texture_index),
            ) orelse return error.NullTexture;

            const relative_path = info.path.toSlice();

            if (model.textures_cache.get(relative_path)) |idx| {
                const res = try material.textures.getOrPut(try .fromAssimp(t_type));

                if (!res.found_existing) {
                    res.value_ptr.* = try .initCapacity(engine.gpa, 1);
                }
                res.value_ptr.appendAssumeCapacity(idx);

                continue;
            }

            const full_path = try std.mem.joinZ(
                engine.gpa,
                "/",
                &[_][]const u8{ model.dir, relative_path },
            );
            defer engine.gpa.free(full_path);

            std.log.debug("{s} :: {s}", .{ model.dir, relative_path });
            const texture: engine.Texture = .{
                .id = try bindTexture(full_path),
                .path = info.path.toSlice(),
                .type = try .fromAssimp(t_type),
            };
            errdefer ogl.deleteTexture(&texture.id);

            const owned_key = try engine.gpa.dupe(u8, relative_path);
            errdefer engine.gpa.free(owned_key);

            try model.textures.append(engine.gpa, texture);

            const idx = model.textures.items.len - 1;

            const res = try material.textures.getOrPut(try .fromAssimp(t_type));

            if (!res.found_existing) {
                res.value_ptr.* = try .initCapacity(engine.gpa, 1);
            }
            res.value_ptr.appendAssumeCapacity(idx);

            try model.textures_cache.put(owned_key, idx);
        }
    }

    return material;
}

fn bindTexture(path: [:0]const u8) !ogl.Texture {
    var image = try zstbi.Image.loadFromFile(path, 0);
    defer image.deinit();

    const format: ogl.InternalFormat = switch (image.num_components) {
        1 => .red,
        3 => .rgb,
        4 => .rgba,
        else => return error.UnsupportedImageFormat,
    };

    const pixel_format: ogl.PixelFormat = switch (image.num_components) {
        1 => .red,
        3 => .rgb,
        4 => .rgba,
        else => unreachable,
    };

    var texture_id: ogl.Texture = undefined;
    ogl.genTexture(&texture_id);
    errdefer ogl.deleteTexture(texture_id);

    ogl.bindTexture(.texture_2d, texture_id);

    ogl.texParameteri(.texture_2d, .min_filter, ogl.LINEAR_MIPMAP_LINEAR);
    ogl.texParameteri(.texture_2d, .mag_filter, ogl.LINEAR);
    ogl.texParameteri(.texture_2d, .wrap_s, ogl.REPEAT);
    ogl.texParameteri(.texture_2d, .wrap_t, ogl.REPEAT);

    ogl.pixelStorei(.unpack_alignment, 1);

    ogl.texImage2DFromMemory(
        .texture_2d,
        0,
        format,
        image.width,
        image.height,
        pixel_format,
        .unsigned_byte,
        image.data.ptr,
    );

    ogl.generateMipmap(.texture_2d);

    return texture_id;
}

fn aiMatToZmMat(ai_mat: ai.aiMatrix4x4) zm.Mat {
    return .{
        .{ ai_mat.a1, ai_mat.b1, ai_mat.c1, ai_mat.d1 },
        .{ ai_mat.a2, ai_mat.b2, ai_mat.c2, ai_mat.d2 },
        .{ ai_mat.a3, ai_mat.b3, ai_mat.c3, ai_mat.d3 },
        .{ ai_mat.a4, ai_mat.b4, ai_mat.c4, ai_mat.d4 },
    };
}

pub fn bindModelAssets(model: *engine.Model) !void {
    const materials = model.materials.items;

    for (model.meshes.items) |*mesh| {
        if (mesh.cleared) return error.SetupCalledTwice;

        ogl.genVertexArray(&mesh.vao);
        ogl.genBuffer(&mesh.vbo);
        ogl.genBuffer(&mesh.ebo);

        const stride = @sizeOf(engine.Mesh.Vertex);

        ogl.bindVertexArray(mesh.vao);

        ogl.bindBuffer(.array_buffer, mesh.vbo);
        ogl.bufferData(.array_buffer, std.mem.sliceAsBytes(mesh.vertices.items), .static_draw);

        ogl.bindBuffer(.element_array_buffer, mesh.ebo);
        ogl.bufferData(.element_array_buffer, std.mem.sliceAsBytes(mesh.indices.items), .static_draw);

        ogl.vertexAttribPointer(@enumFromInt(0), .three, .float, false, stride, @offsetOf(engine.Mesh.Vertex, "position"));
        ogl.enableVertexAttribArray(@enumFromInt(0));

        ogl.vertexAttribPointer(@enumFromInt(1), .three, .float, false, stride, @offsetOf(engine.Mesh.Vertex, "normal"));
        ogl.enableVertexAttribArray(@enumFromInt(1));

        ogl.vertexAttribPointer(@enumFromInt(2), .two, .float, false, stride, @offsetOf(engine.Mesh.Vertex, "tex_coords"));
        ogl.enableVertexAttribArray(@enumFromInt(2));

        ogl.vertexAttribPointer(@enumFromInt(3), .three, .float, false, stride, @offsetOf(engine.Mesh.Vertex, "tangent"));
        ogl.enableVertexAttribArray(@enumFromInt(3));

        ogl.bindVertexArray(.invalid);

        const material = if (mesh.material_idx != null and mesh.material_idx.? < materials.len) &materials[mesh.material_idx.?] else &mesh.fallback_material;

        const defines = try mesh.features.makeShaderDefines(material);
        defer engine.gpa.free(defines);

        mesh.shader = try engine.Singletone.ShadersMap.getForce(&.{
            .vertex = .{
                .path = "shaders/vertex.glsl",
                .defines = defines,
            },
            .fragment = .{
                .path = "shaders/fragment.glsl",
                .defines = defines,
            },
        });

        mesh.vertices.deinit(engine.gpa);
        mesh.indices_count = mesh.indices.items.len;
        mesh.indices.deinit(engine.gpa);

        mesh.cleared = true;
    }
}

test {
    std.testing.refAllDecls(Self);
}
