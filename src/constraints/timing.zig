const std = @import("std");
const graph = @import("../schemas/graph.zig");
const g = @import("../types/ground.zig");
const errors = @import("errors.zig");

pub fn checkConstantTimeChain(allocator: std.mem.Allocator, gr: *const graph.CompositionGraph) ?errors.C5Warning {
    // v0.1 heuristic: warn on secret values or op outputs with non-CT timing when fed by secrets.
    // TODO(v0.2+): richer path-sensitive analysis across ops and inputs.
    _ = allocator;

    for (gr.values) |v| {
        if (!v.secret) continue;
        if (isTimingRisk(v.timing)) {
            return .{ .non_ct_primitive_in_secret_path = .{ .primitive = v.name, .timing = v.timing } };
        }
    }

    for (gr.values) |v| {
        if (v.secret) continue;
        if (!isTimingRisk(v.timing)) continue;

        switch (v.source) {
            .kdf_call => |id| {
                const call = graph.findKdfCall(gr, id) orelse continue;
                if (hasSecretValueRefs(gr, call.inputs)) {
                    return .{ .non_ct_primitive_in_secret_path = .{ .primitive = call.kdf_name, .timing = v.timing } };
                }
            },
            .kem_op => |src| {
                const op = graph.findKemOp(gr, src.op_id) orelse continue;
                if (hasSecretRefs(gr, op.inputs)) {
                    return .{ .non_ct_primitive_in_secret_path = .{ .primitive = op.kem_name, .timing = v.timing } };
                }
            },
            .aead_op => |src| {
                const op = graph.findAeadOp(gr, src.op_id) orelse continue;
                if (aeadHasSecretInput(gr, op)) {
                    return .{ .non_ct_primitive_in_secret_path = .{ .primitive = op.aead_name, .timing = v.timing } };
                }
            },
            else => {},
        }
    }
    return null;
}

fn isTimingRisk(timing: g.TimingClass) bool {
    return timing == .data_dependent or timing == .unknown;
}

fn hasSecretValueRefs(gr: *const graph.CompositionGraph, refs: []const graph.ValueRef) bool {
    for (refs) |r| {
        if (refIsSecret(gr, r.ref())) return true;
    }
    return false;
}

fn hasSecretRefs(gr: *const graph.CompositionGraph, refs: []const graph.Ref) bool {
    for (refs) |r| {
        if (refIsSecret(gr, r)) return true;
    }
    return false;
}

fn aeadHasSecretInput(gr: *const graph.CompositionGraph, op: *const graph.AeadOp) bool {
    if (refIsSecret(gr, op.key)) return true;
    if (refIsSecret(gr, op.nonce)) return true;
    if (op.aad) |aad| if (refIsSecret(gr, aad)) return true;
    if (op.plaintext) |pt| if (refIsSecret(gr, pt)) return true;
    if (op.ciphertext) |ct| if (refIsSecret(gr, ct)) return true;
    return false;
}

fn refIsSecret(gr: *const graph.CompositionGraph, ref: graph.Ref) bool {
    if (ref != .value) return false;
    const v = graph.findValue(gr, ref.value) orelse return false;
    return v.secret;
}
