const std = @import("std");
const assert = std.debug.assert;
const print = std.debug.print;

var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const alloc = arena.allocator();

pub fn main() !void {
    defer arena.deinit();

    const file = try std.fs.cwd().openFile("./src/task.input", .{});
    defer file.close();

    const _reader = file.reader();
    var reader = std.io.bufferedReader(_reader);

    var buf: [100000]u8 = undefined;
    const read = try reader.read(&buf);
    const text = buf[0..read];

    var text_iter = std.mem.splitSequence(u8, text, "\n\n");
    const text_rules = text_iter.next().?;
    const text_updates = text_iter.next().?;
    assert(text_iter.next() == null);

    // print("rules_text: \n{s}\n\n", .{text_rules});
    // print("updates_text: \n{s}\n\n", .{text_updates});

    const rules = blk: {
        var rules_iter = std.mem.splitSequence(u8, text_rules, "\n");
        var rules_buf: [10000]Rule = undefined;
        var rules_count: u32 = 0;
        while (rules_iter.next()) |r| : (rules_count += 1) {
            var r_iter = std.mem.splitSequence(u8, r, "|");
            const b = r_iter.next().?;
            const a = r_iter.next().?;
            assert(r_iter.next() == null);
            rules_buf[rules_count] = Rule{
                .before = try std.fmt.parseInt(u32, b, 10),
                .after = try std.fmt.parseInt(u32, a, 10),
            };
        }
        const rules = rules_buf[0..rules_count];
        break :blk rules;
    };

    const updates = blk: {
        var updates_iter = std.mem.splitSequence(u8, text_updates, "\n");
        var updates_buf: [10000]Update = undefined;
        var updates_count: u32 = 0;
        while (updates_iter.next()) |u| {
            if (std.mem.eql(u8, u, "")) continue;

            var page_iter = std.mem.splitSequence(u8, u, ",");
            var pages = NumList.init(alloc);
            while (page_iter.next()) |p| {
                const page = try std.fmt.parseInt(u32, p, 10);
                try pages.append(page);
            }
            updates_buf[updates_count] = Update{ .pages = try pages.toOwnedSlice() };
            updates_count += 1;
        }
        const updates = updates_buf[0..updates_count];
        break :blk updates;
    };

    const rules_map = try build_rules_map(rules);
    print_rules_map(&rules_map);
    print_updates(updates);

    const valid_update_sum = try sum_valid_updates(updates, &rules_map);
    print("valid update sum: {d}\n", .{valid_update_sum});
}

fn sum_valid_updates(updates: []const Update, rules_map: *const RulesMap) !u32 {
    var sum: u32 = 0;
    for (updates) |u| {
        var is_valid = true;
        var seen = std.AutoHashMap(u32, void).init(alloc);
        page_loop: for (u.pages) |p| {
            try seen.put(p, {});
            const p_rules = rules_map.getPtr(p) orelse continue;
            // if seen and p_rules.after have overlap, then is_valid = false
            for (p_rules.after.items) |p_after| {
                if (seen.contains(p_after)) {
                    is_valid = false;
                    break :page_loop;
                }
            }
        }

        if (is_valid) sum += middle_page(u.pages);
    }
    return sum;
}

fn middle_page(pages: []const u32) u32 {
    const pages_len: f64 = @floatFromInt(pages.len);
    const div = @divExact(pages_len, 2.0);
    const floor = @floor(div);
    const idx: usize = @intFromFloat(floor);
    return pages[idx];
}

fn build_rules_map(rules: []const Rule) !RulesMap {
    var map = RulesMap.init(alloc);
    for (rules) |r| {
        if (!map.contains(r.before)) try map.put(r.before, try PerNumRules.init(alloc));
        if (!map.contains(r.after)) try map.put(r.after, try PerNumRules.init(alloc));
        var before_entry = map.getPtr(r.before).?;
        try before_entry.after.append(r.after);
        var after_entry = map.getPtr(r.after).?;
        try after_entry.before.append(r.before);
    }
    return map;
}

fn print_updates(updates: []const Update) void {
    for (updates, 0..updates.len) |u, idx| {
        print("update {d}:", .{idx});
        for (u.pages) |p| {
            print(" {d}", .{p});
        }
        print("\n", .{});
    }
    print("\n", .{});
}

fn print_rules_map(rules_map: *const RulesMap) void {
    var rules_map_iter = rules_map.iterator();
    while (rules_map_iter.next()) |entry| {
        print("rule for num {d}: \n", .{entry.key_ptr.*});
        print("before:", .{});
        for (entry.value_ptr.*.before.items) |b| {
            print(" {d}", .{b});
        }
        print("\n", .{});
        print("after:", .{});
        for (entry.value_ptr.*.after.items) |a| {
            print(" {d}", .{a});
        }
        print("\n\n", .{});
    }
}


const RulesMap = std.AutoHashMap(u32, PerNumRules);
const NumList = std.ArrayList(u32);

const PerNumRules = struct {
    before: NumList,
    after: NumList,

    const Self = @This();

    fn init(allocator: std.mem.Allocator) anyerror!Self {
        return Self{
            .before = NumList.init(allocator),
            .after = NumList.init(allocator),
        };
    }

    fn deinit(self: *Self) void {
        self.before.deinit();
        self.after.deinit();
    }
};

const Rule = struct { before: u32, after: u32 };

const Update = struct { pages: []u32 };
