const std = @import("std");
const dbg = std.debug.print;

const INPUT = @embedFile("./task.input");

var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
const gpa = general_purpose_allocator.allocator();

fn dbg_arr(arr: *const []u16) void {
    dbg("[", .{});
    for (0..arr.len - 1) |idx| dbg("{d}, ", .{arr.*[idx]});
    dbg("{d}]\n", .{arr.*[arr.len - 1]});
}

fn parse_values(report: []const u8) !std.ArrayList(u16) {
    var values = std.ArrayList(u16).init(gpa);
    var values_iter = std.mem.splitSequence(u8, report, " ");
    while (values_iter.next()) |value| {
        const v = std.fmt.parseUnsigned(u16, value, 10) catch {
            dbg("oopsie: {s}\n", .{value});
            continue;
        };
        try values.append(v);
    }
    return values;
}

fn only_ascending(values: *const []u16) bool {
    // dbg("ascending: ", .{});
    // dbg_arr(values);
    var prev = values.*[0];
    for (values.*[1..]) |curr| {
        if (prev >= curr) return false;
        prev = curr;
    }
    return true;
}

fn only_descending(values: *const []u16) bool {
    // dbg("descending: ", .{});
    // dbg_arr(values);
    var prev = values.*[0];
    for (values.*[1..]) |curr| {
        if (prev <= curr) return false;
        prev = curr;
    }
    return true;
}

fn max_diff_below_three(values: *const []u16) bool {
    // dbg("max_diff: ", .{});
    // dbg_arr(values);
    var prev = values.*[0];
    for (values.*[1..]) |curr| {
        // dbg("difference {d} -> {d}\n", .{ prev, curr });
        const diff = @abs(@as(i32, curr) - @as(i32, prev));
        // dbg("diff: {d}\n", .{diff});
        if (diff > 3 or diff < 1) return false;
        prev = curr;
    }
    return true;
}

fn normal(safe_num: *u16, vals: *const []u16) !void {
    if ((only_ascending(vals) or only_descending(vals)) and max_diff_below_three(vals)) {
        // dbg("SAFE\n", .{});
        safe_num.* += 1;
    }
}

fn dampened(safe_num: *u16, values: *const []u16) !void {
    if ((only_ascending(values) or only_descending(values)) and max_diff_below_three(values)) {
        // dbg("SAFE\n", .{});
        safe_num.* += 1;
        return;
    }

    const last_idx = values.len - 1;
    if ((only_ascending(&values.*[0..last_idx]) or only_descending(&values.*[0..last_idx])) and max_diff_below_three(&values.*[0..last_idx])) {
        // dbg("SAFE\n", .{});
        safe_num.* += 1;
        return;
    }

    if ((only_ascending(&values.*[1..]) or only_descending(&values.*[1..])) and max_diff_below_three(&values.*[1..])) {
        // dbg("SAFE\n", .{});
        safe_num.* += 1;
        return;
    }

    var buf = std.ArrayList(u16).init(gpa);
    for (1..values.len - 1) |left_out_idx| {
        try buf.appendSlice(values.*[0..left_out_idx]);
        try buf.appendSlice(values.*[left_out_idx + 1 ..]);
        if ((only_ascending(&buf.items) or only_descending(&buf.items)) and max_diff_below_three(&buf.items)) {
            // dbg("SAFE\n", .{});
            safe_num.* += 1;
            return;
        }
        buf.shrinkAndFree(0);
    }
    // dbg("NOT SAFE\n", .{});
}

pub fn main() !void {
    var safe_num: u16 = 0;
    var reports = std.mem.splitSequence(u8, INPUT, "\n");
    while (reports.next()) |report| {
        if (std.mem.eql(u8, std.mem.trim(u8, report, " \n\t"), "")) continue;
        const values = try parse_values(report);
        const vals = &values.items;
        // dbg_arr(vals);
        try dampened(&safe_num, vals);
    }
    dbg("{d}\n", .{safe_num});
}
