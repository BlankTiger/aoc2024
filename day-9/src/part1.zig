const std = @import("std");
const assert = std.debug.assert;
const print = std.debug.print;
const mem = std.mem;
const heap = std.heap;
const fmt = std.fmt;

const INPUT = @embedFile("./task.input");

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
    const checksum = calculate_checksum(compressed);
    print("checksum: {d}\n", .{checksum});
}

fn write_to_file(path: []const u8, data: []u8) !void {
    const f = try std.fs.cwd().openFile(path, .{.mode = .write_only});
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

    var b_idx: usize = output.len;
    const num_of_non_dots = output.len - mem.count(i64, output, &[_]i64{-1});
    for (0..num_of_non_dots) |f_idx| {
        if (output[f_idx] != -1) continue;

        for (0..b_idx) |rev_b_idx| {
            b_idx = output.len - 1 - rev_b_idx;
            if (output[b_idx] != -1) break;
        }

        output[f_idx] = output[b_idx];
        output[b_idx] = -1;
    }

    return output;
}

fn calculate_checksum(data: []i64) u64 {
    var res: u64 = 0;
    var idx: usize = 0;
    for (data) |n| {
        if (n == -1) continue;
        const num: usize = @intCast(n);
        res += idx * num;
        idx += 1;
    }
    return res;
}
