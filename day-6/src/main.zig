// const part1 = @import("part1.zig");
// const part2 = @import("part2.zig");
const visualizer = @import("visualizer/main.zig");

pub fn main() !void {
    try visualizer.run();
}
