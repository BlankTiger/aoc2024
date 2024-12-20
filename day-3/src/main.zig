const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;

const print = std.debug.print;
// fn print(comptime fmt: []const u8, args: anytype) void {
//     _ = fmt;
//     _ = args;
// }

const Pair = struct { a: T, b: T };
const PairList = struct {
    items: []Pair,
    len: usize,
};

const IterError = error{
    OutOfRange,
};

const CharIter = struct {
    chars: []u8,
    done: bool = false,
    do: bool = true,

    fn next(self: *CharIter) ?u8 {
        if (self.done) return null;

        if (self.chars.len == 1) {
            self.done = true;
            return self.chars[0];
        }

        self.chars = self.chars[1..];
        return self.chars[0];
    }

    fn peek(self: CharIter, ahead: u32) ?u8 {
        if (self.chars.len <= ahead) return null;
        const res = self.chars[ahead];
        print("peeking: {c}\n", .{res});
        return res;
    }

    fn advance(self: *CharIter, ahead: u32) IterError!void {
        if (self.chars.len <= ahead) return error.OutOfRange;
        self.chars = self.chars[ahead..];
    }
};

const NumParseError = error{
    NoCommaOrClosingParen,
    NoNum,
    EndOfIter,
    OutOfRange,
};

fn parse_num(ch_iter: *CharIter) NumParseError!T {
    var next_ch = ch_iter.peek(1) orelse return NumParseError.EndOfIter;
    _ = try ch_iter.advance(1);
    const num_1: T = std.fmt.parseUnsigned(T, &.{next_ch}, 10) catch return NumParseError.NoNum;

    next_ch = ch_iter.peek(1) orelse return NumParseError.EndOfIter;
    _ = try ch_iter.advance(1);
    if (next_ch == ')' or next_ch == ',') {
        return num_1;
    }

    const num_2: T = std.fmt.parseUnsigned(T, &.{next_ch}, 10) catch return NumParseError.NoNum;
    next_ch = ch_iter.peek(1) orelse return NumParseError.EndOfIter;
    _ = try ch_iter.advance(1);
    if (next_ch == ')' or next_ch == ',') return num_1 * 10 + num_2;

    const num_3: T = std.fmt.parseUnsigned(T, &.{next_ch}, 10) catch return NumParseError.NoNum;
    next_ch = ch_iter.peek(1) orelse return NumParseError.EndOfIter;
    _ = try ch_iter.advance(1);
    if (next_ch != ')' and next_ch != ',') return NumParseError.NoCommaOrClosingParen;

    return num_1 * 100 + num_2 * 10 + num_3;
}

fn peek_do_inst(ch_iter: *CharIter) !void {
    const d = ch_iter.peek(0) orelse return == 'd';
    const o = ch_iter.peek(1) orelse return == 'o';
    if (!(d and o)) return;

    const third_ch = ch_iter.peek(2) orelse return;
    const n = third_ch == 'n';
    const po = third_ch == '(';
    if (n) {
        const tick = ch_iter.peek(3) orelse return == '\'';
        const t = ch_iter.peek(4) orelse return == 't';
        const po2 = ch_iter.peek(5) orelse return == '(';
        const pc2 = ch_iter.peek(6) orelse return == ')';
        if (d and o and n and tick and t and po2 and pc2) {
            _ = try ch_iter.advance(6);
            ch_iter.do = false;
        }
    } else if (po) {
        const pc = ch_iter.peek(3) orelse return == ')';
        if (d and o and po and pc) {
            _ = try ch_iter.advance(3);
            ch_iter.do = true;
        }
    }
}

fn parse_pairs(line: []const u8) !PairList {
    var ch_iter = CharIter{ .chars = @constCast(line) };
    var items: [1000]Pair = undefined;
    @memset(&items, Pair{ .a = 0, .b = 0 });
    var pairs = PairList{ .items = &items, .len = 0 };
    var valid_mul_counter: u16 = 0;
    while (ch_iter.next()) |ch| {
        print("checking from: {c}\n", .{ch});
        try peek_do_inst(&ch_iter);
        if (!ch_iter.do) continue;
        if (ch != 'm') continue;
        const u = ch_iter.peek(1) orelse continue == 'u';
        const l = ch_iter.peek(2) orelse continue == 'l';
        const o = ch_iter.peek(3) orelse continue == '(';

        if (!(u and l and o)) {
            print("didnt find mul( {any} {any} {any}\n", .{ u, l, o });
            continue;
        }
        print("found mul(\n", .{});

        ch_iter.advance(3) catch {
            print("going out of bounds\n", .{});
            continue;
        };

        const a = parse_num(&ch_iter) catch |err| {
            print("a error: {any}\n", .{err});
            continue;
        };
        print("a: {d}\n", .{a});
        const b = parse_num(&ch_iter) catch |err| {
            print("b error: {any}\n", .{err});
            continue;
        };
        print("b {d}\n", .{b});
        const c = ch_iter.peek(0) orelse continue;
        if (c != ')') continue;
        items[valid_mul_counter] = Pair{ .a = a, .b = b };
        valid_mul_counter += 1;
    }
    pairs.len = valid_mul_counter;
    print("\n", .{});
    return pairs;
}

fn mul_pairs(pairs: *const PairList) T {
    var res: T = 0;
    for (0..pairs.len) |idx| {
        const p = pairs.items[idx];
        print("{d} * {d} = ", .{ p.a, p.b });
        const temp = p.a * p.b;
        print("{d}\n", .{temp});
        res += temp;
    }
    return res;
}

const T = u64;

pub fn main() !void {
    const INPUT = @embedFile("./task.input");
    var sum: T = 0;
    const pairs = try parse_pairs(INPUT);
    const pairs_sum = mul_pairs(&pairs);
    sum += pairs_sum;
    std.debug.print("{d}\n", .{sum});
}
