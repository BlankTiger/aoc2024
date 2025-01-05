/// TUI visualizer for day-6 guard pathing solver

const std = @import("std");
const print = std.debug.print;
const term = @import("terminal.zig");
const solver = @import("solver.zig");
const atomic = @import("atomic.zig");

const INPUT = @embedFile("../task.input");

var done = ABool.init(false);

const ABool = atomic.ABool;
pub fn run() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = false }){};
    const allocator = gpa.allocator();
    defer { _ = gpa.deinit(); }

    var msg: [INPUT.len + 200]u8 = undefined;
    const input_msg = msg[0..INPUT.len];
    @memcpy(input_msg, INPUT);
    const info_buf = msg[INPUT.len..];
    @memset(info_buf, ' ');
    const refresh_rate_fps: u32 = 120;
    const update_rate_ms: u32 = 0;

    var work_thread = try std.Thread.spawn(.{}, solver.find_sol, .{allocator, update_rate_ms, msg[0..msg.len], info_buf, &done});
    var ui_thread = try std.Thread.spawn(.{}, term.show, .{allocator, refresh_rate_fps, msg[0..msg.len], &done});
    work_thread.join();
    ui_thread.join();
}
