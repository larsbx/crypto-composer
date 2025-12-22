const std = @import("std");
const c = @import("../types/contracts.zig");
const g = @import("../types/ground.zig");
const notions = @import("../types/notions.zig");

pub const X25519 = c.KEMContract{
    .name = "X25519",
    .notion = .ind_cca2, // TODO(v0.2+): debate notion for DH KEX mapping.
    .assumption = .{ .name = "DDH(Curve25519)", .class = .discrete_log, .params = "Curve25519" },
    .level = .{ .bits = 128 },
    .pk_bytes = 32,
    .sk_bytes = 32,
    .ct_bytes = 32,
    .ss_bytes = 32,
    .ss_entropy_success = .{ .conditioned = .{ .base = &.{ .uniform = 256 }, .ctx_kind = .transcript_bound } },
    .ss_entropy_failure = .{ .conditioned = .{ .base = &.{ .min_entropy = 0 }, .ctx_kind = .ciphertext_bound } },
    .failure = .implicit_reject,
    .timing = .constant_time,
};

pub const P_256 = c.KEMContract{
    .name = "P-256",
    .notion = .ind_cca2, // TODO(v0.2+): debate notion for DH KEX mapping.
    .assumption = .{ .name = "DDH(P-256)", .class = .discrete_log, .params = "P-256" },
    .level = .{ .bits = 128 },
    .pk_bytes = 65,
    .sk_bytes = 32,
    .ct_bytes = 65,
    .ss_bytes = 32,
    .ss_entropy_success = .{ .conditioned = .{ .base = &.{ .uniform = 256 }, .ctx_kind = .transcript_bound } },
    .ss_entropy_failure = .{ .conditioned = .{ .base = &.{ .min_entropy = 0 }, .ctx_kind = .ciphertext_bound } },
    .failure = .implicit_reject,
    .timing = .constant_time,
};

pub const ML_KEM_768 = c.KEMContract{
    .name = "ML-KEM-768",
    .notion = .ind_cca2,
    .assumption = .{ .name = "MLWE(k=3)", .class = .lattice, .params = "k=3,n=256,q=3329" },
    .level = .{ .bits = 192 },
    .pk_bytes = 1184,
    .sk_bytes = 2400,
    .ct_bytes = 1088,
    .ss_bytes = 32,
    .ss_entropy_success = .{ .conditioned = .{ .base = &.{ .uniform = 256 }, .ctx_kind = .transcript_bound } },
    .ss_entropy_failure = .{ .conditioned = .{ .base = &.{ .min_entropy = 0 }, .ctx_kind = .ciphertext_bound } },
    .failure = .implicit_reject,
    .timing = .constant_time,
};

pub const ML_KEM_512 = c.KEMContract{
    .name = "ML-KEM-512",
    .notion = .ind_cca2,
    .assumption = .{ .name = "MLWE(k=2)", .class = .lattice, .params = "k=2,n=256,q=3329" },
    .level = .{ .bits = 128 },
    .pk_bytes = 800,
    .sk_bytes = 1632,
    .ct_bytes = 768,
    .ss_bytes = 32,
    .ss_entropy_success = .{ .conditioned = .{ .base = &.{ .uniform = 256 }, .ctx_kind = .transcript_bound } },
    .ss_entropy_failure = .{ .conditioned = .{ .base = &.{ .min_entropy = 0 }, .ctx_kind = .ciphertext_bound } },
    .failure = .implicit_reject,
    .timing = .constant_time,
};

pub const ML_KEM_1024 = c.KEMContract{
    .name = "ML-KEM-1024",
    .notion = .ind_cca2,
    .assumption = .{ .name = "MLWE(k=4)", .class = .lattice, .params = "k=4,n=256,q=3329" },
    .level = .{ .bits = 256 },
    .pk_bytes = 1568,
    .sk_bytes = 3168,
    .ct_bytes = 1568,
    .ss_bytes = 32,
    .ss_entropy_success = .{ .conditioned = .{ .base = &.{ .uniform = 256 }, .ctx_kind = .transcript_bound } },
    .ss_entropy_failure = .{ .conditioned = .{ .base = &.{ .min_entropy = 0 }, .ctx_kind = .ciphertext_bound } },
    .failure = .implicit_reject,
    .timing = .constant_time,
};

// TODO(v0.2+): add P-256 etc.

pub fn findByName(name: []const u8) ?*const c.KEMContract {
    if (std.mem.eql(u8, name, X25519.name)) return &X25519;
    if (std.mem.eql(u8, name, P_256.name)) return &P_256;
    if (std.mem.eql(u8, name, ML_KEM_512.name)) return &ML_KEM_512;
    if (std.mem.eql(u8, name, ML_KEM_768.name)) return &ML_KEM_768;
    if (std.mem.eql(u8, name, ML_KEM_1024.name)) return &ML_KEM_1024;
    return null;
}
