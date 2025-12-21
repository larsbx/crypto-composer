const graph = @import("../schemas/graph.zig");
const contracts = @import("../types/contracts.zig");
const catalog = @import("../catalog/mod.zig");
const errors = @import("errors.zig");

pub fn checkKeyCommitment(gr: *const graph.CompositionGraph, cat: *const catalog.Catalog, req: contracts.ProductRequirements) ?errors.C6Error {
    if (!req.key_committing) return null;

    // v0.1: find any AEAD op used; require key_committing=true for that AEAD.
    // TODO(v0.2+): make this schema-specific and track which AEAD protects what.
    for (gr.aead_ops) |op| {
        const aead = cat.findAEAD(op.aead_name) orelse continue;
        if (!aead.key_committing) {
            return .{ .aead = aead.name, .product_requires = true };
        }
    }
    return null;
}
