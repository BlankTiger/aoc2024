const std = @import("std");
const print = std.debug.print;
const assert = std.debug.assert;

var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
const alloc = gpa.allocator();

pub fn main() !void {
    const file = try std.fs.cwd().openFile("./src/task.input", .{});
    defer file.close();
    const _reader = file.reader();
    var reader = std.io.bufferedReader(_reader);

    var buf: [100 * 1000]u8 = undefined;
    const read_bytes = try reader.read(&buf);
    const text: []const u8 = buf[0..read_bytes];

    const rules_and_updates = try parse_rules_and_updates(text);
    const rules_per_page_num = try parse_rules_per_page_num(&rules_and_updates);
    _ = rules_per_page_num;
    for (rules_and_updates.rules) |rule| {
        print("{d}|{d}\n", .{rule.before, rule.after});
    }
    for (rules_and_updates.updates) |update| {
        for (0..update.page_count) |page_idx| {
            print("{d} ", .{update.pages[page_idx]});
        }
        print("\n", .{});
    }
}

const RulesForNum = struct {
    const List = std.ArrayList(u32);
    const Self = @This();

    before: List,
    after:  List,


    fn init(self: *Self, allocator: std.mem.Allocator) void {
        self.before = List.init(allocator);
        self.after = List.init(allocator);
    }

    fn deinit(self: *RulesForNum) void {
        self.before.deinit();
        self.after.deinit();
    }
};

fn parse_rules_per_page_num(p: *const UParser()) !std.AutoHashMap(u32, RulesForNum) {
    var res = std.AutoHashMap(u32, RulesForNum).init(alloc);
    for (p.rules) |rule| {
        const before = try res.getOrPut(rule.before);
        const after = try res.getOrPut(rule.after);
        before.value_ptr.*.init(alloc);
        after.value_ptr.*.init(alloc);
    }
    return res;
}

fn parse_rules_and_updates(text: []const u8) !UParser() {
    var parsed: ParserDefault() = undefined;
    var text_iter = std.mem.splitSequence(u8, text, "\n\n");
    const rules_text = text_iter.next().?;
    const updates_text = text_iter.next().?;

    assert(text_iter.next() == null);

    parsed.rules_count   = try parse_rules(&parsed.rules, rules_text);
    parsed.updates_count = try parse_updates(&parsed.updates, updates_text);
    const uparser: UParser() = .{
        .rules   = parsed.rules[0..parsed.rules_count],
        .updates = parsed.updates[0..parsed.updates_count],
    };
    return uparser;
}

fn parse_rules(dest: [*]Rule, text: []const u8) !u32 {
    var line_iter = std.mem.splitSequence(u8, text, "\n");
    var rule_idx: u32 = 0;
    while (line_iter.next()) |line| {
        if (std.mem.eql(u8, line, "")) continue;
        var rule_iter = std.mem.splitSequence(u8, line, "|");
        dest[rule_idx] = Rule{
            .before = try std.fmt.parseInt(u32, rule_iter.next().?, 10),
            .after  = try std.fmt.parseInt(u32, rule_iter.next().?, 10),
        };
        assert(rule_iter.next() == null);
        rule_idx += 1;
    }
    return rule_idx;
}

fn parse_updates(dest: [*]DefaultUpdate(), text: []const u8) !u32 {
    var line_iter = std.mem.splitSequence(u8, text, "\n");
    var update_idx: u32 = 0;
    while (line_iter.next()) |line| {
        if (std.mem.eql(u8, line, "")) continue;
        var page_iter = std.mem.splitSequence(u8, line, ",");
        var page_buf: [DEFAULT_PAGE_BUF_SIZE]u32 = undefined;
        var page_count: u32 = 0;
        while (page_iter.next()) |page_num| {
            page_buf[page_count] = try std.fmt.parseInt(u32, page_num, 10);
            page_count += 1;
        }
        @memcpy(&dest[update_idx].pages, &page_buf);
        dest[update_idx].page_count = page_count;
        update_idx += 1;
    }
    return update_idx;
}

const DEFAULT_PAGE_BUF_SIZE = 25;

fn ParserDefault() type {
    return Parsed(1200, DEFAULT_PAGE_BUF_SIZE);
}

fn Parsed(comptime buf_size: u32, comptime page_buf_size: u32) type {
    return struct {
        rules:         [buf_size]Rule,
        updates:       [buf_size]Update(page_buf_size),
        rules_count:   u32 = 0,
        updates_count: u32 = 0,
    };
}

fn UParser() type {
    return struct {
        rules:   []Rule,
        updates: []Update(DEFAULT_PAGE_BUF_SIZE),
    };
}


const Rule = struct { before: u32, after: u32 };

fn DefaultUpdate() type {
    return Update(DEFAULT_PAGE_BUF_SIZE);
}

fn Update(comptime buf_size: u32) type {
    return struct {
        pages: [buf_size]u32,
        page_count: u32,
    };
}
