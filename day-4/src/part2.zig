const std = @import("std");
const print = std.debug.print;

const input = @embedFile("task.input");
const line_amount = find_lines_amount(input);
const LinesType = [line_amount][]const u8;
const lines = split_lines(input);
const ROW_MAX = lines.len;
const COL_MAX = lines[0].len;
const OPT1 = "MS";
const OPT2 = "SM";

pub fn main() void {
    @setEvalBranchQuota(1000000);
    comptime var count: u64 = 0;
    comptime {
        for (lines, 0..lines.len) |line, _idx_row| {
            for (line, 0..line.len) |ch, _idx_col| {
                if (ch != 'A') continue;
                const idx_row: i64 = @intCast(_idx_row);
                const idx_col: i64 = @intCast(_idx_col);
                if (idx_row - 1 < 0 or idx_row + 1 >= ROW_MAX or idx_col - 1 < 0 or idx_col + 1 >= COL_MAX) continue;

                const first_diag: []const u8 = blk: {
                    const row_first: usize = @intCast(idx_row - 1);
                    const col_first: usize = @intCast(idx_col - 1);
                    const row_second: usize = @intCast(idx_row + 1);
                    const col_second: usize = @intCast(idx_col + 1);
                    break :blk &.{ lines[row_first][col_first], lines[row_second][col_second] };
                };
                const second_diag: []const u8 = blk: {
                    const row_first: usize = @intCast(idx_row - 1);
                    const col_first: usize = @intCast(idx_col + 1);
                    const row_second: usize = @intCast(idx_row + 1);
                    const col_second: usize = @intCast(idx_col - 1);
                    break :blk &.{ lines[row_first][col_first], lines[row_second][col_second] };
                };

                if (!is_one_of_opts(first_diag) or !is_one_of_opts(second_diag)) continue;

                count += 1;
            }
        }
    }
    print("XMAS count: {d}\n", .{count});
}

const eql = std.mem.eql;
fn is_one_of_opts(diag: []const u8) bool {
    std.debug.assert(diag.len == 2);
    return eql(u8, diag, OPT1) or eql(u8, diag, OPT2);
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
