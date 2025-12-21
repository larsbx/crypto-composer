const std = @import("std");
const graph = @import("../schemas/graph.zig");

// TODO(v0.2+): machine-readable SecurityClaim AST + structured reductions.
// v0.1: just dumps a tiny JSON summary of the graph shape.

pub fn emitJsonSummary(allocator: std.mem.Allocator, gr: *const graph.CompositionGraph) ![]const u8 {
    var obj = std.json.ObjectMap.init(allocator);
    defer obj.deinit();

    try obj.put("values", .{ .integer = @intCast(gr.values.len) });
    try obj.put("kem_ops", .{ .integer = @intCast(gr.kem_ops.len) });
    try obj.put("kdf_calls", .{ .integer = @intCast(gr.kdf_calls.len) });
    try obj.put("aead_ops", .{ .integer = @intCast(gr.aead_ops.len) });
    try obj.put("edges", .{ .integer = @intCast(gr.edges.len) });
    try obj.put("outputs", .{ .integer = @intCast(gr.outputs.len) });

    var root = std.json.Value{ .object = obj };
    return std.json.stringifyAlloc(allocator, root, .{ .whitespace = .indent_2 });
}
