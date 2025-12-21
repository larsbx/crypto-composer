const std = @import("std");
const g = @import("ground.zig");
const notions = @import("notions.zig");
const asm = @import("assumptions.zig");

pub const KEMContract = struct {
    name: []const u8,
    notion: notions.ConfNotion,
    assumption: asm.Assumption,
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
    timing: g.TimingClass,
    max_output_bytes: u32,

    pub fn accepts(self: @This(), input: g.EntropyClass) bool {
        _ = self;
        const min_required: u16 = 128; // TODO(v0.2+): couple this to security level / product.
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

pub const AEADContract = struct {
    name: []const u8,
    notion: notions.ConfNotion,
    level: g.SecurityLevel,

    key_bits: u16,
    nonce_bits: u16,
    tag_bits: u16,

    nonce_requirement: NonceRequirement,
    key_committing: bool,
    timing: g.TimingClass,

    max_message_bytes: u64,
    max_messages_per_key: u64,
};

pub const SigContract = struct {
    name: []const u8,
    notion: notions.IntNotion,
    assumption: asm.Assumption,
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

pub const WireFormat = struct {
    // TODO(v0.2+): TLS, HPKE, COSE wire encoding rules.
    _reserved: void = {},
};

pub const Product = struct {
    name: []const u8,
    protocol_id: []const u8,
    requirements: ProductRequirements,
    wire_format: ?WireFormat = null, // TODO(v0.2+): attach encoding rules.
};
