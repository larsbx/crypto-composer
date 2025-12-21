const std = @import("std");
const graph = @import("../schemas/graph.zig");
const errors = @import("errors.zig");

pub fn checkDomainSep(allocator: std.mem.Allocator, gr: *const graph.CompositionGraph) ?errors.C2Error {
    var seen = std.StringHashMap([]const u8).init(allocator);
    defer seen.deinit();

    for (gr.kdf_calls) |call| {
        if (seen.get(call.label)) |existing| {
            return .{ .label = call.label, .call1 = existing, .call2 = call.id };
        }
        seen.put(call.label, call.id) catch unreachable;
    }
    return null;
}
