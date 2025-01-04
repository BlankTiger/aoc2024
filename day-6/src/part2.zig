const std = @import("std");
const print = std.debug.print;
const assert = std.debug.assert;

const GUARD = '^';
const OBSTACLE = '#';
const PATH = '.';

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

    /// for casting to int
    fn cast(self: *const Self, T: type) struct { x: T, y: T } {
        const x: T = @intCast(self.x);
        const y: T = @intCast(self.y);
        return .{ .x = x, .y = y };
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
    lines: [][]u8,
    debug: bool = false,

    const Self = @This();

    fn init(lines: [][]u8) Self {
        return Self {
            .lines = lines,
        };
    }

    fn print_m(self: *const Self) void {
        for (self.lines) |l| {
            print("{s}\n", .{l});
        }
    }

    fn get(self: *const Self, pos: Vec2) ?u8 {
        if (pos.x >= x_len or pos.y >= y_len or pos.x < 0 or pos.y < 0) return null;
        const p = pos.cast(usize);
        return self.lines[p.y][p.x];
    }

    fn set_obstacle_at(self: *Self, pos: *Vec2) void {
        const p = pos.cast(usize);
        if (self.debug) print("swapping pos ({d}, {d}) for obstacle: {c} -> {c}\n", .{p.x, p.y, self.lines[p.y][p.x], OBSTACLE});
        self.lines[p.y][p.x] = OBSTACLE;
    }

    fn set_path_at(self: *Self, pos: *Vec2) void {
        const p = pos.cast(usize);
        if (self.debug) print("swapping pos for path: {c} -> {c}\n", .{self.lines[p.y][p.x], PATH});
        self.lines[p.y][p.x] = PATH;
    }

    fn set_x_at(self: *Self, pos: *Vec2) void {
        const p = pos.cast(usize);
        self.lines[p.y][p.x] = 'x';
    }
};

const HitObstacle = struct {
    pos: Vec2,
    dir: Direction,

    fn eql(first: []HitObstacle, second: []HitObstacle) bool {
        if (first.len != second.len) return false;
        for (first, second) |f, s| {
            if (!std.meta.eql(f, s)) return false;
        }
        return true;
    }
};

pub fn main() !void {
    print("hello, this is the input (len = {d}): \n{s}\n", .{input.len, input});
    var gpa: std.heap.GeneralPurposeAllocator(.{ .safety = false }) = .init;
    const gpa_alloc = gpa.allocator();
    defer {
        _ = gpa.deinit();
    }

    var map = blk: {
        var input_iter = std.mem.splitSequence(u8, input, "\n");
        var lines = std.ArrayList([]u8).init(gpa_alloc);
        while (input_iter.next()) |l| {
            const line = try gpa_alloc.dupe(u8, l);
            try lines.append(line);
        }
        break :blk Map.init(try lines.toOwnedSlice());
    };

    // NOTE:
    // 1. start inserting obstacles in each guard position that he visits, its a loop if he then:
    //      - doesnt exit the map
    //      - hits all the same obstacles again with the same orientation
    // 2. otherwise keep going until he exits the map
    // 3. count how many possible loops there are
    // 4. keep track of obstacles that were hit and the direction at the moment of the collision

    var obstacles_that_loop_count: u32 = 0;
    var g = Guard { .pos = find_guard_position(&map).? };
    const orig_pos = g.pos;
    const orig_dir = g.dir;
    const unique = try find_normal_path(gpa_alloc, g, map);
    var unique_pos_iter = unique.keyIterator();
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const arena_alloc = arena.allocator();
    defer arena.deinit();
    u_loop: while (unique_pos_iter.next()) |u| {
        defer { _ = arena.reset(.free_all); }

        map.set_obstacle_at(u);
        defer {
            map.set_path_at(u);
            g.pos = orig_pos;
            g.dir = orig_dir;
        }
        const HitObstacleList = std.ArrayList(HitObstacle);
        const HitObstacleMap = std.AutoHashMap(HitObstacle, void);
        var obstacles_hit = HitObstacleList.init(arena_alloc);
        var obstacles_hit_again = HitObstacleList.init(arena_alloc);
        var obstacles_hit_map = HitObstacleMap.init(arena_alloc);

        var delta = g.dir.delta();
        var loop_started = false;
        var first_loop = true;
        while (true) {
            const new_pos = g.pos.add(&delta);
            if (map.get(new_pos) == OBSTACLE) {
                const obst_hit = HitObstacle{ .pos = new_pos, .dir = g.dir };

                if (loop_started) {
                    if (obstacles_hit.items.len < obstacles_hit_again.items.len) {
                        continue :u_loop;
                    } else if (HitObstacle.eql(obstacles_hit.items, obstacles_hit_again.items)) {
                        obstacles_that_loop_count += 1;
                        continue :u_loop;
                    } else {
                    }
                }

                if (obstacles_hit.items.len == 0 and obstacles_hit_map.contains(obst_hit)) {
                    loop_started = true;
                    try obstacles_hit.append(obst_hit);
                } else if (loop_started and first_loop and std.meta.eql(obstacles_hit.items[0], obst_hit)) {
                    first_loop = false;
                    try obstacles_hit_again.append(obst_hit);
                } else if (loop_started and first_loop) {
                    try obstacles_hit.append(obst_hit);
                } else if (loop_started and !first_loop) {
                    try obstacles_hit_again.append(obst_hit);
                } else {
                    try obstacles_hit_map.put(obst_hit, {});
                }
                g.rotate_90deg();
                delta = g.dir.delta();

            } else if (map.get(new_pos) == null) {
                continue :u_loop;
            } else {
                g.pos = new_pos;
            }
        }
    }

    print("obstacles_that_loop_count: {d}\n", .{obstacles_that_loop_count});
}

fn find_normal_path(alloc: std.mem.Allocator, guard: Guard, map: Map) !std.AutoHashMap(Vec2, void) {
    var g = guard;
    var unique = std.AutoHashMap(Vec2, void).init(alloc);
    var inbounds = true;
    var delta = g.dir.delta();
    var count: u32 = 0;
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
    return unique;
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
