const std = @import("std");

const zm = @import("zmath");
const zopengl = @import("zopengl");
const ai = @import("assimp");
const ogl = zopengl.wrapper;

const engine = @import("../engine.zig");

pub const Self = @This();

pub const AssimpMatKey = @Enum(
    u8,
    .exhaustive,
    &assimp_mat_keys,
    &assimpMatValues(),
);

pub fn assimpMatKeyFromSlice(str: []const u8) !AssimpMatKey {
    std.meta.stringToEnum(AssimpMatKey, str);
}

pub const AlphaMode = enum {
    m_opaque,
    mask,
    blend,
};

name: []const u8 = "",

base_color_factor: [4]f32 = .{
    1.0,
    1.0,
    1.0,
    1.0,
},

specular_factor: f32 = 1.0,
shininess: f32 = 32.0,

textures: std.AutoHashMap(engine.Texture.Type, std.ArrayList(usize)),

alpha_mode: AlphaMode = .m_opaque,
double_sided: bool = false,

pub fn init() Self {
    return .{ .textures = .init(engine.gpa) };
}

pub fn deinit(self: *Self) void {
    engine.gpa.free(self.name);

    var it = self.textures.iterator();
    while (it.next()) |entry| {
        entry.value_ptr.deinit(engine.gpa);
    }

    self.textures.deinit();

    self.* = undefined;
}

const assimp_mat_keys = [_][]const u8{
    ai.types.AI_MATKEY_NAME,
    ai.types.AI_MATKEY_TWOSIDED,
    ai.types.AI_MATKEY_SHADING_MODEL,
    ai.types.AI_MATKEY_ENABLE_WIREFRAME,
    ai.types.AI_MATKEY_BLEND_FUNC,
    ai.types.AI_MATKEY_OPACITY,
    ai.types.AI_MATKEY_TRANSPARENCYFACTOR,
    ai.types.AI_MATKEY_BUMPSCALING,
    ai.types.AI_MATKEY_SHININESS,
    ai.types.AI_MATKEY_REFLECTIVITY,
    ai.types.AI_MATKEY_SHININESS_STRENGTH,
    ai.types.AI_MATKEY_REFRACTI,
    ai.types.AI_MATKEY_COLOR_DIFFUSE,
    ai.types.AI_MATKEY_COLOR_AMBIENT,
    ai.types.AI_MATKEY_COLOR_SPECULAR,
    ai.types.AI_MATKEY_COLOR_EMISSIVE,
    ai.types.AI_MATKEY_COLOR_TRANSPARENT,
    ai.types.AI_MATKEY_COLOR_REFLECTIVE,
    ai.types.AI_MATKEY_GLOBAL_BACKGROUND_IMAGE,
    ai.types.AI_MATKEY_GLOBAL_SHADERLANG,
    ai.types.AI_MATKEY_SHADER_VERTEX,
    ai.types.AI_MATKEY_SHADER_FRAGMENT,
    ai.types.AI_MATKEY_SHADER_GEO,
    ai.types.AI_MATKEY_SHADER_TESSELATION,
    ai.types.AI_MATKEY_SHADER_PRIMITIVE,
    ai.types.AI_MATKEY_SHADER_COMPUTE,
    ai.types.AI_MATKEY_BASE_COLOR,
    ai.types.AI_MATKEY_METALLIC_FACTOR,
    ai.types.AI_MATKEY_ROUGHNESS_FACTOR,
    ai.types.AI_MATKEY_ANISOTROPY_FACTOR,
    ai.types.AI_MATKEY_SPECULAR_FACTOR,
    ai.types.AI_MATKEY_GLOSSINESS_FACTOR,
    ai.types.AI_MATKEY_SHEEN_COLOR_FACTOR,
    ai.types.AI_MATKEY_SHEEN_ROUGHNESS_FACTOR,
    ai.types.AI_MATKEY_CLEARCOAT_FACTOR,
    ai.types.AI_MATKEY_CLEARCOAT_ROUGHNESS_FACTOR,
    ai.types.AI_MATKEY_TRANSMISSION_FACTOR,
    ai.types.AI_MATKEY_VOLUME_THICKNESS_FACTOR,
    ai.types.AI_MATKEY_VOLUME_ATTENUATION_DISTANCE,
    ai.types.AI_MATKEY_VOLUME_ATTENUATION_COLOR,
    ai.types.AI_MATKEY_EMISSIVE_INTENSITY,
    ai.types.AI_MATKEY_USE_COLOR_MAP,
    ai.types.AI_MATKEY_USE_METALLIC_MAP,
    ai.types.AI_MATKEY_USE_ROUGHNESS_MAP,
    ai.types.AI_MATKEY_USE_EMISSIVE_MAP,
    ai.types.AI_MATKEY_USE_AO_MAP,
    ai.types.AI_MATKEY_TEXTURE_BASE,
    ai.types.AI_MATKEY_UVWSRC_BASE,
    ai.types.AI_MATKEY_TEXOP_BASE,
    ai.types.AI_MATKEY_MAPPING_BASE,
    ai.types.AI_MATKEY_TEXBLEND_BASE,
    ai.types.AI_MATKEY_MAPPINGMODE_U_BASE,
    ai.types.AI_MATKEY_MAPPINGMODE_V_BASE,
    ai.types.AI_MATKEY_TEXMAP_AXIS_BASE,
    ai.types.AI_MATKEY_UVTRANSFORM_BASE,
    ai.types.AI_MATKEY_TEXFLAGS_BASE,
    ai.types.AI_MATKEY_ANISOTROPY_ROTATION,
};

fn assimpMatValues() [assimp_mat_keys.len]u8 {
    var buf = [_]u8{0} ** assimp_mat_keys.len;
    inline for (0..assimp_mat_keys.len) |i| {
        buf[i] = i;
    }
    return buf;
}

test {
    std.testing.refAllDecls(Self);
}
