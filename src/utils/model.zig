const std = @import("std");

const ai = @import("assimp");
const zm = @import("zmath");
const zstbi = @import("zstbi");

const engine = @import("../engine.zig");

const Self = @This();

root: ?engine.Node = null,

meshes: std.ArrayList(engine.Mesh) = .empty,
materials: std.ArrayList(engine.Material) = .empty,
textures: std.ArrayList(engine.Texture) = .empty,

transform: engine.Transform = .init(),

textures_cache: std.StringHashMap(usize),
dir: []const u8,

pub fn init() Self {
    // var importer = ai.Importer.init(engine.gpa);
    // defer importer.deinit();

    // const c_path: [:0]const u8 = try engine.gpa.dupeSentinel(u8, path, 0);
    // defer engine.gpa.free(c_path);

    // var profiler = engine.utils.SimpleProfiler.start();

    // const scene = importer.importFile(c_path, .{
    //     .triangulate = true,
    //     .gen_normals = true,
    //     .gen_uv_coords = true,
    //     .calc_tangent_space = true,
    //     .flip_uvs = true,
    //     .optimize_meshes = true,
    //     .optimize_graph = true,
    // }) catch |err| {
    //     std.log.err("Import error: {s}", .{ai.Importer.getErrorString()});
    //     return err;
    // };
    // defer importer.releaseScene();

    // profiler.logCheckpointUpdated("Assimp import");

    // const root_ai_node = scene.mRootNode orelse return error.NoRootNode;

    // const dir = try engine.gpa.dupe(
    //     u8,
    //     std.fs.path.dirname(path) orelse "",
    // );

    // var model: Self = .{
    //     .textures_cache = .init(engine.gpa),
    //     .dir = dir,
    // };
    // errdefer model.deinit();

    // try loadMaterials(&model, scene);
    // profiler.logCheckpointUpdated("Materials loaded");

    // try loadMeshes(&model, scene);
    // profiler.logCheckpointUpdated("Meshes loaded");

    // model.root = try parseNode(&model, root_ai_node);

    // return model;
}

pub fn deinit(self: *Self) void {
    _ = self; // autofix
    // for (self.materials.items) |*material| {
    //     material.deinit();
    // }

    // self.materials.deinit(engine.gpa);

    // for (self.meshes.items) |*mesh| {
    //     mesh.deinit();
    // }

    // self.meshes.deinit(engine.gpa);

    // if (self.root) |*root| {
    //     root.deinit();
    // }

    // var keys = self.textures_cache.keyIterator();
    // while (keys.next()) |key| {
    //     engine.gpa.free(key.*);
    // }

    // self.textures.deinit(engine.gpa);

    // self.textures_cache.deinit();
    // engine.gpa.free(self.dir);

    // self.* = undefined;
}
