const std = @import("std");
const print = std.debug.print;
const assert = std.debug.assert;

const GUARD = '^';
const OBSTACLE = '#';

/// (x, y)
const Vec2 = struct {
    x: i64,
    y: i64,

    const Self = @This();

    fn init(pos: struct { i64, i64 }) Self {
        return .{ .x = pos[0], .y = pos[1] };
    }

    fn add(self: *const Self, other: *Self) Vec2 {
        return .{ .x = self.x + other.x, .y = self.y + other.y };
    }
};

const Direction = enum {
    LEFT, UP, RIGHT, DOWN,

    const Self = @This();

    fn delta(self: *Self) Vec2 {
        return switch (self.*) {
            Direction.LEFT => Vec2.init(.{ -1, 0 }),
            Direction.UP => Vec2.init(.{ 0, -1 }),
            Direction.RIGHT => Vec2.init(.{ 1, 0 }),
            Direction.DOWN => Vec2.init(.{ 0, 1 }),
        };
    }
};
const Guard = struct {
    pos: Vec2,
    dir: Direction = Direction.UP,

    const Self = @This();

    fn rotate_90deg(self: *Self) void {
        switch (self.dir) {
            Direction.UP => self.dir = Direction.RIGHT,
            Direction.LEFT => self.dir = Direction.UP,
            Direction.RIGHT => self.dir = Direction.DOWN,
            Direction.DOWN => self.dir = Direction.LEFT,
        }
    }
};

const input = @embedFile("task.input");
const y_len = blk: {
    @setEvalBranchQuota(100000);
    break :blk std.mem.count(u8, input, "\n");
};
const x_len = blk: {
    var iter = std.mem.splitSequence(u8, input, "\n");
    break :blk iter.next().?.len;
};

const Map = struct {
    lines: [][]const u8,

    const Self = @This();

    fn init(lines: [][]const u8) Self {
        return Self {
            .lines = lines,
        };
    }

    fn get(self: *const Self, pos: Vec2) ?u8 {
        if (pos.x >= x_len or pos.y >= y_len or pos.x < 0 or pos.y < 0) return null;
        const x: usize = @intCast(pos.x);
        const y: usize = @intCast(pos.y);
        return self.lines[y][x];
    }
};

pub fn main() !void {
    print("hello, this is the input (len = {d}): \n{s}\n", .{input.len, input});
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const alloc = arena.allocator();
    defer arena.deinit();
    defer print("used memory: {d}\n", .{arena.queryCapacity()});


    const map = blk: {
        var input_iter = std.mem.splitSequence(u8, input, "\n");
        var lines = std.ArrayList([]const u8).init(alloc);
        while (input_iter.next()) |l| try lines.append(l);
        break :blk Map.init(try lines.toOwnedSlice());
    };

    var g = Guard { .pos = find_guard_position(&map).? };
    print("guard pos: ({d}, {d})\n", .{g.pos.x, g.pos.y});
    var inbounds = true;
    var delta = g.dir.delta();
    var count: u32 = 0;
    var unique = std.AutoHashMap(Vec2, void).init(alloc);
    while (inbounds) {
        const new_pos = g.pos.add(&delta);
        if (map.get(new_pos) == OBSTACLE) {
            g.rotate_90deg();
            delta = g.dir.delta();
        } else if (map.get(new_pos) == null) {
            inbounds = false;
        } else {
            g.pos = new_pos;
            if (!unique.contains(new_pos)) {
                try unique.put(new_pos, {});
                count += 1;
            }
        }
    }

    print("unique positions: {d}\n", .{count});
}

fn find_guard_position(map: *const Map) ?Vec2 {
    for (0..x_len) |idx_x| {
        for (0..y_len) |idx_y| {
            const x: i64 = @intCast(idx_x);
            const y: i64 = @intCast(idx_y);
            const pos = .{ .x = x, .y = y };
            const c = map.get(pos);
            if (c == GUARD) return pos;
        }
    }
    return null;
}
