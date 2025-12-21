const std = @import("std");
const graph = @import("../schemas/graph.zig");
const g = @import("../types/ground.zig");
const catalog = @import("../catalog/mod.zig");
const errors = @import("errors.zig");

pub fn checkNonceDiscipline(gr: *const graph.CompositionGraph, cat: *const catalog.Catalog) ?errors.C3Error {
    for (gr.aead_ops) |op| {
        const aead = cat.findAEAD(op.aead_name) orelse continue;

        switch (aead.nonce_requirement) {
            .unique_required => {},
            else => continue,
        }

        if (op.nonce != .value) continue;
        const nonce_name = op.nonce.value;
        const nonce_val = graph.findValue(gr, nonce_name) orelse continue;

        const kdf_id = switch (nonce_val.source) {
            .kdf_call => |id| id,
            else => return .{ .nonce_not_derived = .{ .aead_op = op.id, .nonce_value = nonce_name, .source = nonce_val.source } },
        };

        const kdf_call = graph.findKdfCall(gr, kdf_id) orelse continue;

        if (kdf_call.scope != .message) {
            return .{ .nonce_not_message_scoped = .{ .aead_op = op.id, .nonce_value = nonce_name, .actual_scope = kdf_call.scope } };
        }
        if (kdf_call.ctx.message_id == null) {
            return .{ .nonce_missing_message_id = .{ .kdf_call = kdf_call.id } };
        }

        const nonce_ctx = switch (nonce_val.entropy) {
            .conditioned => |c| c.ctx_kind,
            else => .none,
        };

        if (nonce_ctx != .message_bound) {
            return .{ .nonce_wrong_context = .{ .nonce_value = nonce_name, .provided_ctx = nonce_ctx, .required_ctx = .message_bound } };
        }
    }
    return null;
}
