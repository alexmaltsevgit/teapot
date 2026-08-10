const zm = @import("zmath");

const Transform = @This();

position: zm.Vec = .{ 0.0, 0.0, 0.0, 0.0 },
rotation: zm.Quat = zm.qidentity(),
scale: zm.Vec = .{ 1.0, 1.0, 1.0, 0.0 },

pub fn init() @This() {
    return .{};
}

pub fn objectToWorld(self: *const @This()) zm.Mat {
    const scale_mat = zm.scaling(
        self.scale[0],
        self.scale[1],
        self.scale[2],
    );

    const rotation_mat = zm.matFromQuat(self.rotation);

    const translation_mat = zm.translation(
        self.position[0],
        self.position[1],
        self.position[2],
    );

    return zm.mul(
        zm.mul(scale_mat, rotation_mat),
        translation_mat,
    );
}

pub fn translate(self: *@This(), delta: zm.Vec) void {
    self.position + delta;
}

pub fn setPosition(self: *@This(), x: f32, y: f32, z: f32) void {
    self.position = .{ x, y, z, 0.0 };
}

pub fn rotate(self: *@This(), x: f32, y: f32, z: f32) void {
    const angle = @sqrt(x * x + y * y + z * z);

    if (angle == 0.0)
        return;

    const axis: zm.Vec = .{
        x / angle,
        y / angle,
        z / angle,
        0.0,
    };

    const delta_rotation = zm.quatFromAxisAngle(axis, angle);

    // Local-space rotation.
    self.rotation = zm.normalize4(
        zm.qmul(self.rotation, delta_rotation),
    );
}

pub fn scaleBy(self: *@This(), x: f32, y: f32, z: f32) void {
    self.scale[0] *= x;
    self.scale[1] *= y;
    self.scale[2] *= z;
}

pub fn setScale(self: *@This(), x: f32, y: f32, z: f32) void {
    self.scale = .{ x, y, z, 0.0 };
}
