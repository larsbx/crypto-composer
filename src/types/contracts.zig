const std = @import("std");
const g = @import("ground.zig");
const notions = @import("notions.zig");
const assumptions = @import("assumptions.zig");

pub const KEMContract = struct {
    name: []const u8,
    notion: notions.ConfNotion,
    assumption: assumptions.Assumption,
    level: g.SecurityLevel,

    pk_bytes: u16,
    sk_bytes: u16,
    ct_bytes: u16,
    ss_bytes: u16,

    ss_entropy_success: g.EntropyClass,
    ss_entropy_failure: g.EntropyClass,
    failure: g.FailureMode,
    timing: g.TimingClass,
};

pub const KDFContract = struct {
    name: []const u8,
    notion: notions.PrfNotion,
    level: g.SecurityLevel,
    timing: g.TimingClass,
    max_output_bytes: u32,

    pub fn requiredInputBits(self: @This(), out_bits: u16) u16 {
        return @min(out_bits, self.level.bits);
    }

    pub fn accepts(self: @This(), input: g.EntropyClass, out_bits: u16) bool {
        const min_required = self.requiredInputBits(out_bits);
        switch (input) {
            .conditioned => |c| return c.base.minEntropyBits() >= min_required,
            .uniform => |n| return n >= min_required,
            .min_entropy => |n| return n >= min_required,
            .computational => return false,
        }
    }

    pub fn outputEntropy(self: @This(), use: g.UseTag, out_bits: u16, ctx: g.CtxKind) g.EntropyClass {
        _ = self;
        _ = use;
        // TODO(v0.2+): outputs might be min_entropy not uniform depending on model assumptions.
        return .{ .conditioned = .{ .base = &.{ .uniform = out_bits }, .ctx_kind = ctx } };
    }
};

pub const NonceRequirement = union(enum) {
    unique_required,
    misuse_resistant: u32,
    misuse_immune,
    none,
};

pub const KeyCommitment = enum { non_committing, key_committing };

pub const AEADContract = struct {
    name: []const u8,
    notion: notions.AeadNotion,
    level: g.SecurityLevel,

    key_bits: u16,
    nonce_bits: u16,
    tag_bits: u16,

    nonce_requirement: NonceRequirement,
    key_commitment: KeyCommitment,
    timing: g.TimingClass,

    max_message_bytes: u64,
    max_messages_per_key: u64,

    pub fn isKeyCommitting(self: @This()) bool {
        return self.key_commitment == .key_committing;
    }
};

pub const SigContract = struct {
    name: []const u8,
    notion: notions.IntNotion,
    assumption: assumptions.Assumption,
    level: g.SecurityLevel,

    pk_bytes: u16,
    sk_bytes: u16,
    sig_bytes_min: u16,
    sig_bytes_max: u16,

    deterministic: bool,
    timing: g.TimingClass,
};

pub const Primitive = union(enum) {
    kem: *const KEMContract,
    kdf: *const KDFContract,
    aead: *const AEADContract,
    sig: *const SigContract,
};

pub const Binding = struct {
    slot_name: []const u8,
    primitive: Primitive,
};

pub const ProductRequirements = struct {
    key_committing: bool = false,
    forward_secrecy: bool = false,
    post_compromise_security: bool = false,
};

pub const WireFormat = enum {
    tls13,
    hpke,
    cose,

    pub fn protocolId(self: @This()) []const u8 {
        return switch (self) {
            .tls13 => "tls13",
            .hpke => "hpke",
            .cose => "cose",
        };
    }
};

pub const Product = struct {
    name: []const u8,
    protocol_id: []const u8,
    requirements: ProductRequirements,
    wire_format: ?WireFormat = null, // TODO(v0.2+): attach encoding rules.

    pub fn validate(self: *const @This()) !void {
        try validateProduct(self);
    }
};

pub fn validateProduct(product: *const Product) !void {
    if (product.protocol_id.len == 0) return error.InvalidProtocolId;
    if (product.wire_format) |wf| {
        if (!std.mem.eql(u8, product.protocol_id, wf.protocolId())) {
            return error.WireFormatProtocolMismatch;
        }
    }
}
