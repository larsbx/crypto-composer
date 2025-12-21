const std = @import("std");
const graph = @import("../schemas/graph.zig");
const g = @import("../types/ground.zig");
const errors = @import("errors.zig");

pub fn checkConstantTimeChain(allocator: std.mem.Allocator, gr: *const graph.CompositionGraph) ?errors.C5Warning {
    // v0.1 heuristic: any Value with secret=true must have timing != data_dependent.
    // TODO(v0.2+): path-sensitive analysis across ops and inputs.
    _ = allocator;

    for (gr.values) |v| {
        if (!v.secret) continue;
        if (v.timing == .data_dependent or v.timing == .unknown) {
            return .{ .non_ct_primitive_in_secret_path = .{ .primitive = v.name, .timing = v.timing } };
        }
    }
    return null;
}
