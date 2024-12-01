const std = @import("std");
const print = std.debug.print;

const INPUT = @embedFile("./input");
var allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
const gpa = allocator.allocator();

pub fn main() !void {
    // try part1();
    try part2();
}

fn part2() !void {
    var sorted = try sorted_lists();
    defer sorted.deinit();
    var sim_score: u32 = 0;
    for (sorted.list1.items) |num| {
        sim_score = sim_score + num * frequency(num, sorted.list2.items);
    }
    print("{d}\n", .{sim_score});
}

fn frequency(num: u32, list: []const u32) u32 {
    var freq: u32 = 0;
    for (list) |n| {
        if (n == num) {
            freq = freq + 1;
        }
    }
    return freq;
}

fn part1() !void {
    var sum: u64 = 0;
    var sorted = try sorted_lists();
    defer sorted.deinit();
    for (sorted.list1.items, sorted.list2.items) |num1, num2| {
        const diff = @as(i64, num1) - @as(i64, num2);
        sum = sum + @as(u64, @abs(diff));
    }

    print("{d}\n", .{sum});
}

const SortedLists = struct {
    const T = std.ArrayList(u32);
    list1: T,
    list2: T,

    fn deinit(self: *SortedLists) void {
        self.list1.deinit();
        self.list2.deinit();
    }
};

fn sorted_lists() !SortedLists {
    var list1 = std.ArrayList(u32).init(gpa);
    var list2 = std.ArrayList(u32).init(gpa);

    var it = std.mem.splitScalar(u8, INPUT, '\n');
    while (it.next()) |line| {
        if (std.mem.eql(u8, line, "")) {
            break;
        }
        var nums = std.mem.splitSequence(u8, line, "   ");
        if (nums.next()) |num1| {
            const num = try std.fmt.parseUnsigned(u32, std.mem.trim(u8, num1, "\n "), 10);
            try list1.append(num);
        } else {
            continue;
        }
        if (nums.next()) |num2| {
            const num = try std.fmt.parseUnsigned(u32, std.mem.trim(u8, num2, "\n "), 10);
            try list2.append(num);
        } else {
            continue;
        }
    }
    std.mem.sort(u32, list1.items, {}, comptime std.sort.asc(u32));
    std.mem.sort(u32, list2.items, {}, comptime std.sort.asc(u32));

    return .{ .list1 = list1, .list2 = list2 };
}
