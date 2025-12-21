const g = @import("../types/ground.zig");
const graph = @import("../schemas/graph.zig");

pub const C1Error = union(enum) {
    entropy_underflow: struct { kdf_call: []const u8, input: []const u8, provided_bits: u16, required_bits: u16 },
    entropy_missing_conditioning: struct { kdf_call: []const u8, input: []const u8, provided: g.EntropyClass, required_ctx: g.CtxKind },
    entropy_wrong_context: struct { kdf_call: []const u8, input: []const u8, provided_ctx: g.CtxKind, required_ctx: g.CtxKind },
    entropy_failure_path_unhandled: struct { kdf_call: []const u8, input: []const u8, failure_entropy: g.EntropyClass }, // TODO(v0.2+): unify w/ C4.
};

pub const C2Error = struct { label: []const u8, call1: []const u8, call2: []const u8 };

pub const C3Error = union(enum) {
    nonce_not_message_scoped: struct { aead_op: []const u8, nonce_value: []const u8, actual_scope: ?g.Scope },
    nonce_missing_message_id: struct { kdf_call: []const u8 },
    nonce_wrong_context: struct { nonce_value: []const u8, provided_ctx: g.CtxKind, required_ctx: g.CtxKind },
    nonce_not_derived: struct { aead_op: []const u8, nonce_value: []const u8, source: graph.ValueSource },
};

pub const C4Error = union(enum) {
    failure_reaches_key: struct { failure_value: []const u8, reached_output: []const u8 },
    failure_not_terminated: struct { failure_value: []const u8 },
    // TODO(v0.2+): add explicit AEAD failure verification by op.failure_out edges.
};

pub const C5Warning = union(enum) {
    non_ct_primitive_in_secret_path: struct { primitive: []const u8, timing: g.TimingClass },
};

pub const W1Warning = union(enum) {
    same_assumption_class: struct { left: []const u8, right: []const u8, class: @import("../types/assumptions.zig").AssumptionClass },
};

pub const C6Error = struct { aead: []const u8, product_requires: bool };
