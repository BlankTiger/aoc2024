const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const assert = std.debug.assert;

var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
const alloc = general_purpose_allocator.allocator();

const Pair = struct { a: u64, b: u64 };
const PairList = std.ArrayList(Pair);

const IterError = error{
    OutOfRange,
};

const CharIter = struct {
    chars: []const u8,
    curr: u32 = 0,

    fn next(self: *CharIter) ?u8 {
        if (self.chars.len <= self.curr) return null;
        const res = self.chars[self.curr];
        self.curr += 1;
        return res;
    }

    fn peek(self: CharIter, ahead: u32) ?u8 {
        if (self.chars.len <= self.curr + ahead) return null;
        const res = self.chars[self.curr + ahead];
        print("peeking: {c}\n", .{res});
        return res;
    }

    fn advance(self: *CharIter, ahead: u32) IterError!void {
        if (self.chars.len <= self.curr + ahead) return error.OutOfRange;
        self.curr += ahead;
    }
};

const NumParseError = error{
    NoCommaOrClosingParen,
    NoNum,
    EndOfIter,
    OutOfRange,
};

fn parse_num(ch_iter: *CharIter) NumParseError!u16 {
    var next_ch = ch_iter.peek(0) orelse return NumParseError.EndOfIter;
    _ = try ch_iter.advance(1);
    const num_1: u16 = std.fmt.parseUnsigned(u8, &.{next_ch}, 10) catch return NumParseError.NoNum;

    next_ch = ch_iter.peek(0) orelse return NumParseError.EndOfIter;
    _ = try ch_iter.advance(1);
    if (next_ch == ')' or next_ch == ',') {
        return num_1;
    }

    const num_2: u16 = std.fmt.parseUnsigned(u8, &.{next_ch}, 10) catch return NumParseError.NoNum;
    next_ch = ch_iter.peek(0) orelse return NumParseError.EndOfIter;
    _ = try ch_iter.advance(1);
    if (next_ch == ')' or next_ch == ',') return num_1 * 10 + num_2;

    const num_3: u16 = std.fmt.parseUnsigned(u8, &.{next_ch}, 10) catch return NumParseError.NoNum;
    next_ch = ch_iter.peek(0) orelse return NumParseError.EndOfIter;
    _ = try ch_iter.advance(1);
    if (next_ch != ')' and next_ch != ',') return NumParseError.NoCommaOrClosingParen;

    return num_1 * 100 + num_2 * 10 + num_3;
}

fn parse_pairs(line: []const u8) !PairList {
    var ch_iter = CharIter{ .chars = line };
    var pairs = PairList.init(alloc);

    while (ch_iter.next()) |ch| {
        print("checking from: {c}\n", .{ch});
        if (ch != 'm') continue;
        const u = ch_iter.peek(0) orelse continue == 'u';
        const l = ch_iter.peek(1) orelse continue == 'l';
        const o = ch_iter.peek(2) orelse continue == '(';

        if (!(u and l and o)) {
            print("didnt find mul( {any} {any} {any}\n", .{ u, l, o });
            continue;
        }
        print("found mul(\n", .{});

        ch_iter.advance(3) catch {
            print("going out of bounds\n", .{});
            continue;
        };

        const a = parse_num(&ch_iter) catch continue;
        const b = parse_num(&ch_iter) catch continue;
        try pairs.append(Pair{ .a = a, .b = b });
    }
    print("\n", .{});
    return pairs;
}

const T = u64;
fn mul_pairs(pairs: *const PairList) T {
    var res: T = 0;
    for (pairs.items) |p| {
        print("{d} * {d} = ", .{ p.a, p.b });
        const temp = p.a * p.b;
        print("{d}\n", .{temp});
        res += temp;
    }
    return res;
}

pub fn main() !void {
    const INPUT = @embedFile("task.input");
    var sum: T = 0;
    const pairs = try parse_pairs(INPUT);
    defer pairs.deinit();
    const pairs_sum = mul_pairs(&pairs);
    sum += pairs_sum;
    print("{d}\n", .{sum});
}
