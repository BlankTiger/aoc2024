const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const heap = std.heap;

const INPUT = @embedFile("./task.input");

pub fn main() !void {
    var arena_allocator = heap.ArenaAllocator.init(heap.page_allocator);
    const allocator = arena_allocator.allocator();
    defer {
        print("\nused mem: {d} KB\n", .{arena_allocator.queryCapacity() / 1000});
        _ = arena_allocator.reset(.free_all);
    }

    // 1. go through every char in input
    // 2. find all frequencies
    // 3. store them
    // 4. find all pairs
    // 5. find delta between pair nodes from one that comes earlier in the input to the other one
    // 6. first antinode = node earlier - delta
    // 7. second antinode = node later + delta

    var map = Map.init(allocator, try allocator.dupe(u8, INPUT));
    print("{s}\n", .{map.input});

    const unique_freqs = try map.find_unique_freqs();
    Map.print_unique_freqs(unique_freqs);
    const combinations = try build_combinations(allocator, unique_freqs);
    print_combinations(combinations);
    const deltas = try calculate_deltas(allocator, combinations);
    print_deltas(deltas);
    const antinodes = try calculate_antinodes(allocator, deltas, map);
    var unique_antinodes = UniquePos.init(allocator);
    for (antinodes) |a| {
        print("{d}, {d}\n", .{a.x, a.y});
        map.set(a, '#');
        try unique_antinodes.put(a, {});
        print("{s}\n", .{map.input});
    }
    print("amount: {d}\n", .{antinodes.len});
    print("unique amount: {d}\n", .{unique_antinodes.count()});
}

fn Vec2(T: type) type {
    return struct {
        x: T,
        y: T,

        const @"type" = T;
        const Self = @This();

        fn find_delta(self: Self, o: Self) Delta {
            const a = self.cast(Delta.@"type");
            const b = o.cast(Delta.@"type");
            return .{ .x = a.x - b.x, .y = a.y - b.y };
        }

        fn sub(self: Self, o: Self) Delta {
            const a = self.cast(Delta.@"type");
            const b = o.cast(Delta.@"type");
            return .{ .x = a.x - b.x, .y = a.y - b.y };
        }

        fn sub_delta(self: Self, d: Delta) Delta {
            const a = self.cast(Delta.@"type");
            return .{ .x = a.x - d.x, .y = a.y - d.y };
        }

        fn add_delta(self: Self, d: Delta) Delta {
            const a = self.cast(Delta.@"type");
            return .{ .x = a.x + d.x, .y = a.y + d.y };
        }

        fn cast(self: Self, NewT: type) Vec2(NewT) {
            const x: NewT = @intCast(self.x);
            const y: NewT = @intCast(self.y);
            return .{ .x = x, .y = y };
        }
    };
}

const Delta = Vec2(isize);
const Pos = Vec2(usize);
const PosList = std.ArrayList(Pos);
const UniquePos = std.AutoHashMap(Pos, void);

const Map = struct {
    allocator: mem.Allocator,
    input: []u8,
    x_lim: usize,
    y_lim: usize,

    const Self = @This();

    fn init(allocator: mem.Allocator, input: []u8) Self {
        const y_lim = mem.count(u8, input, "\n");
        const x_lim = mem.indexOfScalar(u8, input, '\n').?;
        return Self {
            .allocator = allocator,
            .input = input,
            .x_lim = x_lim,
            .y_lim = y_lim,
        };
    }

    const UniqueFreqsWithList = std.AutoHashMap(u8, PosList);
    const UniqueFreqs = std.AutoHashMap(u8, []Pos);

    fn find_unique_freqs(self: Self) !UniqueFreqs {
        var unique_with_list = UniqueFreqsWithList.init(self.allocator);
        for (self.input, 0..) |c, idx| {
            if (c == '\n' or c == '.') continue;

            const pos = try self.calc_pos(idx);
            if (unique_with_list.contains(c)) {
                try unique_with_list.getPtr(c).?.append(pos);
            } else {
                var list = PosList.init(self.allocator);
                try list.append(pos);
                try unique_with_list.put(c, list);
            }
        }

        var unique = UniqueFreqs.init(self.allocator);
        var iter = unique_with_list.iterator();
        while (iter.next()) |e| {
            try unique.put(e.key_ptr.*, try e.value_ptr.toOwnedSlice());
        }
        unique_with_list.deinit();
        return unique;
    }

    fn print_unique_freqs(unique_freqs: UniqueFreqs) void {
        var entry_iter = unique_freqs.iterator();
        while (entry_iter.next()) |e| {
            print("{c} at: [ ", .{e.key_ptr.*});
            for (e.value_ptr.*) |p| {
                print("({d}, {d}) ", .{p.x, p.y});
            }
            print("]\n", .{});
        }
    }

    const SoloAntenas = std.AutoHashMap(Pos, void);

    fn find_solo_antenas(allocator: mem.Allocator, unique_freqs: UniqueFreqs) !SoloAntenas {
        var antenas = SoloAntenas.init(allocator);
        var entry_iter = unique_freqs.iterator();
        while (entry_iter.next()) |e| {
            if (e.value_ptr.len == 1) try antenas.put(e.value_ptr.*[0], {});
        }
        return antenas;
    }

    fn is_antinode_valid(self: Self, pos: Delta) bool {
        if (pos.x < 0 or pos.y < 0) return false;
        if (pos.x >= self.x_lim or pos.y >= self.y_lim) return false;
        const p = pos.cast(usize);
        const c = self.get(p).?;
        if (c == '\n') return false;
        return true;
    }

    fn calc_idx(self: Self, pos: Pos) usize {
        const idx = pos.y * (self.x_lim + 1) + pos.x;
        return idx;
    }

    fn calc_pos(self: Self, idx: usize) !Pos {
        const x = try std.math.mod(usize, idx, self.x_lim + 1);
        const y = idx / (self.x_lim + 1);
        return Pos { .x = x, .y = y };
    }

    fn get(self: Self, pos: Pos) ?u8 {
        const idx = self.calc_idx(pos);
        if (idx > self.input.len) return null;
        return self.input[idx];
    }

    fn set(self: *Self, pos: Pos, value: u8) void {
        const idx = self.calc_idx(pos);
        if (idx > self.input.len) return;
        self.input[idx] = value;
    }
};

const Combination = struct { Pos, Pos };

fn build_combinations(allocator: mem.Allocator, unique_freqs: Map.UniqueFreqs) ![]Combination {
    var list = std.ArrayList(Combination).init(allocator);

    var entry_iter = unique_freqs.iterator();
    while (entry_iter.next()) |e| {
        var offset: usize = 0;
        for (e.value_ptr.*, 0..) |p1, idx| {
            defer offset += 1;

            for (e.value_ptr.*, 0..) |p2, idx2| {
                if (idx2 < offset) continue;
                if (idx == idx2) continue;
                try list.append(.{ p1, p2 });
            }
        }
    }

    return list.toOwnedSlice();
}

fn print_combinations(combinations: []Combination) void {
    for (combinations) |c| print(" [({d}, {d}), ({d}, {d})]", .{c[0].x, c[0].y, c[1].x, c[1].y});
    print("\n", .{});
}

fn sort_combinations(combinations: []Combination) void {
    for (combinations) |*c| {
        if (c[0].y < c[1].y) continue;
        if (c[0].y > c[1].y) {
            mem.swap(Pos, &c[0], &c[1]);
            continue;
        }

        if (c[0].x < c[1].x) continue;
        if (c[0].x > c[1].x) mem.swap(Pos, &c[0], &c[1]);
    }
}

const DeltaMap = std.AutoHashMap(Combination, Delta);

fn calculate_deltas(allocator: mem.Allocator, combinations: []Combination) !DeltaMap {
    var map = DeltaMap.init(allocator);
    for (combinations) |c| {
        const delta = c[1].sub(c[0]);
        try map.put(c, delta);
    }
    return map;
}

fn print_deltas(deltas: DeltaMap) void {
    var d_iter = deltas.iterator();
    while (d_iter.next()) |e| {
        const k = e.key_ptr.*;
        const v = e.value_ptr.*;
        print("({d}, {d});({d}, {d}) = ({d}, {d})\n", .{k[0].x, k[0].y, k[1].x, k[1].y, v.x, v.y});
    }
}

fn calculate_antinodes(allocator: mem.Allocator, deltas: DeltaMap, map: Map) ![]Pos {
    var list = PosList.init(allocator);
    var entry_iter = deltas.iterator();
    while (entry_iter.next()) |e| {
        const combination = e.key_ptr.*;
        const delta = e.value_ptr.*;

        const T = Pos.@"type";
        const antinode_a = combination[0].sub_delta(delta);
        if (map.is_antinode_valid(antinode_a)) try list.append(antinode_a.cast(T));
        const antinode_b = combination[1].add_delta(delta);
        if (map.is_antinode_valid(antinode_b)) try list.append(antinode_b.cast(T));
    }
    return list.toOwnedSlice();
}
