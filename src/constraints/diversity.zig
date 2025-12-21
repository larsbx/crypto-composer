const contracts = @import("../types/contracts.zig");
const errors = @import("errors.zig");
const asm = @import("../types/assumptions.zig");

pub fn checkAssumptionDiversity(bindings: []const contracts.Binding) ?errors.W1Warning {
    var first: ?asm.Assumption = null;

    for (bindings) |b| {
        switch (b.primitive) {
            .kem => |k| {
                if (first == null) { first = k.assumption; continue; }
                if (first.?.class == k.assumption.class) {
                    return .{ .same_assumption_class = .{ .left = first.?.name, .right = k.assumption.name, .class = k.assumption.class } };
                }
            },
            else => {},
        }
    }
    return null;
}
