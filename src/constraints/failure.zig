const std = @import("std");
const graph = @import("../schemas/graph.zig");
const errors = @import("errors.zig");

pub fn checkFailureConsistency(allocator: std.mem.Allocator, gr: *const graph.CompositionGraph) ?errors.C4Error {
    // Collect KEM failure values
    var failure_values = std.ArrayList([]const u8).init(allocator);
    defer failure_values.deinit();

    for (gr.kem_ops) |op| {
        if (op.canFail()) {
            if (op.ss_failure_out) |fv| failure_values.append(fv) catch unreachable;
        }
    }

    // TODO(v0.2+): collect AEAD failures as "virtual failure values" and enforce they go to reject_boundary.

    for (failure_values.items) |fv| {
        var reachable = computeBranchAwareReachable(allocator, gr, fv, .failure);
        defer reachable.deinit();

        for (gr.outputs) |out| {
            if (out.kind == .value and !out.public) {
                if (reachable.contains(out.value)) {
                    return .{ .failure_reaches_key = .{ .failure_value = fv, .reached_output = out.name } };
                }
            }
        }

        if (!reachable.contains("reject_boundary")) {
            return .{ .failure_not_terminated = .{ .failure_value = fv } };
        }
    }
    return null;
}

const Branch = enum { success, failure };

fn computeBranchAwareReachable(
    allocator: std.mem.Allocator,
    gr: *const graph.CompositionGraph,
    start: []const u8,
    start_branch: Branch,
) std.StringHashMap(void) {
    var reachable = std.StringHashMap(void).init(allocator);
    var queue = std.ArrayList(struct { name: []const u8, branch: Branch }).init(allocator);

    queue.append(.{ .name = start, .branch = start_branch }) catch unreachable;

    while (queue.items.len > 0) {
        const cur = queue.orderedRemove(0);

        if (reachable.contains(cur.name)) continue;
        reachable.put(cur.name, {}) catch unreachable;

        // Follow edges (branch-aware)
        for (gr.edges) |edge| {
            const from_ref = edge.from.ref();
            if (from_ref != .value) continue;
            if (!std.mem.eql(u8, from_ref.value, cur.name)) continue;

            const edge_branch: ?Branch = if (edge.from.isFailurePath()) .failure else if (edge.from.isSuccessPath()) .success else null;
            const can_follow = edge_branch == null or edge_branch.? == cur.branch;

            if (can_follow) {
                const to_ref = edge.to;
                if (to_ref != .value) continue;
                queue.append(.{ .name = to_ref.value, .branch = cur.branch }) catch unreachable;
            }
        }

        // Flow through KDF calls if current is an input (conservative)
        for (gr.kdf_calls) |call| {
            for (call.inputs) |inp| {
                const ir = inp.ref();
                if (ir != .value) continue;
                if (!std.mem.eql(u8, ir.value, cur.name)) continue;

                const inp_branch: ?Branch = if (inp.isFailurePath()) .failure else if (inp.isSuccessPath()) .success else null;
                const can_flow = inp_branch == null or inp_branch.? == cur.branch;

                if (can_flow) {
                    queue.append(.{ .name = call.out_name, .branch = cur.branch }) catch unreachable;
                }
            }
        }
    }

    return reachable;
}
