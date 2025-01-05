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
    const holes = @as(u64, nums.len - 1);
    const operations_max = std.math.pow(u64, 3, holes);

    for (0..operations_max) |operations| {
        var running_res: u64 = nums[0];
        const formatted = try number_to_base(allocator, operations, 3);
        for (0..holes) |idx| {
            const op_idx = if (idx < formatted.len) formatted[formatted.len - idx - 1] else '0';
            const op: *const fn(u64, u64) u64 = switch (op_idx) {
                '0' => add,
                '1' => multiply,
                '2' => concat,
                else => {
                    print("invalid op_idx: {c}\n", .{op_idx});
                    print("formatted: {s}\n", .{formatted});
                    unreachable;
                },
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
fn concat(a: u64, b: u64) u64 {
    var buf: [200]u8 = undefined;
    const res = fmt.bufPrint(buf[0..], "{d}{d}", .{a, b}) catch unreachable;
    return fmt.parseInt(u64, res, 10) catch unreachable;
}

fn number_to_base(allocator: mem.Allocator, num: u64, base: u64) ![]u8 {
    var buf = std.ArrayList(u8).init(allocator);
    if (num == 0) {
        try buf.append('0');
        return buf.toOwnedSlice();
    }

    var n = num;
    while (n > 0) {
        const res = try std.math.mod(u64, n, base);
        const res_str = try fmt.allocPrint(allocator, "{d}", .{res});
        try buf.appendSlice(res_str);
        n = n / base;
    }
    mem.reverse(u8, buf.items);
    return buf.toOwnedSlice();
}
