const std = @import("std");
const graph = @import("../schemas/graph.zig");
const g = @import("../types/ground.zig");
const errors = @import("errors.zig");

pub fn checkConstantTimeChain(allocator: std.mem.Allocator, gr: *const graph.CompositionGraph) ?errors.C5Warning {
    // v0.1 heuristic: warn on secret-tainted values or non-CT op outputs fed by secrets.
    // TODO(v0.2+): richer path-sensitive analysis across ops and inputs.

    var tainted = computeTaintedValues(allocator, gr);
    defer tainted.deinit();

    for (gr.values) |v| {
        if (!v.secret) continue;
        if (isTimingRisk(v.timing)) {
            return .{ .non_ct_primitive_in_secret_path = .{ .primitive = v.name, .timing = v.timing } };
        }
    }

    for (gr.kdf_calls) |call| {
        if (!valueRefsTainted(&tainted, call.inputs)) continue;
        if (valueTimingRisk(gr, call.out_name)) |timing| {
            return .{ .non_ct_primitive_in_secret_path = .{ .primitive = call.kdf_name, .timing = timing } };
        }
    }

    for (gr.kem_ops) |op| {
        if (!refsTainted(&tainted, op.inputs)) continue;
        if (valueTimingRisk(gr, op.ss_success_out)) |timing| {
            return .{ .non_ct_primitive_in_secret_path = .{ .primitive = op.kem_name, .timing = timing } };
        }
        if (op.ss_failure_out) |name| {
            if (valueTimingRisk(gr, name)) |timing| {
                return .{ .non_ct_primitive_in_secret_path = .{ .primitive = op.kem_name, .timing = timing } };
            }
        }
        if (op.ct_out) |name| {
            if (valueTimingRisk(gr, name)) |timing| {
                return .{ .non_ct_primitive_in_secret_path = .{ .primitive = op.kem_name, .timing = timing } };
            }
        }
    }

    for (gr.aead_ops) |*op| {
        if (!aeadInputsTainted(&tainted, op)) continue;
        if (op.ct_out) |name| {
            if (valueTimingRisk(gr, name)) |timing| {
                return .{ .non_ct_primitive_in_secret_path = .{ .primitive = op.aead_name, .timing = timing } };
            }
        }
        if (op.pt_out) |name| {
            if (valueTimingRisk(gr, name)) |timing| {
                return .{ .non_ct_primitive_in_secret_path = .{ .primitive = op.aead_name, .timing = timing } };
            }
        }
        if (op.failure_out) |name| {
            if (valueTimingRisk(gr, name)) |timing| {
                return .{ .non_ct_primitive_in_secret_path = .{ .primitive = op.aead_name, .timing = timing } };
            }
        }
    }

    for (gr.values) |v| {
        if (!tainted.contains(v.name)) continue;
        if (isTimingRisk(v.timing)) {
            return .{ .non_ct_primitive_in_secret_path = .{ .primitive = v.name, .timing = v.timing } };
        }
    }
    return null;
}

fn isTimingRisk(timing: g.TimingClass) bool {
    return timing == .data_dependent or timing == .unknown;
}

fn computeTaintedValues(allocator: std.mem.Allocator, gr: *const graph.CompositionGraph) std.StringHashMap(void) {
    var tainted = std.StringHashMap(void).init(allocator);
    for (gr.values) |v| {
        if (v.secret) {
            tainted.put(v.name, {}) catch unreachable;
        }
    }

    var changed = true;
    while (changed) {
        changed = false;

        for (gr.edges) |edge| {
            const from_ref = edge.from.ref();
            if (from_ref != .value) continue;
            if (!tainted.contains(from_ref.value)) continue;
            if (edge.to != .value) continue;
            markTainted(&tainted, edge.to.value, &changed);
        }

        for (gr.kdf_calls) |call| {
            if (!valueRefsTainted(&tainted, call.inputs)) continue;
            markTainted(&tainted, call.out_name, &changed);
        }

        for (gr.kem_ops) |op| {
            if (!refsTainted(&tainted, op.inputs)) continue;
            markTainted(&tainted, op.ss_success_out, &changed);
            if (op.ss_failure_out) |name| markTainted(&tainted, name, &changed);
            if (op.ct_out) |name| markTainted(&tainted, name, &changed);
        }

        for (gr.aead_ops) |*op| {
            if (!aeadInputsTainted(&tainted, op)) continue;
            if (op.ct_out) |name| markTainted(&tainted, name, &changed);
            if (op.pt_out) |name| markTainted(&tainted, name, &changed);
            if (op.failure_out) |name| markTainted(&tainted, name, &changed);
        }
    }

    return tainted;
}

fn markTainted(tainted: *std.StringHashMap(void), name: []const u8, changed: *bool) void {
    if (tainted.contains(name)) return;
    tainted.put(name, {}) catch unreachable;
    changed.* = true;
}

fn valueTimingRisk(gr: *const graph.CompositionGraph, name: []const u8) ?g.TimingClass {
    const v = graph.findValue(gr, name) orelse return null;
    if (!isTimingRisk(v.timing)) return null;
    return v.timing;
}

fn valueRefsTainted(tainted: *const std.StringHashMap(void), refs: []const graph.ValueRef) bool {
    for (refs) |r| {
        if (refTainted(tainted, r.ref())) return true;
    }
    return false;
}

fn refsTainted(tainted: *const std.StringHashMap(void), refs: []const graph.Ref) bool {
    for (refs) |r| {
        if (refTainted(tainted, r)) return true;
    }
    return false;
}

fn aeadInputsTainted(tainted: *const std.StringHashMap(void), op: *const graph.AeadOp) bool {
    if (refTainted(tainted, op.key)) return true;
    if (refTainted(tainted, op.nonce)) return true;
    if (op.aad) |aad| if (refTainted(tainted, aad)) return true;
    if (op.plaintext) |pt| if (refTainted(tainted, pt)) return true;
    if (op.ciphertext) |ct| if (refTainted(tainted, ct)) return true;
    return false;
}

fn refTainted(tainted: *const std.StringHashMap(void), ref: graph.Ref) bool {
    if (ref != .value) return false;
    return tainted.contains(ref.value);
}
