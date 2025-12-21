const std = @import("std");
const graph = @import("../schemas/graph.zig");
const g = @import("../types/ground.zig");
const catalog = @import("../catalog/mod.zig");
const errors = @import("errors.zig");

pub fn checkEntropyFlow(gr: *const graph.CompositionGraph, cat: *const catalog.Catalog) ?errors.C1Error {
    for (gr.kdf_calls) |call| {
        const kdf = cat.findKDF(call.kdf_name) orelse continue;

        for (call.inputs) |input_ref| {
            const r = input_ref.ref();
            if (r != .value) continue;

            const v = graph.findValue(gr, r.value) orelse continue;

            const effective_entropy = switch (input_ref) {
                .on_failure => |f| f.fallback,
                else => v.entropy,
            };

            const provided_bits = effective_entropy.minEntropyBits();
            const required_bits = kdf.requiredInputBits(call.out_bits);

            if (provided_bits < required_bits or !kdf.accepts(effective_entropy, call.out_bits)) {
                return .{ .entropy_underflow = .{ .kdf_call = call.id, .input = r.value, .provided_bits = provided_bits, .required_bits = required_bits } };
            }

            const required_ctx = call.in_required_ctx_kind;
            if (required_ctx != .none) {
                switch (effective_entropy) {
                    .conditioned => |c| {
                        if (!g.ctxCompatible(c.ctx_kind, required_ctx)) {
                            return .{ .entropy_wrong_context = .{ .kdf_call = call.id, .input = r.value, .provided_ctx = c.ctx_kind, .required_ctx = required_ctx } };
                        }
                    },
                    else => {
                        return .{ .entropy_missing_conditioning = .{ .kdf_call = call.id, .input = r.value, .provided = effective_entropy, .required_ctx = required_ctx } };
                    },
                }
            }

            if (input_ref.isFailurePath()) {
                // TODO(v0.2+): decide whether this belongs in C1 or purely C4.
                // For now, we don't error here; C4 is the authoritative failure-leak check.
            }
        }
    }
    return null;
}
