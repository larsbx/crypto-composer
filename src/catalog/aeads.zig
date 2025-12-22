const std = @import("std");
const c = @import("../types/contracts.zig");
const g = @import("../types/ground.zig");
const notions = @import("../types/notions.zig");

pub const AES_256_GCM = c.AEADContract{
    .name = "AES-256-GCM",
    .notion = .ind_cca2, // TODO(v0.2+): tighten with AEAD notion.
    .level = .{ .bits = 128 },
    .key_bits = 256,
    .nonce_bits = 96,
    .tag_bits = 128,
    .nonce_requirement = .unique_required,
    .key_committing = false, // TODO(v0.2+): represent key-commit variants.
    .timing = .constant_time,
    .max_message_bytes = 64 * 1024 * 1024 * 1024,
    .max_messages_per_key = 1 << 32,
};

pub const CHACHA20_POLY1305 = c.AEADContract{
    .name = "ChaCha20-Poly1305",
    .notion = .ind_cca2, // TODO(v0.2+): tighten with AEAD notion.
    .level = .{ .bits = 128 },
    .key_bits = 256,
    .nonce_bits = 96,
    .tag_bits = 128,
    .nonce_requirement = .unique_required,
    .key_committing = false,
    .timing = .constant_time,
    .max_message_bytes = 64 * 1024 * 1024 * 1024,
    .max_messages_per_key = 1 << 32,
};

pub const XCHACHA20_POLY1305 = c.AEADContract{
    .name = "XChaCha20-Poly1305",
    .notion = .ind_cca2, // TODO(v0.2+): tighten with AEAD notion.
    .level = .{ .bits = 128 },
    .key_bits = 256,
    .nonce_bits = 192,
    .tag_bits = 128,
    .nonce_requirement = .unique_required,
    .key_committing = false,
    .timing = .constant_time,
    .max_message_bytes = 64 * 1024 * 1024 * 1024,
    .max_messages_per_key = 1 << 32,
};

pub fn findByName(name: []const u8) ?*const c.AEADContract {
    if (std.mem.eql(u8, name, AES_256_GCM.name)) return &AES_256_GCM;
    if (std.mem.eql(u8, name, CHACHA20_POLY1305.name)) return &CHACHA20_POLY1305;
    if (std.mem.eql(u8, name, XCHACHA20_POLY1305.name)) return &XCHACHA20_POLY1305;
    return null;
}
