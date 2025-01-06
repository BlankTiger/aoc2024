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
    const uncompackted = try uncompact(allocator, input);
    print("{s}\n", .{uncompackted});
    const compressed = try compress(allocator, uncompackted);
    print("{s}\n", .{compressed});
    // const checksum = calculate_checksum(compressed);
    // print("checksum: {d}\n", .{checksum});
}

fn uncompact(allocator: mem.Allocator, data: []u8) ![]u8 {
    var output = std.ArrayList(u8).init(allocator);
    for (data, 0..) |c, idx| {
        if (c == '\n') continue;
        const char_buf = [_]u8{c};
        const count = try fmt.parseInt(usize, &char_buf, 10);
        if (try std.math.mod(usize, idx, 2) == 0) {
            // filled space
            const id = idx / 2;
            const num = try fmt.allocPrint(allocator, "{d}", .{id});
            for (0..count) |_| {
                try output.appendSlice(num);
            }
        } else {
            // empty space
            try output.appendNTimes('.', count);
        }
    }
    return output.toOwnedSlice();
}

fn compress(allocator: mem.Allocator, data: []u8) ![]u8 {
    var output = try allocator.dupe(u8, data);
    for (data) |c| {
    }
    return output;
}

// fn calculate_checksum(data: []u8) u64 {
//     var res: u64 = 0;
//     for (data) |c| {
//     }
//     return res;
// }
