const std = @import("std");
const c = @import("../types/contracts.zig");

pub fn findByName(name: []const u8) ?*const c.SigContract {
    _ = name;
    return null; // TODO(v0.2+): populate signature catalog.
}
