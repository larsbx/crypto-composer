const std = @import("std");
const composer = @import("composer");
const harness = @import("harness.zig");
const generator = @import("constraint_test_generator");
const graph = composer.schemas.graph;
const _constraint_tests = @import("constraint_tests.zig");

test "proof helper rejects empty proof" {
    const proof = harness.Proof{
        .statement = "Proof helpers reject empty statements/arguments before tests run.",
        .argument = "PDD requires explicit reasoning; missing fields must fail fast.",
        .constraints = &[_]harness.ConstraintId{.meta_pdd},
    };
    try harness.requireProof(proof);

    try std.testing.expectError(error.MissingProofStatement, harness.requireProof(.{
        .statement = "",
        .argument = "x",
        .constraints = &[_]harness.ConstraintId{.meta_pdd},
    }));
    try std.testing.expectError(error.MissingProofArgument, harness.requireProof(.{
        .statement = "x",
        .argument = "",
        .constraints = &[_]harness.ConstraintId{.meta_pdd},
    }));
    try std.testing.expectError(error.MissingProofConstraints, harness.requireProof(.{
        .statement = "x",
        .argument = "y",
        .constraints = &[_]harness.ConstraintId{},
    }));
}

test "constraint test generator emits proof-bound stubs" {
    const proof = harness.Proof{
        .statement = "Generator emits proof-bound stubs for each constraint.",
        .argument = "Generated tests must include proofs and constraint bindings to enforce PDD.",
        .constraints = &[_]harness.ConstraintId{.meta_pdd},
    };
    try harness.requireProof(proof);

    const out = try generator.generate(std.testing.allocator, .{
        .constraints = &[_][]const u8{ "c1_entropy_flow", "c2_domain_sep" },
    });
    defer std.testing.allocator.free(out);

    try std.testing.expect(std.mem.containsAtLeast(u8, out, 1, "test \"Constraints c1_entropy_flow negative\""));
    try std.testing.expect(std.mem.containsAtLeast(u8, out, 1, "test \"Constraints c2_domain_sep positive\""));
    try std.testing.expect(std.mem.containsAtLeast(u8, out, 1, "const proof = harness.Proof"));
    try std.testing.expect(std.mem.containsAtLeast(u8, out, 1, "try harness.requireProofForConstraint"));
    try std.testing.expect(std.mem.containsAtLeast(u8, out, 1, "valid construction."));
    try std.testing.expect(
        std.mem.containsAtLeast(u8, out, 1, ".constraints = &[_]harness.ConstraintId{ .c1_entropy_flow }"),
    );
}

test "catalog includes ML-KEM-512 and ML-KEM-1024" {
    const proof = harness.Proof{
        .statement = "The catalog should expose the full ML-KEM parameter set.",
        .argument = "Downstream schemas should be able to bind ML-KEM-512 and ML-KEM-1024 by name.",
        .constraints = &[_]harness.ConstraintId{.meta_pdd},
    };
    try harness.requireProof(proof);

    try std.testing.expect(composer.catalog.kems.findByName("ML-KEM-512") != null);
    try std.testing.expect(composer.catalog.kems.findByName("ML-KEM-1024") != null);
}

test "C1 rejects insufficient entropy input" {
    const proof = harness.Proof{
        .statement = "Entropy underflow in KDF input must be rejected (C1).",
        .argument = "The KDF input provides only 64 bits, below the 128-bit minimum.",
        .constraints = &[_]harness.ConstraintId{.c1_entropy_flow},
    };

    const cat = composer.catalog.DefaultCatalog;
    const kdf = composer.catalog.kdfs.HKDF_SHA256;
    const ctx = graph.DerivationContext{
        .schema_id = "Test",
        .protocol_id = "test",
        .suite_id = "suite",
        .transcript_hash = null,
        .message_id = null,
    };

    const values = [_]graph.Value{
        .{ .name = "seed", .entropy = .{ .min_entropy = 64 }, .timing = .constant_time, .secret = true, .source = .input },
        .{ .name = "out", .entropy = kdf.outputEntropy(.key, 256, .transcript_bound), .timing = kdf.timing, .secret = true, .source = .{ .kdf_call = "kdf1" } },
        .{ .name = "reject_boundary", .entropy = .{ .uniform = 0 }, .timing = .constant_time, .secret = false, .source = .structural },
    };
    const kdf_calls = [_]graph.KDFCall{
        .{
            .id = "kdf1",
            .kdf_name = kdf.name,
            .inputs = &[_]graph.ValueRef{.{ .direct = .{ .value = "seed" } }},
            .in_required_ctx_kind = .none,
            .label = "test/kdf1",
            .ctx = ctx,
            .scope = .session,
            .use = .key,
            .out_bits = 256,
            .out_name = "out",
            .out_ctx_kind = .transcript_bound,
        },
    };
    const edges = [_]graph.FlowEdge{
        .{ .from = .{ .direct = .{ .kdf_call = "kdf1" } }, .to = .{ .value = "out" } },
    };
    const outputs = [_]graph.Output{
        .{ .name = "out", .value = "out", .kind = .value, .public = false },
        .{ .name = "reject", .value = "reject_boundary", .kind = .reject_boundary, .public = false },
    };

    const g = graph.CompositionGraph{
        .values = values[0..],
        .kem_ops = &[_]graph.KemOp{},
        .kdf_calls = kdf_calls[0..],
        .aead_ops = &[_]graph.AeadOp{},
        .edges = edges[0..],
        .outputs = outputs[0..],
    };

    try harness.expectConstraint(proof, std.testing.allocator, &g, &cat, .{}, .c1_entropy_flow, .present);
}

test "C1 accepts entropy at security level for short output" {
    const proof = harness.Proof{
        .statement = "C1 scales input entropy requirements with KDF security level.",
        .argument = "A 64-bit output only requires 64 bits of input entropy when the KDF level is higher.",
        .constraints = &[_]harness.ConstraintId{ .overall_valid, .c1_entropy_flow },
    };

    const cat = composer.catalog.DefaultCatalog;
    const kdf = composer.catalog.kdfs.HKDF_SHA256;
    const ctx = graph.DerivationContext{
        .schema_id = "Test",
        .protocol_id = "test",
        .suite_id = "suite",
        .transcript_hash = null,
        .message_id = null,
    };

    const values = [_]graph.Value{
        .{ .name = "seed", .entropy = .{ .uniform = 64 }, .timing = .constant_time, .secret = true, .source = .input },
        .{ .name = "out", .entropy = kdf.outputEntropy(.key, 64, .transcript_bound), .timing = kdf.timing, .secret = true, .source = .{ .kdf_call = "kdf1" } },
        .{ .name = "reject_boundary", .entropy = .{ .uniform = 0 }, .timing = .constant_time, .secret = false, .source = .structural },
    };
    const kdf_calls = [_]graph.KDFCall{
        .{
            .id = "kdf1",
            .kdf_name = kdf.name,
            .inputs = &[_]graph.ValueRef{.{ .direct = .{ .value = "seed" } }},
            .in_required_ctx_kind = .none,
            .label = "test/kdf1",
            .ctx = ctx,
            .scope = .session,
            .use = .key,
            .out_bits = 64,
            .out_name = "out",
            .out_ctx_kind = .transcript_bound,
        },
    };
    const edges = [_]graph.FlowEdge{
        .{ .from = .{ .direct = .{ .kdf_call = "kdf1" } }, .to = .{ .value = "out" } },
    };
    const outputs = [_]graph.Output{
        .{ .name = "out", .value = "out", .kind = .value, .public = false },
        .{ .name = "reject", .value = "reject_boundary", .kind = .reject_boundary, .public = false },
    };

    const g = graph.CompositionGraph{
        .values = values[0..],
        .kem_ops = &[_]graph.KemOp{},
        .kdf_calls = kdf_calls[0..],
        .aead_ops = &[_]graph.AeadOp{},
        .edges = edges[0..],
        .outputs = outputs[0..],
    };

    try harness.expectConstraint(proof, std.testing.allocator, &g, &cat, .{}, .c1_entropy_flow, .absent);
    try harness.expectConstraint(proof, std.testing.allocator, &g, &cat, .{}, .overall_valid, .present);
}

test "C2 rejects duplicate labels" {
    const proof = harness.Proof{
        .statement = "Domain separation requires unique labels (C2).",
        .argument = "Two KDF calls re-use the same label, which must fail.",
        .constraints = &[_]harness.ConstraintId{.c2_domain_sep},
    };

    const cat = composer.catalog.DefaultCatalog;
    const kdf = composer.catalog.kdfs.HKDF_SHA256;
    const ctx = graph.DerivationContext{
        .schema_id = "Test",
        .protocol_id = "test",
        .suite_id = "suite",
        .transcript_hash = null,
        .message_id = null,
    };

    const values = [_]graph.Value{
        .{ .name = "seed", .entropy = .{ .uniform = 256 }, .timing = .constant_time, .secret = true, .source = .input },
        .{ .name = "out1", .entropy = kdf.outputEntropy(.key, 256, .transcript_bound), .timing = kdf.timing, .secret = true, .source = .{ .kdf_call = "kdf1" } },
        .{ .name = "out2", .entropy = kdf.outputEntropy(.key, 256, .transcript_bound), .timing = kdf.timing, .secret = true, .source = .{ .kdf_call = "kdf2" } },
        .{ .name = "reject_boundary", .entropy = .{ .uniform = 0 }, .timing = .constant_time, .secret = false, .source = .structural },
    };
    const kdf_calls = [_]graph.KDFCall{
        .{
            .id = "kdf1",
            .kdf_name = kdf.name,
            .inputs = &[_]graph.ValueRef{.{ .direct = .{ .value = "seed" } }},
            .in_required_ctx_kind = .none,
            .label = "dup",
            .ctx = ctx,
            .scope = .session,
            .use = .key,
            .out_bits = 256,
            .out_name = "out1",
            .out_ctx_kind = .transcript_bound,
        },
        .{
            .id = "kdf2",
            .kdf_name = kdf.name,
            .inputs = &[_]graph.ValueRef{.{ .direct = .{ .value = "seed" } }},
            .in_required_ctx_kind = .none,
            .label = "dup",
            .ctx = ctx,
            .scope = .session,
            .use = .key,
            .out_bits = 256,
            .out_name = "out2",
            .out_ctx_kind = .transcript_bound,
        },
    };
    const edges = [_]graph.FlowEdge{
        .{ .from = .{ .direct = .{ .kdf_call = "kdf1" } }, .to = .{ .value = "out1" } },
        .{ .from = .{ .direct = .{ .kdf_call = "kdf2" } }, .to = .{ .value = "out2" } },
    };
    const outputs = [_]graph.Output{
        .{ .name = "out1", .value = "out1", .kind = .value, .public = false },
        .{ .name = "out2", .value = "out2", .kind = .value, .public = false },
        .{ .name = "reject", .value = "reject_boundary", .kind = .reject_boundary, .public = false },
    };

    const g = graph.CompositionGraph{
        .values = values[0..],
        .kem_ops = &[_]graph.KemOp{},
        .kdf_calls = kdf_calls[0..],
        .aead_ops = &[_]graph.AeadOp{},
        .edges = edges[0..],
        .outputs = outputs[0..],
    };

    try harness.expectConstraint(proof, std.testing.allocator, &g, &cat, .{}, .c2_domain_sep, .present);
}

test "C3 rejects non-derived nonce" {
    const proof = harness.Proof{
        .statement = "AEAD nonce must be derived from a message-scoped KDF (C3).",
        .argument = "Using an input nonce violates unique-required discipline.",
        .constraints = &[_]harness.ConstraintId{.c3_nonce_discipline},
    };

    const cat = composer.catalog.DefaultCatalog;
    const aead = composer.catalog.aeads.AES_256_GCM;

    const values = [_]graph.Value{
        .{ .name = "key", .entropy = .{ .uniform = 256 }, .timing = .constant_time, .secret = true, .source = .input },
        .{ .name = "nonce", .entropy = .{ .uniform = 96 }, .timing = .constant_time, .secret = false, .source = .input },
        .{ .name = "aad", .entropy = .{ .uniform = 0 }, .timing = .constant_time, .secret = false, .source = .input },
        .{ .name = "plaintext", .entropy = .{ .uniform = 0 }, .timing = .constant_time, .secret = true, .source = .input },
        .{ .name = "ct", .entropy = .{ .uniform = 0 }, .timing = .constant_time, .secret = false, .source = .{ .aead_op = .{ .op_id = "aead_seal", .output_kind = .ciphertext } } },
        .{ .name = "reject_boundary", .entropy = .{ .uniform = 0 }, .timing = .constant_time, .secret = false, .source = .structural },
    };
    const aead_ops = [_]graph.AeadOp{
        .{
            .id = "aead_seal",
            .aead_name = aead.name,
            .kind = .seal,
            .key = .{ .value = "key" },
            .nonce = .{ .value = "nonce" },
            .aad = .{ .value = "aad" },
            .plaintext = .{ .value = "plaintext" },
            .ciphertext = null,
            .ct_out = "ct",
            .pt_out = null,
            .failure_out = null,
        },
    };
    const edges = [_]graph.FlowEdge{
        .{ .from = .{ .direct = .{ .aead_op = "aead_seal" } }, .to = .{ .value = "ct" } },
    };
    const outputs = [_]graph.Output{
        .{ .name = "ciphertext", .value = "ct", .kind = .value, .public = true },
        .{ .name = "reject", .value = "reject_boundary", .kind = .reject_boundary, .public = false },
    };

    const g = graph.CompositionGraph{
        .values = values[0..],
        .kem_ops = &[_]graph.KemOp{},
        .kdf_calls = &[_]graph.KDFCall{},
        .aead_ops = aead_ops[0..],
        .edges = edges[0..],
        .outputs = outputs[0..],
    };

    try harness.expectConstraint(proof, std.testing.allocator, &g, &cat, .{}, .c3_nonce_discipline, .present);
}

test "C4 rejects failure reaching secret output" {
    const proof = harness.Proof{
        .statement = "Failure outputs must not reach secret outputs (C4).",
        .argument = "A decapsulation failure flows into a secret output without rejection.",
        .constraints = &[_]harness.ConstraintId{.c4_failure_consistency},
    };

    const cat = composer.catalog.DefaultCatalog;
    const kem = composer.catalog.kems.ML_KEM_768;

    const values = [_]graph.Value{
        .{ .name = "sk", .entropy = .{ .uniform = 0 }, .timing = .constant_time, .secret = true, .source = .input },
        .{ .name = "ct", .entropy = .{ .uniform = 0 }, .timing = .constant_time, .secret = false, .source = .input },
        .{ .name = "ss_success", .entropy = kem.ss_entropy_success, .timing = kem.timing, .secret = true, .source = .{ .kem_op = .{ .op_id = "kem_decap", .output_kind = .shared_secret_success } } },
        .{ .name = "ss_failure", .entropy = kem.ss_entropy_failure, .timing = kem.timing, .secret = true, .source = .{ .kem_op = .{ .op_id = "kem_decap", .output_kind = .shared_secret_failure } } },
        .{ .name = "leaked_key", .entropy = .{ .uniform = 0 }, .timing = .constant_time, .secret = true, .source = .structural },
        .{ .name = "reject_boundary", .entropy = .{ .uniform = 0 }, .timing = .constant_time, .secret = false, .source = .structural },
    };
    const kem_ops = [_]graph.KemOp{
        .{
            .id = "kem_decap",
            .kem_name = kem.name,
            .kind = .decap,
            .inputs = &[_]graph.Ref{ .{ .value = "sk" }, .{ .value = "ct" } },
            .ct_out = null,
            .ss_success_out = "ss_success",
            .ss_failure_out = "ss_failure",
            .out_ctx_kind_success = .transcript_bound,
            .out_ctx_kind_failure = .ciphertext_bound,
        },
    };
    const edges = [_]graph.FlowEdge{
        .{ .from = .{ .direct = .{ .value = "ss_failure" } }, .to = .{ .value = "leaked_key" } },
    };
    const outputs = [_]graph.Output{
        .{ .name = "leaked_key", .value = "leaked_key", .kind = .value, .public = false },
        .{ .name = "reject", .value = "reject_boundary", .kind = .reject_boundary, .public = false },
    };

    const g = graph.CompositionGraph{
        .values = values[0..],
        .kem_ops = kem_ops[0..],
        .kdf_calls = &[_]graph.KDFCall{},
        .aead_ops = &[_]graph.AeadOp{},
        .edges = edges[0..],
        .outputs = outputs[0..],
    };

    try harness.expectConstraint(proof, std.testing.allocator, &g, &cat, .{}, .c4_failure_consistency, .present);
}

test "C4 rejects AEAD failure without reject boundary" {
    const proof = harness.Proof{
        .statement = "AEAD failure paths must terminate at reject boundary (C4).",
        .argument = "An AEAD open failure is routed to a non-reject value with no path to rejection.",
        .constraints = &[_]harness.ConstraintId{.c4_failure_consistency},
    };

    const cat = composer.catalog.DefaultCatalog;
    const aead = composer.catalog.aeads.AES_256_GCM;
    const kdf = composer.catalog.kdfs.HKDF_SHA256;
    const ctx = graph.DerivationContext{
        .schema_id = "Test",
        .protocol_id = "test",
        .suite_id = "suite",
        .transcript_hash = null,
        .message_id = 0,
    };

    const values = [_]graph.Value{
        .{ .name = "key", .entropy = .{ .uniform = 256 }, .timing = .constant_time, .secret = true, .source = .input },
        .{ .name = "seed", .entropy = .{ .uniform = 256 }, .timing = .constant_time, .secret = true, .source = .input },
        .{ .name = "nonce", .entropy = kdf.outputEntropy(.nonce, aead.nonce_bits, .message_bound), .timing = kdf.timing, .secret = false, .source = .{ .kdf_call = "kdf_nonce" } },
        .{ .name = "aad", .entropy = .{ .uniform = 0 }, .timing = .constant_time, .secret = false, .source = .input },
        .{ .name = "ct", .entropy = .{ .uniform = 0 }, .timing = .constant_time, .secret = false, .source = .input },
        .{ .name = "plaintext", .entropy = .{ .uniform = 0 }, .timing = aead.timing, .secret = true, .source = .{ .aead_op = .{ .op_id = "aead_open", .output_kind = .plaintext } } },
        .{ .name = "aead_failure", .entropy = .{ .uniform = 0 }, .timing = .constant_time, .secret = false, .source = .structural },
        .{ .name = "reject_boundary", .entropy = .{ .uniform = 0 }, .timing = .constant_time, .secret = false, .source = .structural },
    };
    const kdf_calls = [_]graph.KDFCall{
        .{
            .id = "kdf_nonce",
            .kdf_name = kdf.name,
            .inputs = &[_]graph.ValueRef{.{ .direct = .{ .value = "seed" } }},
            .in_required_ctx_kind = .none,
            .label = "test/nonce",
            .ctx = ctx,
            .scope = .message,
            .use = .nonce,
            .out_bits = aead.nonce_bits,
            .out_name = "nonce",
            .out_ctx_kind = .message_bound,
        },
    };
    const aead_ops = [_]graph.AeadOp{
        .{
            .id = "aead_open",
            .aead_name = aead.name,
            .kind = .open,
            .key = .{ .value = "key" },
            .nonce = .{ .value = "nonce" },
            .aad = .{ .value = "aad" },
            .plaintext = null,
            .ciphertext = .{ .value = "ct" },
            .ct_out = null,
            .pt_out = "plaintext",
            .failure_out = "aead_failure",
        },
    };
    const edges = [_]graph.FlowEdge{
        .{ .from = .{ .direct = .{ .kdf_call = "kdf_nonce" } }, .to = .{ .value = "nonce" } },
        .{ .from = .{ .on_success = .{ .aead_op = "aead_open" } }, .to = .{ .value = "plaintext" } },
        .{ .from = .{ .on_failure = .{ .source = .{ .aead_op = "aead_open" }, .fallback = .{ .uniform = 0 } } }, .to = .{ .value = "aead_failure" } },
    };
    const outputs = [_]graph.Output{
        .{ .name = "plaintext", .value = "plaintext", .kind = .value, .public = false },
        .{ .name = "reject", .value = "reject_boundary", .kind = .reject_boundary, .public = false },
    };

    const g = graph.CompositionGraph{
        .values = values[0..],
        .kem_ops = &[_]graph.KemOp{},
        .kdf_calls = kdf_calls[0..],
        .aead_ops = aead_ops[0..],
        .edges = edges[0..],
        .outputs = outputs[0..],
    };

    try harness.expectConstraint(proof, std.testing.allocator, &g, &cat, .{}, .c4_failure_consistency, .present);
}

test "C5 warns on secret data-dependent timing" {
    const proof = harness.Proof{
        .statement = "Secret values must not be data-dependent in timing (C5 warning).",
        .argument = "A secret input marked data-dependent should trigger the warning.",
        .constraints = &[_]harness.ConstraintId{.c5_timing_chain},
    };

    const cat = composer.catalog.DefaultCatalog;

    const values = [_]graph.Value{
        .{ .name = "secret", .entropy = .{ .uniform = 0 }, .timing = .data_dependent, .secret = true, .source = .input },
        .{ .name = "reject_boundary", .entropy = .{ .uniform = 0 }, .timing = .constant_time, .secret = false, .source = .structural },
    };
    const outputs = [_]graph.Output{
        .{ .name = "secret", .value = "secret", .kind = .value, .public = false },
        .{ .name = "reject", .value = "reject_boundary", .kind = .reject_boundary, .public = false },
    };

    const g = graph.CompositionGraph{
        .values = values[0..],
        .kem_ops = &[_]graph.KemOp{},
        .kdf_calls = &[_]graph.KDFCall{},
        .aead_ops = &[_]graph.AeadOp{},
        .edges = &[_]graph.FlowEdge{},
        .outputs = outputs[0..],
    };

    try harness.expectConstraint(proof, std.testing.allocator, &g, &cat, .{}, .c5_timing_chain, .present);
}

test "C5 warns on data-dependent op with secret input" {
    const proof = harness.Proof{
        .statement = "Data-dependent primitives on secret inputs must warn (C5 warning).",
        .argument = "A secret input flows into a data-dependent KDF output even though the output is public.",
        .constraints = &[_]harness.ConstraintId{.c5_timing_chain},
    };

    const cat = composer.catalog.DefaultCatalog;
    const kdf = composer.catalog.kdfs.HKDF_SHA256;
    const ctx = graph.DerivationContext{
        .schema_id = "Test",
        .protocol_id = "test",
        .suite_id = "suite",
        .transcript_hash = null,
        .message_id = null,
    };

    const values = [_]graph.Value{
        .{ .name = "seed", .entropy = .{ .uniform = 256 }, .timing = .constant_time, .secret = true, .source = .input },
        .{ .name = "out", .entropy = kdf.outputEntropy(.key, 128, .transcript_bound), .timing = .data_dependent, .secret = false, .source = .{ .kdf_call = "kdf1" } },
        .{ .name = "reject_boundary", .entropy = .{ .uniform = 0 }, .timing = .constant_time, .secret = false, .source = .structural },
    };
    const kdf_calls = [_]graph.KDFCall{
        .{
            .id = "kdf1",
            .kdf_name = kdf.name,
            .inputs = &[_]graph.ValueRef{.{ .direct = .{ .value = "seed" } }},
            .in_required_ctx_kind = .none,
            .label = "test/kdf1",
            .ctx = ctx,
            .scope = .session,
            .use = .key,
            .out_bits = 128,
            .out_name = "out",
            .out_ctx_kind = .transcript_bound,
        },
    };
    const edges = [_]graph.FlowEdge{
        .{ .from = .{ .direct = .{ .kdf_call = "kdf1" } }, .to = .{ .value = "out" } },
    };
    const outputs = [_]graph.Output{
        .{ .name = "out", .value = "out", .kind = .value, .public = true },
        .{ .name = "reject", .value = "reject_boundary", .kind = .reject_boundary, .public = false },
    };

    const g = graph.CompositionGraph{
        .values = values[0..],
        .kem_ops = &[_]graph.KemOp{},
        .kdf_calls = kdf_calls[0..],
        .aead_ops = &[_]graph.AeadOp{},
        .edges = edges[0..],
        .outputs = outputs[0..],
    };

    try harness.expectConstraint(proof, std.testing.allocator, &g, &cat, .{}, .c5_timing_chain, .present);
}

test "C5 warns on secret-tainted path across ops" {
    const proof = harness.Proof{
        .statement = "Timing warnings should follow secret-tainted data through multiple ops (C5 warning).",
        .argument = "A secret input flows through a constant-time KDF into a data-dependent KDF output.",
        .constraints = &[_]harness.ConstraintId{.c5_timing_chain},
    };

    const cat = composer.catalog.DefaultCatalog;
    const kdf = composer.catalog.kdfs.HKDF_SHA256;
    const ctx = graph.DerivationContext{
        .schema_id = "Test",
        .protocol_id = "test",
        .suite_id = "suite",
        .transcript_hash = null,
        .message_id = null,
    };

    const values = [_]graph.Value{
        .{ .name = "seed", .entropy = .{ .uniform = 256 }, .timing = .constant_time, .secret = true, .source = .input },
        .{ .name = "mid", .entropy = kdf.outputEntropy(.key, 128, .transcript_bound), .timing = .constant_time, .secret = false, .source = .{ .kdf_call = "kdf1" } },
        .{ .name = "out", .entropy = kdf.outputEntropy(.key, 128, .transcript_bound), .timing = .data_dependent, .secret = false, .source = .{ .kdf_call = "kdf2" } },
        .{ .name = "reject_boundary", .entropy = .{ .uniform = 0 }, .timing = .constant_time, .secret = false, .source = .structural },
    };
    const kdf_calls = [_]graph.KDFCall{
        .{
            .id = "kdf1",
            .kdf_name = kdf.name,
            .inputs = &[_]graph.ValueRef{.{ .direct = .{ .value = "seed" } }},
            .in_required_ctx_kind = .none,
            .label = "test/kdf1",
            .ctx = ctx,
            .scope = .session,
            .use = .key,
            .out_bits = 128,
            .out_name = "mid",
            .out_ctx_kind = .transcript_bound,
        },
        .{
            .id = "kdf2",
            .kdf_name = kdf.name,
            .inputs = &[_]graph.ValueRef{.{ .direct = .{ .value = "mid" } }},
            .in_required_ctx_kind = .none,
            .label = "test/kdf2",
            .ctx = ctx,
            .scope = .session,
            .use = .key,
            .out_bits = 128,
            .out_name = "out",
            .out_ctx_kind = .transcript_bound,
        },
    };
    const edges = [_]graph.FlowEdge{
        .{ .from = .{ .direct = .{ .kdf_call = "kdf1" } }, .to = .{ .value = "mid" } },
        .{ .from = .{ .direct = .{ .kdf_call = "kdf2" } }, .to = .{ .value = "out" } },
    };
    const outputs = [_]graph.Output{
        .{ .name = "out", .value = "out", .kind = .value, .public = true },
        .{ .name = "reject", .value = "reject_boundary", .kind = .reject_boundary, .public = false },
    };

    const g = graph.CompositionGraph{
        .values = values[0..],
        .kem_ops = &[_]graph.KemOp{},
        .kdf_calls = kdf_calls[0..],
        .aead_ops = &[_]graph.AeadOp{},
        .edges = edges[0..],
        .outputs = outputs[0..],
    };

    try harness.expectConstraint(proof, std.testing.allocator, &g, &cat, .{}, .c5_timing_chain, .present);
}

test "C6 rejects non-key-committing AEAD when required" {
    const proof = harness.Proof{
        .statement = "Key commitment is enforced when the product requires it (C6).",
        .argument = "AES-256-GCM is non-key-committing and must fail when required.",
        .constraints = &[_]harness.ConstraintId{.c6_key_commitment},
    };

    const cat = composer.catalog.DefaultCatalog;
    var product = composer.types.contracts.Product{
        .name = "HPKE-KEMDEM",
        .protocol_id = "hpke",
        .requirements = .{ .key_committing = true },
    };
    const bindings = &[_]composer.types.contracts.Binding{
        .{ .slot_name = "kem", .primitive = .{ .kem = &composer.catalog.kems.ML_KEM_768 } },
        .{ .slot_name = "kdf", .primitive = .{ .kdf = &composer.catalog.kdfs.HKDF_SHA256 } },
        .{ .slot_name = "aead", .primitive = .{ .aead = &composer.catalog.aeads.AES_256_GCM } },
    };

    var g = try composer.schemas.kem_dem.expandKEMDEMSeal(std.testing.allocator, bindings, &product, 0);
    defer graph.freeGraph(std.testing.allocator, &g);

    try harness.expectConstraint(proof, std.testing.allocator, &g, &cat, product.requirements, .c6_key_commitment, .present);
}

test "Product rejects wire format protocol mismatch" {
    const proof = harness.Proof{
        .statement = "Product wire format must agree with protocol id.",
        .argument = "A TLS protocol id cannot claim HPKE wire format.",
        .constraints = &[_]harness.ConstraintId{.meta_pdd},
    };
    try harness.requireProof(proof);

    var product = composer.types.contracts.Product{
        .name = "TLS13-Hybrid-KEX",
        .protocol_id = "tls13",
        .requirements = .{},
        .wire_format = .hpke,
    };

    try std.testing.expectError(
        error.WireFormatProtocolMismatch,
        composer.types.contracts.validateProduct(&product),
    );
}

test "Product accepts matching wire format" {
    const proof = harness.Proof{
        .statement = "Product wire format matches protocol id.",
        .argument = "The HPKE wire format must match the hpke protocol id.",
        .constraints = &[_]harness.ConstraintId{.meta_pdd},
    };
    try harness.requireProof(proof);

    var product = composer.types.contracts.Product{
        .name = "HPKE-KEMDEM",
        .protocol_id = "hpke",
        .requirements = .{},
        .wire_format = .hpke,
    };

    try composer.types.contracts.validateProduct(&product);
}

test "HybridKEM encap graph validates" {
    const proof = harness.Proof{
        .statement = "HybridKEM encap graph should validate and satisfy constraints.",
        .argument = "Encap has no failure paths; KDF inputs are transcript-bound and meet entropy bounds.",
        .constraints = &[_]harness.ConstraintId{
            .overall_valid,
            .c1_entropy_flow,
            .c2_domain_sep,
            .c4_failure_consistency,
            .c5_timing_chain,
        },
    };

    const cat = composer.catalog.DefaultCatalog;
    var product = composer.types.contracts.Product{
        .name = "TLS13-Hybrid-KEX",
        .protocol_id = "tls13",
        .requirements = .{ .key_committing = false, .forward_secrecy = true },
    };

    const bindings = &[_]composer.types.contracts.Binding{
        .{ .slot_name = "classical", .primitive = .{ .kem = &composer.catalog.kems.X25519 } },
        .{ .slot_name = "pq", .primitive = .{ .kem = &composer.catalog.kems.ML_KEM_768 } },
        .{ .slot_name = "kdf", .primitive = .{ .kdf = &composer.catalog.kdfs.HKDF_SHA256 } },
    };

    var g = try composer.schemas.hybrid_kem.expandHybridKEMEncap(std.testing.allocator, bindings, &product);
    defer composer.schemas.graph.freeGraph(std.testing.allocator, &g);

    try composer.constraints.validate.validateGraph(std.testing.allocator, &g);

    try harness.expectConstraint(proof, std.testing.allocator, &g, &cat, product.requirements, .overall_valid, .present);
}

test "KEMDEM seal nonce discipline passes" {
    const proof = harness.Proof{
        .statement = "KEMDEM seal derives a message-scoped nonce and satisfies C3.",
        .argument = "Nonce output comes from message-scoped KDF with message_id and message-bound context.",
        .constraints = &[_]harness.ConstraintId{.c3_nonce_discipline},
    };

    const cat = composer.catalog.DefaultCatalog;
    var product = composer.types.contracts.Product{
        .name = "HPKE-KEMDEM",
        .protocol_id = "hpke",
        .requirements = .{ .key_committing = false },
    };

    const bindings = &[_]composer.types.contracts.Binding{
        .{ .slot_name = "kem", .primitive = .{ .kem = &composer.catalog.kems.ML_KEM_768 } },
        .{ .slot_name = "kdf", .primitive = .{ .kdf = &composer.catalog.kdfs.HKDF_SHA256 } },
        .{ .slot_name = "aead", .primitive = .{ .aead = &composer.catalog.aeads.AES_256_GCM } },
    };

    var g = try composer.schemas.kem_dem.expandKEMDEMSeal(std.testing.allocator, bindings, &product, 0);
    defer composer.schemas.graph.freeGraph(std.testing.allocator, &g);

    try composer.constraints.validate.validateGraph(std.testing.allocator, &g);
    try harness.expectConstraint(proof, std.testing.allocator, &g, &cat, product.requirements, .c3_nonce_discipline, .absent);
}
