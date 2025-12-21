const std = @import("std");
const contracts = @import("../types/contracts.zig");
const g = @import("../types/ground.zig");
const graph = @import("graph.zig");

pub fn canonicalLabel(
    allocator: std.mem.Allocator,
    protocol_id: []const u8,
    schema_id: []const u8,
    scope: g.Scope,
    use: g.UseTag,
    discriminator: []const u8,
) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{s}/{s}/{s}/{s}/{s}", .{
        protocol_id,
        schema_id,
        @tagName(scope),
        @tagName(use),
        discriminator,
    });
}

fn findKEM(bindings: []const contracts.Binding, slot_name: []const u8) ?*const contracts.KEMContract {
    for (bindings) |b| {
        if (std.mem.eql(u8, b.slot_name, slot_name)) {
            return switch (b.primitive) {
                .kem => |k| k,
                else => null,
            };
        }
    }
    return null;
}

fn findKDF(bindings: []const contracts.Binding, slot_name: []const u8) ?*const contracts.KDFContract {
    for (bindings) |b| {
        if (std.mem.eql(u8, b.slot_name, slot_name)) {
            return switch (b.primitive) {
                .kdf => |k| k,
                else => null,
            };
        }
    }
    return null;
}

fn buildSuiteId(
    allocator: std.mem.Allocator,
    kem1: *const contracts.KEMContract,
    kem2: *const contracts.KEMContract,
    kdf: *const contracts.KDFContract,
) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{s}+{s}+{s}", .{ kem1.name, kem2.name, kdf.name });
}

/// HybridKEM (sender/encap): no failure paths.
pub fn expandHybridKEMEncap(
    allocator: std.mem.Allocator,
    bindings: []const contracts.Binding,
    product: *const contracts.Product,
) !graph.CompositionGraph {
    const classical = findKEM(bindings, "classical") orelse return error.MissingBinding;
    const pq = findKEM(bindings, "pq") orelse return error.MissingBinding;
    const kdf = findKDF(bindings, "kdf") orelse return error.MissingBinding;

    const suite_id = try buildSuiteId(allocator, classical, pq, kdf);

    const ctx = graph.DerivationContext{
        .schema_id = "HybridKEM",
        .protocol_id = product.protocol_id,
        .suite_id = suite_id,
        .transcript_hash = null,
        .message_id = null,
    };

    const combine_label = try canonicalLabel(allocator, product.protocol_id, "HybridKEM", .session, .key, "combine");

    var values = std.ArrayList(graph.Value).init(allocator);
    var kem_ops = std.ArrayList(graph.KemOp).init(allocator);
    var kdf_calls = std.ArrayList(graph.KDFCall).init(allocator);
    var aead_ops = std.ArrayList(graph.AeadOp).init(allocator);
    var edges = std.ArrayList(graph.FlowEdge).init(allocator);
    var outputs = std.ArrayList(graph.Output).init(allocator);

    // Ciphertexts
    try values.append(.{
        .name = "ct_classical",
        .entropy = .{ .uniform = 0 }, // TODO(v0.2+): model public randomness / distribution.
        .timing = .constant_time,
        .secret = false,
        .source = .{ .kem_op = .{ .op_id = "kem_classical", .output_kind = .ciphertext } },
    });
    try values.append(.{
        .name = "ct_pq",
        .entropy = .{ .uniform = 0 },
        .timing = .constant_time,
        .secret = false,
        .source = .{ .kem_op = .{ .op_id = "kem_pq", .output_kind = .ciphertext } },
    });

    // Shared secrets (encap success only)
    try values.append(.{
        .name = "ss_classical",
        .entropy = classical.ss_entropy_success,
        .timing = classical.timing,
        .secret = true,
        .source = .{ .kem_op = .{ .op_id = "kem_classical", .output_kind = .shared_secret_success } },
    });
    try values.append(.{
        .name = "ss_pq",
        .entropy = pq.ss_entropy_success,
        .timing = pq.timing,
        .secret = true,
        .source = .{ .kem_op = .{ .op_id = "kem_pq", .output_kind = .shared_secret_success } },
    });

    // Reject boundary structural
    try values.append(.{
        .name = "reject_boundary",
        .entropy = .{ .uniform = 0 },
        .timing = .constant_time,
        .secret = false,
        .source = .structural,
    });

    // KDF output
    try values.append(.{
        .name = "hybrid_ss",
        .entropy = kdf.outputEntropy(.key, 256, .transcript_bound),
        .timing = kdf.timing,
        .secret = true,
        .source = .{ .kdf_call = "kdf_combine" },
    });

    try kem_ops.append(.{
        .id = "kem_classical",
        .kem_name = classical.name,
        .kind = .encap,
        .inputs = &[_]graph.Ref{},
        .ct_out = "ct_classical",
        .ss_success_out = "ss_classical",
        .ss_failure_out = null,
        .out_ctx_kind_success = .transcript_bound,
        .out_ctx_kind_failure = null,
    });

    try kem_ops.append(.{
        .id = "kem_pq",
        .kem_name = pq.name,
        .kind = .encap,
        .inputs = &[_]graph.Ref{},
        .ct_out = "ct_pq",
        .ss_success_out = "ss_pq",
        .ss_failure_out = null,
        .out_ctx_kind_success = .transcript_bound,
        .out_ctx_kind_failure = null,
    });

    try kdf_calls.append(.{
        .id = "kdf_combine",
        .kdf_name = kdf.name,
        .inputs = &[_]graph.ValueRef{
            .{ .direct = .{ .value = "ss_classical" } },
            .{ .direct = .{ .value = "ss_pq" } },
        },
        .in_required_ctx_kind = .transcript_bound,
        .label = combine_label,
        .ctx = ctx,
        .scope = .session,
        .use = .key,
        .out_bits = 256,
        .out_name = "hybrid_ss",
        .out_ctx_kind = .transcript_bound,
    });

    // KDF -> value edge
    try edges.append(.{
        .from = .{ .direct = .{ .kdf_call = "kdf_combine" } },
        .to = .{ .value = "hybrid_ss" },
    });

    // Outputs
    try outputs.append(.{ .name = "ct_classical", .value = "ct_classical", .kind = .value, .public = true });
    try outputs.append(.{ .name = "ct_pq", .value = "ct_pq", .kind = .value, .public = true });
    try outputs.append(.{ .name = "shared_secret", .value = "hybrid_ss", .kind = .value, .public = false });
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

/// HybridKEM (receiver/decap): has failure paths.
pub fn expandHybridKEMDecap(
    allocator: std.mem.Allocator,
    bindings: []const contracts.Binding,
    product: *const contracts.Product,
) !graph.CompositionGraph {
    const classical = findKEM(bindings, "classical") orelse return error.MissingBinding;
    const pq = findKEM(bindings, "pq") orelse return error.MissingBinding;
    const kdf = findKDF(bindings, "kdf") orelse return error.MissingBinding;

    const suite_id = try buildSuiteId(allocator, classical, pq, kdf);

    const ctx = graph.DerivationContext{
        .schema_id = "HybridKEM",
        .protocol_id = product.protocol_id,
        .suite_id = suite_id,
        .transcript_hash = null,
        .message_id = null,
    };

    const combine_label = try canonicalLabel(allocator, product.protocol_id, "HybridKEM", .session, .key, "combine");

    var values = std.ArrayList(graph.Value).init(allocator);
    var kem_ops = std.ArrayList(graph.KemOp).init(allocator);
    var kdf_calls = std.ArrayList(graph.KDFCall).init(allocator);
    var aead_ops = std.ArrayList(graph.AeadOp).init(allocator);
    var edges = std.ArrayList(graph.FlowEdge).init(allocator);
    var outputs = std.ArrayList(graph.Output).init(allocator);

    // Inputs (sk + ct)
    try values.append(.{ .name = "sk_classical", .entropy = .{ .uniform = 0 }, .timing = .constant_time, .secret = true, .source = .input });
    try values.append(.{ .name = "sk_pq", .entropy = .{ .uniform = 0 }, .timing = .constant_time, .secret = true, .source = .input });
    try values.append(.{ .name = "ct_classical", .entropy = .{ .uniform = 0 }, .timing = .constant_time, .secret = false, .source = .input });
    try values.append(.{ .name = "ct_pq", .entropy = .{ .uniform = 0 }, .timing = .constant_time, .secret = false, .source = .input });

    // Decap outputs
    try values.append(.{
        .name = "ss_classical_success",
        .entropy = classical.ss_entropy_success,
        .timing = classical.timing,
        .secret = true,
        .source = .{ .kem_op = .{ .op_id = "kem_classical_decap", .output_kind = .shared_secret_success } },
    });
    try values.append(.{
        .name = "ss_classical_failure",
        .entropy = classical.ss_entropy_failure,
        .timing = classical.timing,
        .secret = true,
        .source = .{ .kem_op = .{ .op_id = "kem_classical_decap", .output_kind = .shared_secret_failure } },
    });

    try values.append(.{
        .name = "ss_pq_success",
        .entropy = pq.ss_entropy_success,
        .timing = pq.timing,
        .secret = true,
        .source = .{ .kem_op = .{ .op_id = "kem_pq_decap", .output_kind = .shared_secret_success } },
    });
    try values.append(.{
        .name = "ss_pq_failure",
        .entropy = pq.ss_entropy_failure,
        .timing = pq.timing,
        .secret = true,
        .source = .{ .kem_op = .{ .op_id = "kem_pq_decap", .output_kind = .shared_secret_failure } },
    });

    // Reject boundary structural
    try values.append(.{ .name = "reject_boundary", .entropy = .{ .uniform = 0 }, .timing = .constant_time, .secret = false, .source = .structural });

    // KDF output
    try values.append(.{ .name = "hybrid_ss", .entropy = kdf.outputEntropy(.key, 256, .transcript_bound), .timing = kdf.timing, .secret = true, .source = .{ .kdf_call = "kdf_combine" } });

    // Kem ops
    try kem_ops.append(.{
        .id = "kem_classical_decap",
        .kem_name = classical.name,
        .kind = .decap,
        .inputs = &[_]graph.Ref{ .{ .value = "sk_classical" }, .{ .value = "ct_classical" } },
        .ct_out = null,
        .ss_success_out = "ss_classical_success",
        .ss_failure_out = "ss_classical_failure",
        .out_ctx_kind_success = .transcript_bound,
        .out_ctx_kind_failure = .ciphertext_bound,
    });
    try kem_ops.append(.{
        .id = "kem_pq_decap",
        .kem_name = pq.name,
        .kind = .decap,
        .inputs = &[_]graph.Ref{ .{ .value = "sk_pq" }, .{ .value = "ct_pq" } },
        .ct_out = null,
        .ss_success_out = "ss_pq_success",
        .ss_failure_out = "ss_pq_failure",
        .out_ctx_kind_success = .transcript_bound,
        .out_ctx_kind_failure = .ciphertext_bound,
    });

    // KDF call success-only inputs
    try kdf_calls.append(.{
        .id = "kdf_combine",
        .kdf_name = kdf.name,
        .inputs = &[_]graph.ValueRef{
            .{ .on_success = .{ .value = "ss_classical_success" } },
            .{ .on_success = .{ .value = "ss_pq_success" } },
        },
        .in_required_ctx_kind = .transcript_bound,
        .label = combine_label,
        .ctx = ctx,
        .scope = .session,
        .use = .key,
        .out_bits = 256,
        .out_name = "hybrid_ss",
        .out_ctx_kind = .transcript_bound,
    });

    // KDF -> value edge
    try edges.append(.{ .from = .{ .direct = .{ .kdf_call = "kdf_combine" } }, .to = .{ .value = "hybrid_ss" } });

    // Failure edges -> reject boundary
    try edges.append(.{
        .from = .{ .on_failure = .{ .source = .{ .value = "ss_classical_failure" }, .fallback = classical.ss_entropy_failure } },
        .to = .{ .value = "reject_boundary" },
    });
    try edges.append(.{
        .from = .{ .on_failure = .{ .source = .{ .value = "ss_pq_failure" }, .fallback = pq.ss_entropy_failure } },
        .to = .{ .value = "reject_boundary" },
    });

    // Outputs
    try outputs.append(.{ .name = "shared_secret", .value = "hybrid_ss", .kind = .value, .public = false });
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
