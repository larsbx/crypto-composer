const std = @import("std");
const g = @import("../types/ground.zig");

pub const DerivationContext = struct {
    schema_id: []const u8,
    protocol_id: []const u8,
    suite_id: []const u8,
    transcript_hash: ?[32]u8,
    message_id: ?u64, // Required iff scope = message (validated).
};

pub const Ref = union(enum) {
    value: []const u8,
    kem_op: []const u8,
    kdf_call: []const u8,
    aead_op: []const u8,

    pub fn name(self: @This()) []const u8 {
        return switch (self) {
            inline else => |n| n,
        };
    }
};

pub const ValueRef = union(enum) {
    direct: Ref,
    on_success: Ref,
    on_failure: struct {
        source: Ref,
        fallback: g.EntropyClass,
    },

    pub fn ref(self: @This()) Ref {
        return switch (self) {
            .direct => |r| r,
            .on_success => |r| r,
            .on_failure => |f| f.source,
        };
    }

    pub fn isFailurePath(self: @This()) bool {
        return self == .on_failure;
    }

    pub fn isSuccessPath(self: @This()) bool {
        return self == .on_success;
    }
};

pub const KemOutputKind = enum {
    ciphertext,
    shared_secret_success,
    shared_secret_failure,
};

pub const AeadOutputKind = enum { ciphertext, plaintext };

pub const ValueSource = union(enum) {
    input,
    structural,

    kem_op: struct {
        op_id: []const u8,
        output_kind: KemOutputKind,
    },

    kdf_call: []const u8,

    aead_op: struct {
        op_id: []const u8,
        output_kind: AeadOutputKind,
    },
};

pub const Value = struct {
    name: []const u8,
    entropy: g.EntropyClass,
    timing: g.TimingClass,
    secret: bool,
    source: ValueSource,
};

pub const KemOpKind = enum { encap, decap };

pub const KemOp = struct {
    id: []const u8,
    kem_name: []const u8,
    kind: KemOpKind,
    inputs: []const Ref,

    ct_out: ?[]const u8,        // encap only
    ss_success_out: []const u8, // always
    ss_failure_out: ?[]const u8, // decap only

    out_ctx_kind_success: g.CtxKind,
    out_ctx_kind_failure: ?g.CtxKind,

    pub fn canFail(self: @This()) bool {
        return self.kind == .decap;
    }
};

pub const KDFCall = struct {
    id: []const u8,
    kdf_name: []const u8,

    inputs: []const ValueRef,
    in_required_ctx_kind: g.CtxKind,

    label: []const u8,
    ctx: DerivationContext,
    scope: g.Scope,
    use: g.UseTag,

    out_bits: u16,
    out_name: []const u8,
    out_ctx_kind: g.CtxKind,
};

pub const AeadOpKind = enum { seal, open };

pub const AeadOp = struct {
    id: []const u8,
    aead_name: []const u8,
    kind: AeadOpKind,

    key: Ref,
    nonce: Ref,
    aad: ?Ref,

    plaintext: ?Ref,   // seal only
    ciphertext: ?Ref,  // open only

    ct_out: ?[]const u8,
    pt_out: ?[]const u8,

    failure_out: ?[]const u8, // open only

    pub fn canFail(self: @This()) bool {
        return self.kind == .open;
    }
};

pub const FlowEdge = struct {
    from: ValueRef,
    to: Ref,
};

pub const OutputKind = enum { value, reject_boundary };

pub const Output = struct {
    name: []const u8,
    value: []const u8, // must reference Value.name
    kind: OutputKind,
    public: bool,
};

pub const CompositionGraph = struct {
    values: []const Value,
    kem_ops: []const KemOp,
    kdf_calls: []const KDFCall,
    aead_ops: []const AeadOp,
    edges: []const FlowEdge,
    outputs: []const Output,
};

// ---- helpers ----

pub fn findValue(graph: *const CompositionGraph, name: []const u8) ?*const Value {
    for (graph.values) |*v| if (std.mem.eql(u8, v.name, name)) return v;
    return null;
}

pub fn findKdfCall(graph: *const CompositionGraph, id: []const u8) ?*const KDFCall {
    for (graph.kdf_calls) |*c| if (std.mem.eql(u8, c.id, id)) return c;
    return null;
}

pub fn findAeadOp(graph: *const CompositionGraph, id: []const u8) ?*const AeadOp {
    for (graph.aead_ops) |*op| if (std.mem.eql(u8, op.id, id)) return op;
    return null;
}

pub fn findKemOp(graph: *const CompositionGraph, id: []const u8) ?*const KemOp {
    for (graph.kem_ops) |*op| if (std.mem.eql(u8, op.id, id)) return op;
    return null;
}
