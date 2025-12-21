const std = @import("std");
const c = @import("../types/contracts.zig");
const notions = @import("../types/notions.zig");
const g = @import("../types/ground.zig");

pub const HKDF_SHA256 = c.KDFContract{
    .name = "HKDF-SHA256",
    .notion = .prf,
    .level = .{ .bits = 128 },
    .timing = .constant_time,
    .max_output_bytes = 255 * 32,
};

pub fn findByName(name: []const u8) ?*const c.KDFContract {
    if (std.mem.eql(u8, name, HKDF_SHA256.name)) return &HKDF_SHA256;
    return null;
}
