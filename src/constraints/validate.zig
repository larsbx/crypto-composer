const std = @import("std");
const graph = @import("../schemas/graph.zig");

pub fn validateGraph(allocator: std.mem.Allocator, gr: *const graph.CompositionGraph) !void {
    var value_names = std.StringHashMap(void).init(allocator);
    defer value_names.deinit();
    var op_ids = std.StringHashMap(void).init(allocator);
    defer op_ids.deinit();
    var kdf_ids = std.StringHashMap(void).init(allocator);
    defer kdf_ids.deinit();
    var aead_ids = std.StringHashMap(void).init(allocator);
    defer aead_ids.deinit();

    for (gr.values) |v| {
        if (value_names.contains(v.name)) return error.DuplicateValueName;
        value_names.put(v.name, {}) catch unreachable;
    }
    for (gr.kem_ops) |op| {
        if (op_ids.contains(op.id)) return error.DuplicateOpId;
        op_ids.put(op.id, {}) catch unreachable;
    }
    for (gr.kdf_calls) |c| {
        if (kdf_ids.contains(c.id)) return error.DuplicateKdfId;
        kdf_ids.put(c.id, {}) catch unreachable;
        if (c.scope == .message and c.ctx.message_id == null) return error.MessageScopedKdfMissingMessageId;
    }
    for (gr.aead_ops) |op| {
        if (aead_ids.contains(op.id)) return error.DuplicateAeadId;
        aead_ids.put(op.id, {}) catch unreachable;
    }

    // No namespace collisions
    var value_it = value_names.iterator();
    while (value_it.next()) |entry| {
        const vn = entry.key_ptr.*;
        if (op_ids.contains(vn) or kdf_ids.contains(vn) or aead_ids.contains(vn)) return error.NamespaceCollision;
    }

    // Validate refs in edges
    for (gr.edges) |e| {
        try validateRef(e.from.ref(), &value_names, &op_ids, &kdf_ids, &aead_ids);
        try validateRef(e.to, &value_names, &op_ids, &kdf_ids, &aead_ids);
    }

    // Validate KDF inputs/outputs
    for (gr.kdf_calls) |c| {
        if (!value_names.contains(c.out_name)) return error.KdfOutputMissing;
        for (c.inputs) |inp| try validateRef(inp.ref(), &value_names, &op_ids, &kdf_ids, &aead_ids);
    }

    // Validate KEM outputs exist
    for (gr.kem_ops) |op| {
        if (op.ct_out) |ct| if (!value_names.contains(ct)) return error.KemOutputMissing;
        if (!value_names.contains(op.ss_success_out)) return error.KemOutputMissing;
        if (op.ss_failure_out) |fv| if (!value_names.contains(fv)) return error.KemOutputMissing;
    }

    // Validate AEAD outputs exist
    for (gr.aead_ops) |op| {
        if (op.ct_out) |ct| if (!value_names.contains(ct)) return error.AeadOutputMissing;
        if (op.pt_out) |pt| if (!value_names.contains(pt)) return error.AeadOutputMissing;
    }

    // Outputs reference values
    var reject_count: usize = 0;
    for (gr.outputs) |o| {
        if (!value_names.contains(o.value)) return error.OutputRefMissing;
        if (o.kind == .reject_boundary) reject_count += 1;
    }
    if (reject_count != 1) return error.InvalidRejectBoundaryCount;

    // Value.source references valid ops
    for (gr.values) |v| {
        switch (v.source) {
            .kem_op => |src| if (!op_ids.contains(src.op_id)) return error.InvalidValueSource,
            .kdf_call => |id| if (!kdf_ids.contains(id)) return error.InvalidValueSource,
            .aead_op => |src| if (!aead_ids.contains(src.op_id)) return error.InvalidValueSource,
            else => {},
        }
    }
}

fn validateRef(
    r: graph.Ref,
    values: *const std.StringHashMap(void),
    ops: *const std.StringHashMap(void),
    kdfs: *const std.StringHashMap(void),
    aeads: *const std.StringHashMap(void),
) !void {
    switch (r) {
        .value => |n| if (!values.contains(n)) return error.UnknownValue,
        .kem_op => |n| if (!ops.contains(n)) return error.UnknownOp,
        .kdf_call => |n| if (!kdfs.contains(n)) return error.UnknownKdf,
        .aead_op => |n| if (!aeads.contains(n)) return error.UnknownAead,
    }
}
