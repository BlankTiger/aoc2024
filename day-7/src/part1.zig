const std = @import("std");
const print = std.debug.print;
const assert = std.debug.assert;
const fmt = std.fmt;
const mem = std.mem;

const INPUT = @embedFile("./task.input");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();

    print("{s}\n\n", .{INPUT});
    var final_sum: u64 = 0;
    var input_iter = mem.splitSequence(u8, INPUT, "\n");
    while (input_iter.next()) |line| {
        defer { _ = arena.reset(.free_all); }
        if (mem.eql(u8, line, "")) continue;
        if (!try validate(allocator, line)) continue;
        const res = try parse_out_res(line);
        final_sum += res;
    }
    print("sum: {d}\n", .{final_sum});
}

fn validate(allocator: mem.Allocator, equation: []const u8) !bool {
    const res = try parse_out_res(equation);
    var eq_iter = mem.splitSequence(u8, equation, " ");
    _ = eq_iter.next().?;
    const nums = try parse_out_nums(allocator, &eq_iter);
    // for (nums) |n| print("num: {d}\n", .{n});
    // have to go over each position and try all combinations,
    // to do that we have to keep track of performed operations
    // at every index (in the beginning all of them can be set to
    // a sum), have to create an array of operations as a key
    //
    // could keep track of operations by looking at a binary representation
    // of a number that's 2^number of places for an operation
    // go in a loop from 0 to that number and looking at the binary representation
    // whenever a digit is one perform * at that index, when it's zero perform
    // an addition
    const holes = @as(u64, nums.len - 1);
    const operations_max = std.math.pow(u64, 2, holes);

    var b: [100]u8 = undefined;
    for (0..operations_max) |operations| {
        var running_res: u64 = nums[0];
        const formatted = try fmt.bufPrint(b[0..], "{b}", .{operations});
        for (0..holes) |idx| {
            const op_idx = if (idx < formatted.len) formatted[formatted.len - idx - 1] else '0';
            const op: *const fn(u64, u64) u64 = switch (op_idx) {
                '0' => add,
                '1' => multiply,
                else => unreachable(),
            };
            running_res = op(running_res, nums[idx+1]);
        }
        if (running_res == res) return true;
    }
    return false;
}

fn parse_out_res(equation: []const u8) !u64 {
    var eq_iter = mem.splitSequence(u8, equation, ":");
    const res_str = eq_iter.next().?;
    const res = try fmt.parseInt(u64, res_str, 10);
    return res;
}

fn parse_out_nums(allocator: mem.Allocator, eq_iter: *mem.SplitIterator(u8, .sequence)) ![]u64 {
    var list = std.ArrayList(u64).init(allocator);
    while (eq_iter.next()) |num| {
        const number = try fmt.parseInt(u64, num, 10);
        try list.append(number);
    }
    return list.toOwnedSlice();
}

fn add(a: u64, b: u64) u64 { return a + b; }
fn multiply(a: u64, b: u64) u64 { return a * b; }
