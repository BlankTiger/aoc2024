const std = @import("std");
const print = std.debug.print;
const assert = std.debug.assert;
const vaxis = @import("vaxis");
const atomic = @import("atomic.zig");

const ABool = atomic.ABool;

pub const panic = vaxis.panic_handler;

pub const std_options: std.Options = .{
    .log_scope_levels = &.{
        .{ .scope = .vaxis, .level = .warn },
        .{ .scope = .vaxis_parser, .level = .warn },
    },
};

const Event = union(enum) {
    key_press: vaxis.Key,
    key_release: vaxis.Key,
    focus_in,
    focus_out,
    paste_start,
    paste_end,
    paste: []const u8,
    color_report: vaxis.Color.Report, // osc 4, 10, 11, 12 response
    color_scheme: vaxis.Color.Scheme,
    winsize: vaxis.Winsize,
};

const Visualizer = struct {
    allocator: std.mem.Allocator,
    refresh_rate_fps: u32,
    should_quit: bool,
    tty: vaxis.Tty,
    vx: vaxis.Vaxis,
    msg: []u8,
    done: *ABool,

    pub fn init(allocator: std.mem.Allocator, refresh_rate_fps: u32, msg: []u8, done: *ABool) !Visualizer {
        return .{
            .allocator = allocator,
            .refresh_rate_fps = refresh_rate_fps,
            .should_quit = false,
            .tty = try vaxis.Tty.init(),
            .vx = try vaxis.init(allocator, .{}),
            .msg = msg,
            .done = done,
        };
    }

    pub fn deinit(self: *Visualizer) void {
        self.vx.deinit(self.allocator, self.tty.anyWriter());
        self.tty.deinit();
    }

    pub fn run(self: *Visualizer) !void {
        var loop: vaxis.Loop(Event) = .{
            .tty = &self.tty,
            .vaxis = &self.vx,
        };
        try loop.init();
        try loop.start();

        try self.vx.enterAltScreen(self.tty.anyWriter());
        try self.vx.queryTerminal(self.tty.anyWriter(), 1 * std.time.ns_per_s);

        while (!self.should_quit and !self.done.load(.monotonic)) {
            std.time.sleep(std.time.ns_per_s / self.refresh_rate_fps);
            while (loop.tryEvent()) |event| {
                try self.update(event);
            }

            self.draw();

            var buffered = self.tty.bufferedWriter();
            try self.vx.render(buffered.writer().any());
            try buffered.flush();
        }
        try std.Thread.yield();
    }

    pub fn update(self: *Visualizer, event: Event) !void {
        switch (event) {
            .key_press => |key| {
                if (key.matches('c', .{ .ctrl = true }))
                    self.should_quit = true;
            },
            .winsize => |ws| try self.vx.resize(self.allocator, self.tty.anyWriter(), ws),
            else => {},
        }
    }

    pub fn draw(self: *Visualizer) void {
        const msg = self.msg;
        var it = std.mem.splitSequence(u8, msg, "\n");
        const msg_line = it.next().?;
        const win = self.vx.window();
        win.clear();
        const child = win.child(.{
            .x_off = win.width / 2 - msg_line.len / 2,
            .y_off = 1,
            .width = .{ .limit = msg.len },
            .height = .{ .limit = std.mem.count(u8, msg, "\n") + 1 },
        });
        const style: vaxis.Style = .{};
        _ = try child.printSegment(.{ .text = msg, .style = style }, .{});
    }
};

pub fn show(allocator: std.mem.Allocator, refresh_rate_fps: u32, msg: []u8, done: *ABool) !void {
    var app = try Visualizer.init(allocator, refresh_rate_fps, msg, done);
    defer app.deinit();
    try app.run();
}
