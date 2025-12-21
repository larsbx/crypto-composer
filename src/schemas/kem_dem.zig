const std = @import("std");
const contracts = @import("../types/contracts.zig");
const g = @import("../types/ground.zig");
const graph = @import("graph.zig");
const hybrid = @import("hybrid_kem.zig");

fn findKEM(bindings: []const contracts.Binding, slot_name: []const u8) ?*const contracts.KEMContract {
    for (bindings) |b| if (std.mem.eql(u8, b.slot_name, slot_name)) return switch (b.primitive) { .kem => |k| k, else => null };
    return null;
}
fn findKDF(bindings: []const contracts.Binding, slot_name: []const u8) ?*const contracts.KDFContract {
    for (bindings) |b| if (std.mem.eql(u8, b.slot_name, slot_name)) return switch (b.primitive) { .kdf => |k| k, else => null };
    return null;
}
fn findAEAD(bindings: []const contracts.Binding, slot_name: []const u8) ?*const contracts.AEADContract {
    for (bindings) |b| if (std.mem.eql(u8, b.slot_name, slot_name)) return switch (b.primitive) { .aead => |a| a, else => null };
    return null;
}

fn buildSuiteId(allocator: std.mem.Allocator, kem: *const contracts.KEMContract, kdf: *const contracts.KDFContract, aead: *const contracts.AEADContract) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{s}+{s}+{s}", .{ kem.name, kdf.name, aead.name });
}

/// KEMDEM seal (sender): encap + derive key+nonce + aead seal.
/// message_id required for nonce derivation.
pub fn expandKEMDEMSeal(
    allocator: std.mem.Allocator,
    bindings: []const contracts.Binding,
    product: *const contracts.Product,
    message_id: u64,
) !graph.CompositionGraph {
    const kem = findKEM(bindings, "kem") orelse return error.MissingBinding;
    const kdf = findKDF(bindings, "kdf") orelse return error.MissingBinding;
    const aead = findAEAD(bindings, "aead") orelse return error.MissingBinding;

    const suite_id = try buildSuiteId(allocator, kem, kdf, aead);

    const session_ctx = graph.DerivationContext{
        .schema_id = "KEMDEM",
        .protocol_id = product.protocol_id,
        .suite_id = suite_id,
        .transcript_hash = null,
        .message_id = null,
    };
    const message_ctx = graph.DerivationContext{
        .schema_id = "KEMDEM",
        .protocol_id = product.protocol_id,
        .suite_id = suite_id,
        .transcript_hash = null,
        .message_id = message_id,
    };

    const key_label = try hybrid.canonicalLabel(allocator, product.protocol_id, "KEMDEM", .session, .key, "aead_key");
    const nonce_disc = try std.fmt.allocPrint(allocator, "msg_{d}", .{message_id});
    const nonce_label = try hybrid.canonicalLabel(allocator, product.protocol_id, "KEMDEM", .message, .nonce, nonce_disc);

    var values = std.ArrayList(graph.Value).init(allocator);
    var kem_ops = std.ArrayList(graph.KemOp).init(allocator);
    var kdf_calls = std.ArrayList(graph.KDFCall).init(allocator);
    var aead_ops = std.ArrayList(graph.AeadOp).init(allocator);
    var edges = std.ArrayList(graph.FlowEdge).init(allocator);
    var outputs = std.ArrayList(graph.Output).init(allocator);

    // Inputs
    try values.append(.{ .name = "plaintext", .entropy = .{ .uniform = 0 }, .timing = .constant_time, .secret = true, .source = .input });
    try values.append(.{ .name = "aad", .entropy = .{ .uniform = 0 }, .timing = .constant_time, .secret = false, .source = .input });

    // KEM outputs
    try values.append(.{ .name = "kem_ct", .entropy = .{ .uniform = 0 }, .timing = .constant_time, .secret = false, .source = .{ .kem_op = .{ .op_id = "kem_encap", .output_kind = .ciphertext } } });
    try values.append(.{ .name = "kem_ss", .entropy = kem.ss_entropy_success, .timing = kem.timing, .secret = true, .source = .{ .kem_op = .{ .op_id = "kem_encap", .output_kind = .shared_secret_success } } });

    // KDF outputs
    try values.append(.{ .name = "aead_key", .entropy = kdf.outputEntropy(.key, aead.key_bits, .transcript_bound), .timing = kdf.timing, .secret = true, .source = .{ .kdf_call = "kdf_key" } });
    try values.append(.{ .name = "aead_nonce", .entropy = kdf.outputEntropy(.nonce, aead.nonce_bits, .message_bound), .timing = kdf.timing, .secret = false, .source = .{ .kdf_call = "kdf_nonce" } });

    // AEAD output
    try values.append(.{ .name = "aead_ct", .entropy = .{ .uniform = 0 }, .timing = .constant_time, .secret = false, .source = .{ .aead_op = .{ .op_id = "aead_seal", .output_kind = .ciphertext } } });

    // Structural reject boundary
    try values.append(.{ .name = "reject_boundary", .entropy = .{ .uniform = 0 }, .timing = .constant_time, .secret = false, .source = .structural });

    // KEM op (encap)
    try kem_ops.append(.{
        .id = "kem_encap",
        .kem_name = kem.name,
        .kind = .encap,
        .inputs = &[_]graph.Ref{},
        .ct_out = "kem_ct",
        .ss_success_out = "kem_ss",
        .ss_failure_out = null,
        .out_ctx_kind_success = .transcript_bound,
        .out_ctx_kind_failure = null,
    });

    // KDF calls
    try kdf_calls.append(.{
        .id = "kdf_key",
        .kdf_name = kdf.name,
        .inputs = &[_]graph.ValueRef{ .{ .direct = .{ .value = "kem_ss" } } },
        .in_required_ctx_kind = .transcript_bound,
        .label = key_label,
        .ctx = session_ctx,
        .scope = .session,
        .use = .key,
        .out_bits = aead.key_bits,
        .out_name = "aead_key",
        .out_ctx_kind = .transcript_bound,
    });

    try kdf_calls.append(.{
        .id = "kdf_nonce",
        .kdf_name = kdf.name,
        .inputs = &[_]graph.ValueRef{ .{ .direct = .{ .value = "kem_ss" } } },
        .in_required_ctx_kind = .transcript_bound,
        .label = nonce_label,
        .ctx = message_ctx,
        .scope = .message,
        .use = .nonce,
        .out_bits = aead.nonce_bits,
        .out_name = "aead_nonce",
        .out_ctx_kind = .message_bound,
    });

    // AEAD seal op
    try aead_ops.append(.{
        .id = "aead_seal",
        .aead_name = aead.name,
        .kind = .seal,
        .key = .{ .value = "aead_key" },
        .nonce = .{ .value = "aead_nonce" },
        .aad = .{ .value = "aad" },
        .plaintext = .{ .value = "plaintext" },
        .ciphertext = null,
        .ct_out = "aead_ct",
        .pt_out = null,
        .failure_out = null,
    });

    // Edges
    try edges.append(.{ .from = .{ .direct = .{ .kdf_call = "kdf_key" } }, .to = .{ .value = "aead_key" } });
    try edges.append(.{ .from = .{ .direct = .{ .kdf_call = "kdf_nonce" } }, .to = .{ .value = "aead_nonce" } });
    try edges.append(.{ .from = .{ .direct = .{ .aead_op = "aead_seal" } }, .to = .{ .value = "aead_ct" } });

    // Outputs
    try outputs.append(.{ .name = "kem_ciphertext", .value = "kem_ct", .kind = .value, .public = true });
    try outputs.append(.{ .name = "aead_ciphertext", .value = "aead_ct", .kind = .value, .public = true });
    try outputs.append(.{ .name = "reject", .value = "reject_boundary", .kind = .reject_boundary, .public = false });

    return .{
        .values = try values.toOwnedSlice(),
        .kem_ops = try kem_ops.toOwnedSlice(),
        .kdf_calls = try kdf_calls.toOwnedSlice(),
        .aead_ops = try aead_ops.toOwnedSlice(),
        .edges = try edges.toOwnedSlice(),
        .outputs = try outputs.toOwnedSlice(),
    };
}

/// KEMDEM open (receiver): decap can fail; aead open can fail.
pub fn expandKEMDEMOpen(
    allocator: std.mem.Allocator,
    bindings: []const contracts.Binding,
    product: *const contracts.Product,
    message_id: u64,
) !graph.CompositionGraph {
    const kem = findKEM(bindings, "kem") orelse return error.MissingBinding;
    const kdf = findKDF(bindings, "kdf") orelse return error.MissingBinding;
    const aead = findAEAD(bindings, "aead") orelse return error.MissingBinding;

    const suite_id = try buildSuiteId(allocator, kem, kdf, aead);

    const session_ctx = graph.DerivationContext{
        .schema_id = "KEMDEM",
        .protocol_id = product.protocol_id,
        .suite_id = suite_id,
        .transcript_hash = null,
        .message_id = null,
    };
    const message_ctx = graph.DerivationContext{
        .schema_id = "KEMDEM",
        .protocol_id = product.protocol_id,
        .suite_id = suite_id,
        .transcript_hash = null,
        .message_id = message_id,
    };

    const key_label = try hybrid.canonicalLabel(allocator, product.protocol_id, "KEMDEM", .session, .key, "aead_key");
    const nonce_disc = try std.fmt.allocPrint(allocator, "msg_{d}", .{message_id});
    const nonce_label = try hybrid.canonicalLabel(allocator, product.protocol_id, "KEMDEM", .message, .nonce, nonce_disc);

    var values = std.ArrayList(graph.Value).init(allocator);
    var kem_ops = std.ArrayList(graph.KemOp).init(allocator);
    var kdf_calls = std.ArrayList(graph.KDFCall).init(allocator);
    var aead_ops = std.ArrayList(graph.AeadOp).init(allocator);
    var edges = std.ArrayList(graph.FlowEdge).init(allocator);
    var outputs = std.ArrayList(graph.Output).init(allocator);

    // Inputs
    try values.append(.{ .name = "kem_sk", .entropy = .{ .uniform = 0 }, .timing = .constant_time, .secret = true, .source = .input });
    try values.append(.{ .name = "kem_ct", .entropy = .{ .uniform = 0 }, .timing = .constant_time, .secret = false, .source = .input });
    try values.append(.{ .name = "aead_ct", .entropy = .{ .uniform = 0 }, .timing = .constant_time, .secret = false, .source = .input });
    try values.append(.{ .name = "aad", .entropy = .{ .uniform = 0 }, .timing = .constant_time, .secret = false, .source = .input });

    // KEM decap outputs
    try values.append(.{ .name = "kem_ss_success", .entropy = kem.ss_entropy_success, .timing = kem.timing, .secret = true, .source = .{ .kem_op = .{ .op_id = "kem_decap", .output_kind = .shared_secret_success } } });
    try values.append(.{ .name = "kem_ss_failure", .entropy = kem.ss_entropy_failure, .timing = kem.timing, .secret = true, .source = .{ .kem_op = .{ .op_id = "kem_decap", .output_kind = .shared_secret_failure } } });

    // KDF outputs (success-only)
    try values.append(.{ .name = "aead_key", .entropy = kdf.outputEntropy(.key, aead.key_bits, .transcript_bound), .timing = kdf.timing, .secret = true, .source = .{ .kdf_call = "kdf_key" } });
    try values.append(.{ .name = "aead_nonce", .entropy = kdf.outputEntropy(.nonce, aead.nonce_bits, .message_bound), .timing = kdf.timing, .secret = false, .source = .{ .kdf_call = "kdf_nonce" } });

    // Plaintext output
    try values.append(.{ .name = "plaintext", .entropy = .{ .uniform = 0 }, .timing = .constant_time, .secret = true, .source = .{ .aead_op = .{ .op_id = "aead_open", .output_kind = .plaintext } } });

    // Structural reject boundary
    try values.append(.{ .name = "reject_boundary", .entropy = .{ .uniform = 0 }, .timing = .constant_time, .secret = false, .source = .structural });

    // KEM op (decap)
    try kem_ops.append(.{
        .id = "kem_decap",
        .kem_name = kem.name,
        .kind = .decap,
        .inputs = &[_]graph.Ref{ .{ .value = "kem_sk" }, .{ .value = "kem_ct" } },
        .ct_out = null,
        .ss_success_out = "kem_ss_success",
        .ss_failure_out = "kem_ss_failure",
        .out_ctx_kind_success = .transcript_bound,
        .out_ctx_kind_failure = .ciphertext_bound,
    });

    // KDF calls (success-only inputs)
    try kdf_calls.append(.{
        .id = "kdf_key",
        .kdf_name = kdf.name,
        .inputs = &[_]graph.ValueRef{ .{ .on_success = .{ .value = "kem_ss_success" } } },
        .in_required_ctx_kind = .transcript_bound,
        .label = key_label,
        .ctx = session_ctx,
        .scope = .session,
        .use = .key,
        .out_bits = aead.key_bits,
        .out_name = "aead_key",
        .out_ctx_kind = .transcript_bound,
    });
    try kdf_calls.append(.{
        .id = "kdf_nonce",
        .kdf_name = kdf.name,
        .inputs = &[_]graph.ValueRef{ .{ .on_success = .{ .value = "kem_ss_success" } } },
        .in_required_ctx_kind = .transcript_bound,
        .label = nonce_label,
        .ctx = message_ctx,
        .scope = .message,
        .use = .nonce,
        .out_bits = aead.nonce_bits,
        .out_name = "aead_nonce",
        .out_ctx_kind = .message_bound,
    });

    // AEAD open
    try aead_ops.append(.{
        .id = "aead_open",
        .aead_name = aead.name,
        .kind = .open,
        .key = .{ .value = "aead_key" },
        .nonce = .{ .value = "aead_nonce" },
        .aad = .{ .value = "aad" },
        .plaintext = null,
        .ciphertext = .{ .value = "aead_ct" },
        .ct_out = null,
        .pt_out = "plaintext",
        .failure_out = "reject_boundary",
    });

    // Edges: KDF -> values
    try edges.append(.{ .from = .{ .direct = .{ .kdf_call = "kdf_key" } }, .to = .{ .value = "aead_key" } });
    try edges.append(.{ .from = .{ .direct = .{ .kdf_call = "kdf_nonce" } }, .to = .{ .value = "aead_nonce" } });

    // AEAD success -> plaintext
    try edges.append(.{ .from = .{ .on_success = .{ .aead_op = "aead_open" } }, .to = .{ .value = "plaintext" } });

    // Failures -> reject
    try edges.append(.{ .from = .{ .on_failure = .{ .source = .{ .value = "kem_ss_failure" }, .fallback = kem.ss_entropy_failure } }, .to = .{ .value = "reject_boundary" } });
    try edges.append(.{ .from = .{ .on_failure = .{ .source = .{ .aead_op = "aead_open" }, .fallback = .{ .uniform = 0 } } }, .to = .{ .value = "reject_boundary" } });

    // Outputs
    try outputs.append(.{ .name = "plaintext", .value = "plaintext", .kind = .value, .public = false });
    try outputs.append(.{ .name = "reject", .value = "reject_boundary", .kind = .reject_boundary, .public = false });

    return .{
        .values = try values.toOwnedSlice(),
        .kem_ops = try kem_ops.toOwnedSlice(),
        .kdf_calls = try kdf_calls.toOwnedSlice(),
        .aead_ops = try aead_ops.toOwnedSlice(),
        .edges = try edges.toOwnedSlice(),
        .outputs = try outputs.toOwnedSlice(),
    };
}
