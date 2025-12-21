const std = @import("std");
const graph = @import("../schemas/graph.zig");
const contracts = @import("../types/contracts.zig");
const catalog = @import("../catalog/mod.zig");

const validate = @import("validate.zig");
const entropy_flow = @import("entropy_flow.zig");
const domain_sep = @import("domain_sep.zig");
const nonce = @import("nonce.zig");
const failure = @import("failure.zig");
const timing = @import("timing.zig");
const key_commit = @import("key_commit.zig");
const diversity = @import("diversity.zig");
const errors = @import("errors.zig");

pub const CheckResult = struct {
    valid: bool,
    c1: ?errors.C1Error = null,
    c2: ?errors.C2Error = null,
    c3: ?errors.C3Error = null,
    c4: ?errors.C4Error = null,
    c6: ?errors.C6Error = null,
    w_ct: ?errors.C5Warning = null,
    w_div: ?errors.W1Warning = null,
};

pub fn checkAll(
    allocator: std.mem.Allocator,
    gr: *const graph.CompositionGraph,
    cat: *const catalog.Catalog,
    req: contracts.ProductRequirements,
) !CheckResult {
    try validate.validateGraph(allocator, gr);

    var res = CheckResult{ .valid = true };

    res.c1 = entropy_flow.checkEntropyFlow(gr, cat);
    res.c2 = domain_sep.checkDomainSep(allocator, gr);
    res.c3 = nonce.checkNonceDiscipline(gr, cat);
    res.c4 = failure.checkFailureConsistency(allocator, gr);
    res.c6 = key_commit.checkKeyCommitment(gr, cat, req);

    res.w_ct = timing.checkConstantTimeChain(allocator, gr);
    // diversity works on bindings; call it outside with bindings if desired (TODO v0.2+).
    _ = diversity;

    res.valid = (res.c1 == null and res.c2 == null and res.c3 == null and res.c4 == null and res.c6 == null);
    return res;
}
