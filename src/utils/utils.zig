const std = @import("std");

const engine = @import("../engine.zig");

pub fn EventSource(comptime EventT: type) type {
    return struct {
        const Self = @This();

        const Callback = *const fn (ctx: ?*anyopaque) void;
        const CallbackNode = struct { callback: Callback, ctx: ?*anyopaque, node: std.SinglyLinkedList.Node = .{} };

        allocator: std.mem.Allocator,
        subs: std.AutoHashMap(EventT, std.SinglyLinkedList),

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .allocator = allocator, .subs = std.AutoHashMap(EventT, std.SinglyLinkedList).init(allocator) };
        }

        pub fn deinit(self: *Self) void {
            var value_it = self.subs.valueIterator();
            while (value_it.next()) |value| {
                var current = value.first orelse break;
                while (true) {
                    const maybe_next = current.next;
                    self.allocator.destroy(@as(*CallbackNode, @fieldParentPtr("node", current)));
                    current = maybe_next orelse break;
                }
            }

            self.subs.deinit();
        }

        pub fn on(self: *Self, key: EventT, ctx: ?*anyopaque, callback: Callback) !void {
            const res = try self.subs.getOrPut(key);
            if (!res.found_existing) {
                res.value_ptr.* = .{};
            }

            const cbn: *CallbackNode = try self.allocator.create(CallbackNode);
            cbn.* = .{ .callback = callback, .ctx = ctx };

            res.value_ptr.prepend(&cbn.node);
        }

        pub fn off(self: *Self, key: EventT, callback: Callback) !void {
            const list = self.subs.get(key) orelse return error.ItemNotFound;

            if (!list.first.?) return error.ItemNotFound;

            const first: *CallbackNode = @fieldParentPtr("node", list.first.?);

            if (first.callback == callback) {
                self.allocator.destroy(first);
                list.first = list.first.next;
            } else {
                var node = list.first.?;
                while (node.next) : (node = node.next) {
                    const handler: *CallbackNode = @fieldParentPtr("node", node.next);
                    if (handler.callback != callback) continue;

                    self.allocator.destroy(handler);
                    node.next = node.next.?.next;

                    return;
                }
            }

            return error.ItemNotFound;
        }

        pub fn invoke(self: *Self, key: EventT) void {
            const list = self.subs.get(key);
            if (list == null) return;

            var node = list.?.first;
            while (node != null) : (node = node.?.next) {
                const handler: *CallbackNode = @fieldParentPtr("node", node.?);
                handler.callback(handler.ctx);
            }
        }
    };
}

pub const SimpleProfiler = struct {
    const Self = @This();

    start_time: std.Io.Timestamp,

    pub fn start() Self {
        return .{ .start_time = std.Io.Clock.awake.now(engine.io) };
    }

    pub fn checkpoint(self: *const Self) i64 {
        return self.start_time.untilNow(engine.io, .awake).toMilliseconds();
    }

    pub fn checkpointUpdated(self: *Self) i64 {
        const ms = self.start_time.untilNow(engine.io, .awake).toMilliseconds();
        self.start_time = std.Io.Clock.awake.now(engine.io);
        return ms;
    }

    pub fn logCheckpoint(self: *const Self, hint: []const u8) void {
        std.log.info("[PROFILE] {s}: {d}ms", .{ hint, self.checkpoint() });
    }

    pub fn logCheckpointUpdated(self: *Self, hint: []const u8) void {
        std.log.info("[PROFILE] {s} :: {d}ms", .{ hint, self.checkpointUpdated() });
    }
};
