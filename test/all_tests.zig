const std = @import("std");
const composer = @import("composer");

test "HybridKEM encap graph validates" {
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
    defer freeGraph(std.testing.allocator, &g);

    try composer.constraints.validate.validateGraph(std.testing.allocator, &g);

    const res = try composer.constraints.checker.checkAll(std.testing.allocator, &g, &cat, product.requirements);
    try std.testing.expect(res.valid);
}

test "KEMDEM seal nonce discipline passes" {
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
    defer freeGraph(std.testing.allocator, &g);

    try composer.constraints.validate.validateGraph(std.testing.allocator, &g);
    try std.testing.expect(composer.constraints.nonce.checkNonceDiscipline(&g, &cat) == null);
}

fn freeGraph(allocator: std.mem.Allocator, gr: *composer.schemas.graph.CompositionGraph) void {
    // TODO(v0.2+): switch to arenas or graph-owned allocator so this is trivial.
    allocator.free(gr.values);
    allocator.free(gr.kem_ops);
    allocator.free(gr.kdf_calls);
    allocator.free(gr.aead_ops);
    allocator.free(gr.edges);
    allocator.free(gr.outputs);
}
