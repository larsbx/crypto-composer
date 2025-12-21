const std = @import("std");
const composer = @import("composer");

pub const ConstraintId = enum {
    overall_valid,
    c1_entropy_flow,
    c2_domain_sep,
    c3_nonce_discipline,
    c4_failure_consistency,
    c5_timing_chain,
    c6_key_commitment,
    w1_assumption_diversity,
    meta_pdd,
};

pub const Proof = struct {
    statement: []const u8,
    argument: []const u8,
    constraints: []const ConstraintId,
    evidence: ?[]const u8 = null,
};

pub const ConstraintPresence = enum { absent, present };

pub fn requireProof(proof: Proof) !void {
    if (proof.statement.len == 0) return error.MissingProofStatement;
    if (proof.argument.len == 0) return error.MissingProofArgument;
    if (proof.constraints.len == 0) return error.MissingProofConstraints;
}

pub fn requireProofForConstraint(proof: Proof, required: ConstraintId) !void {
    try requireProof(proof);
    if (!hasConstraint(proof.constraints, required)) return error.MissingProofConstraint;
}

pub fn requireProofForValid(proof: Proof) !void {
    try requireProofForConstraint(proof, .overall_valid);
}

pub fn expectConstraint(
    proof: Proof,
    allocator: std.mem.Allocator,
    gr: *const composer.schemas.graph.CompositionGraph,
    cat: *const composer.catalog.Catalog,
    req: composer.types.contracts.ProductRequirements,
    id: ConstraintId,
    expected: ConstraintPresence,
) !void {
    try requireProofForConstraint(proof, id);
    const res = try composer.constraints.checker.checkAll(allocator, gr, cat, req);
    const present = switch (id) {
        .overall_valid => res.valid,
        .c1_entropy_flow => res.c1 != null,
        .c2_domain_sep => res.c2 != null,
        .c3_nonce_discipline => res.c3 != null,
        .c4_failure_consistency => res.c4 != null,
        .c5_timing_chain => res.w_ct != null,
        .c6_key_commitment => res.c6 != null,
        else => return error.UnsupportedConstraint,
    };
    try std.testing.expect((expected == .present) == present);
}

pub fn expectW1(proof: Proof, bindings: []const composer.types.contracts.Binding, expected_warn: bool) !void {
    try requireProofForConstraint(proof, .w1_assumption_diversity);
    const warn = composer.constraints.diversity.checkAssumptionDiversity(bindings);
    try std.testing.expect((warn != null) == expected_warn);
}

fn hasConstraint(constraints: []const ConstraintId, required: ConstraintId) bool {
    for (constraints) |constraint| {
        if (constraint == required) return true;
    }
    return false;
}
