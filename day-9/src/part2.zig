const std = @import("std");
const assert = std.debug.assert;
const print = std.debug.print;
const mem = std.mem;
const heap = std.heap;
const fmt = std.fmt;

const INPUT = @embedFile("./test.input");

pub fn main() !void {
    var arena_allocator = heap.ArenaAllocator.init(heap.page_allocator);
    const allocator = arena_allocator.allocator();
    defer {
        print("\nused memory: {d} KB\n", .{arena_allocator.queryCapacity() / 1000});
        // assert(arena_allocator.reset(.free_all));
    }
    // 1. load the compressed representation
    // 2. build uncompressed representation
    // 3. fold data from the right to empty spaces from the left
    // 4. at the end, sum results of multiplication of data by the index of that data to create a checksum
    const input = try allocator.dupe(u8, INPUT);
    const uncompacted = try uncompact(allocator, input);
    const compressed = try compress(allocator, uncompacted);
    try write_to_file("dbgzig.txt", try to_text(allocator, compressed));
    const checksum = calculate_checksum(compressed);
    print("{d}\n", .{checksum});
}

fn to_text(allocator: mem.Allocator, data: []i64) ![]u8 {
    var res = std.ArrayList(u8).init(allocator);
    for (data) |num| {
        if (num == -1) try res.append('.') else try res.appendSlice(try fmt.allocPrint(allocator, "{d}", .{num}));
    }
    return res.toOwnedSlice();
}

fn write_to_file(path: []const u8, data: []u8) !void {
    const f = try std.fs.cwd().createFile(path, .{});
    defer f.close();
    _ = try f.writer().write(data);
}

fn uncompact(allocator: mem.Allocator, data: []u8) ![]i64 {
    var output = std.ArrayList(i64).init(allocator);
    for (data, 0..) |c, idx| {
        if (c == '\n') continue;
        var char_buf = [_]u8{c};
        const count = try fmt.parseInt(usize, &char_buf, 10);
        if (try std.math.mod(usize, idx, 2) == 0) {
            // filled space
            const id: i64 = @intCast(idx / 2);
            for (0..count) |_| try output.append(id);
        } else {
            // empty space
            try output.appendNTimes(-1, count);
        }
    }
    return output.toOwnedSlice();
}

fn compress(allocator: mem.Allocator, data: []i64) ![]i64 {
    var output = try allocator.dupe(i64, data);

    var idx_empty: usize = 0;
    var idx_file: usize = output.len - 1;
    var file_buf = std.ArrayList(i64).init(allocator);
    var file_buf_from: usize = 0;
    var available_space: usize = 0;
    var available_from: usize = 0;
    var sufficient_space_found = false;
    var untouchable = std.AutoHashMap(usize, void).init(allocator);
    var tried_to_move = std.AutoHashMap(i64, void).init(allocator);
    for (0..output.len) |_| {
        defer {
            print("idx_empty: {d}\n", .{idx_empty});
            const i64_idx_empty: i64 = @intCast(idx_empty);
            print("{any}\n", .{output[@max(i64_idx_empty-20, 0)..@min(idx_empty+20, output.len - 1)]});
            idx_empty = 0;
            available_space = 0;
            available_from = 0;
            sufficient_space_found = false;
            file_buf.clearRetainingCapacity();
            file_buf_from = 0;
            // idx_file = output.len - 1;
            print("idx_file: {d}\n", .{idx_file});
            const i64_idx_file: i64 = @intCast(idx_file);
            print("{any}\n", .{output[@max(i64_idx_file, 0)..@min(idx_file+20, output.len - 1)]});
        }

        // find file from the right
        {
            var id: i64 = -1;
            for (0..idx_file) |_| {
                idx_file -= 1;
                id = output[idx_file];
                if (id != -1 and !tried_to_move.contains(id)) break;
            }
            if (idx_file == 0) break;
            try file_buf.append(output[idx_file]);
            if (idx_file + 1 < output.len) {
                if (output[idx_file+1] == file_buf.items[0]) {
                    while (idx_file < output.len - 1 and output[idx_file] == file_buf.items[0]) {
                        idx_file += 1;
                    }
                }
            }
            if (idx_file + 2 < output.len) {
                print("before start of file at idx: {d} -> {d}\n", .{idx_file+2, output[idx_file+2]});
                print("before start of file at idx: {d} -> {d}\n", .{idx_file+1, output[idx_file+1]});
            }
            print("start of file at idx: {d} -> {d}\n", .{idx_file, output[idx_file]});
            try tried_to_move.put(id, {});
            print("already tried to move: ", .{});
            var it = tried_to_move.keyIterator();
            while (it.next()) |k| print("{d} ", .{k.*});
            print("\n", .{});
            idx_file -= 1;
            while (idx_file > 0 and output[idx_file] == file_buf.items[0]) {
                print("file continues at idx: {d} -> {d}\n", .{idx_file, output[idx_file]});
                try file_buf.append(output[idx_file]);
                idx_file -= 1;
            }
            print("file stops at idx: {d} -> {d}\n", .{idx_file, output[idx_file]});
            idx_file += 1;
            file_buf_from = idx_file;
            if (untouchable.contains(file_buf_from)) continue;
            print("file {any}\n", .{file_buf.items});
        }

        // find sufficient space from the left
        while (idx_empty < idx_file) {
            if (output[idx_empty] == -1) {
                available_from = idx_empty;
                available_space = 1;
                idx_empty += 1;
                while (idx_empty < output.len and output[idx_empty] == -1) {
                    available_space += 1;
                    idx_empty += 1;
                }
                if (available_space >= file_buf.items.len) {
                    sufficient_space_found = true;
                    break;
                }
            } else {
                idx_empty += 1;
            }
        }

        if (sufficient_space_found) {
            assert(file_buf_from > available_from);
            print("found empty {any}\n", .{output[available_from..available_from+available_space]}); for (output[available_from..available_from+available_space]) |d| assert(d == -1);
            const dest_file = output[available_from..available_from+file_buf.items.len];
            try untouchable.put(available_from, {});
            const dest_empty = output[file_buf_from..file_buf_from+file_buf.items.len];
            @memcpy(dest_file, file_buf.items);
            @memset(dest_empty, -1);
        } else {
            // idx_file += file_buf.items.len + 1;
            print("file_idx: {d}\n", .{idx_file});
        }
    }

    return output;
}

fn calculate_checksum(data: []i64) u64 {
    var res: u64 = 0;
    var idx: usize = 0;
    for (data) |n| {
        defer idx += 1;
        if (n == -1) continue;
        const num: usize = @intCast(n);
        res += idx * num;
    }
    return res;
}
