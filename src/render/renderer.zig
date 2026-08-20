const std = @import("std");
const utils = @import("../utils/utils.zig");
const Interface = @import("interface").Interface;
const engine = @import("../engine.zig");

pub const Renderer = Interface(.{
    .setup = fn () anyerror!void,
    .render = fn (*const engine.Model) anyerror!void,
    .deinit = fn () void,
}, null);

// const Self = @This();

// pub const R = utils.interfaceFrom(Self);

pub const impls = struct {
    pub const RendererOgl = @import("./opengl/rendererOgl.zig");
    pub const RendererVk = @import("./vulkan/RendererVk.zig");
};

// impl: *anyopaque,
// vtable: *const VTable,

// const VTable = struct {
//     setup: *const fn (*anyopaque) anyerror!void,
//     render: *const fn (*anyopaque, *const engine.Model) anyerror!void,
//     deinit: *const fn (*anyopaque) void,
// };

// pub fn implBy(impl_obj: anytype) Self {
//     const delegate = Delegate(impl_obj);
//     const vtable = VTable{
//         .setup = delegate.setup,
//         .render = delegate.render,
//         .deinit = delegate.deinit,
//     };

//     return .{
//         .impl = @constCast(impl_obj),
//         .vtable = &vtable,
//     };
// }

// pub fn setup(self: *Self) !void {
//     try self.vtable.setup(self.impl);
// }

// pub fn render(self: *Self, model: *const engine.Model) !void {
//     try self.vtable.render(self.impl, model);
// }

// pub fn deinit(self: *Self) void {
//     self.vtable.deinit(self.impl);
// }

// inline fn Delegate(impl_obj: anytype) type {
//     const ImplType = @TypeOf(impl_obj);

//     return struct {
//         fn setup(impl: *anyopaque) !void {
//             try @constCast(TPtr(ImplType, impl)).setup();
//         }

//         fn render(impl: *anyopaque, model: *const engine.Model) !void {
//             try @constCast(TPtr(ImplType, impl)).render(model);
//         }

//         fn deinit(impl: *anyopaque) void {
//             @constCast(TPtr(ImplType, impl)).deinit();
//         }
//     };
// }

// fn TPtr(T: type, opaque_ptr: *anyopaque) T {
//     return @as(T, @ptrCast(@alignCast(opaque_ptr)));
// }

// test {
//     std.testing.refAllDecls(Self);
// }
