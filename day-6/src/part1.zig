const std = @import("std");
const print = std.debug.print;
const assert = std.debug.assert;

pub fn main() !void {
    const file = try std.fs.cwd().openFile("src/test.input", .{});
    defer file.close();
    var buf: [20000]u8 = undefined;
    const _reader = file.reader();
    var reader = std.io.bufferedReader(_reader);
    const read_bytes = try reader.read(&buf);
    const input = buf[0..read_bytes];
    print("hello, this is the input (len = {d}): \n{s}\n", .{input.len, input});
}
