const std = @import("std");
const print = std.debug.print;

const input = @embedFile("task.input");
const line_amount = find_lines_amount(input);
const LinesType = [line_amount][]const u8;
const FROM_X = "MAS";
const FROM_S = "AMX";

pub fn main() void {
    @setEvalBranchQuota(1000000);
    comptime var count = 0;
    comptime {
        const lines = split_lines(input);
        const ROW_MAX = lines.len;
        const COL_MAX = lines[0].len;

        for (lines, 0..lines.len) |line, _idx_row| {
            for (line, 0..line.len) |ch, _idx_col| {
                if (ch != 'X' and ch != 'S') {
                    continue;
                }

                dir_for: for (Direction.ALL_DIRECTIONS) |dir| {
                    const offsets = dir.offsets();
                    const o_last = offsets[offsets.len - 1];
                    const idx_row: i64 = @intCast(_idx_row);
                    const idx_col: i64 = @intCast(_idx_col);
                    const row_max_with_o = idx_row + o_last[0];
                    const col_max_with_o = idx_col + o_last[1];

                    if (row_max_with_o < 0 or row_max_with_o >= ROW_MAX or col_max_with_o < 0 or col_max_with_o >= COL_MAX) {
                        // print("skipping: ({d}, {d}) for dir: {any}\n", .{ _idx_row, _idx_col, dir });
                        continue;
                    }

                    if (ch == 'X') {
                        for (offsets, 0..offsets.len) |o, o_idx| {
                            const row: usize = @intCast(idx_row + o[0]);
                            const col: usize = @intCast(idx_col + o[1]);
                            if (lines[row][col] != FROM_X[o_idx]) continue :dir_for;
                        }
                    } else if (ch == 'S') {
                        for (offsets, 0..offsets.len) |o, o_idx| {
                            const row: usize = @intCast(idx_row + o[0]);
                            const col: usize = @intCast(idx_col + o[1]);
                            if (lines[row][col] != FROM_S[o_idx]) continue :dir_for;
                        }
                    }

                    count += 1;
                }
            }
        }
        count = @divExact(count, 2);
    }
    print("XMAS count: {d}\n", .{count});
}

fn find_lines_amount(string: []const u8) comptime_int {
    @setEvalBranchQuota(100000);
    comptime {
        var amount = 0;
        for (string) |ch| {
            if (ch == '\n') amount += 1;
        }
        return amount;
    }
}

fn split_lines(string: []const u8) LinesType {
    @setEvalBranchQuota(100000);
    comptime {
        var buf: LinesType = undefined;
        var iter = std.mem.splitSequence(u8, string, "\n");
        var idx = 0;
        while (iter.next()) |line| : (idx += 1) {
            if (std.mem.eql(u8, line, "")) {
                continue;
            }
            buf[idx] = line;
        }
        return buf;
    }
}

const Direction = enum {
    NW,
    N,
    NE,
    E,
    SE,
    S,
    SW,
    W,

    const _fields_len = @typeInfo(Direction).@"enum".fields.len;
    const ALL_DIRECTIONS: [_fields_len]Direction = blk: {
        const fields = @typeInfo(Direction).@"enum".fields;
        var dirs: [_fields_len]Direction = undefined;
        for (fields, 0.._fields_len) |f, idx| {
            dirs[idx] = @enumFromInt(f.value);
        }
        break :blk dirs;
    };

    fn offsets(d: Direction) []const struct { i64, i64 } {
        return switch (d) {
            // .{ rows, cols }
            .NW => &.{ .{ -1, -1 }, .{ -2, -2 }, .{ -3, -3 } },
            .N => &.{ .{ -1, 0 }, .{ -2, 0 }, .{ -3, 0 } },
            .NE => &.{ .{ -1, 1 }, .{ -2, 2 }, .{ -3, 3 } },
            .E => &.{ .{ 0, 1 }, .{ 0, 2 }, .{ 0, 3 } },
            .SE => &.{ .{ 1, 1 }, .{ 2, 2 }, .{ 3, 3 } },
            .S => &.{ .{ 1, 0 }, .{ 2, 0 }, .{ 3, 0 } },
            .SW => &.{ .{ 1, -1 }, .{ 2, -2 }, .{ 3, -3 } },
            .W => &.{ .{ 0, -1 }, .{ 0, -2 }, .{ 0, -3 } },
        };
    }
};
