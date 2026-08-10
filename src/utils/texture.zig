const std = @import("std");

const ai = @import("assimp");
const zopengl = @import("zopengl");
const ogl = zopengl.wrapper;

const engine = @import("../engine.zig");

pub const Self = @This();

pub const Type = enum {
    diffuse,
    specular,
    ambient,
    emissive,
    height,
    normals,
    shininess,
    opacity,
    displacement,
    lightmap,
    reflection,
    base_color,
    normal_camera,
    emission_color,
    metalness,
    diffuse_roughness,
    ambient_occlusion,
    unknown,
    sheen,
    clearcoat,
    transmission,
    maya_base,
    maya_specular,
    maya_specular_color,
    maya_specular_roughness,
    anisotropy,
    gltf_metallic_roughness,

    pub fn toString(self: @This(), allocator: std.mem.Allocator) []const u8 {
        return std.fmt.allocPrint(allocator, "t_{s}", .{@tagName(self)}) catch unreachable;
    }

    pub fn fromAssimp(ai_type: ai.aiTextureType) !@This() {
        const str = try std.ascii.allocLowerString(engine.gpa, std.enums.tagName(ai.aiTextureType, ai_type).?);
        defer engine.gpa.free(str);
        return std.meta.stringToEnum(@This(), str).?;
    }
};

id: ogl.Texture,
type: Type,
path: []const u8,

test {
    std.testing.refAllDecls(Self);
}
