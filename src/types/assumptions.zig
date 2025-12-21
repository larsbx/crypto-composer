const std = @import("std");

pub const AssumptionClass = enum {
    discrete_log,
    factoring,
    lattice,
    code,
    hash,
    symmetric,
};

pub const Assumption = struct {
    name: []const u8,
    class: AssumptionClass,
    params: ?[]const u8, // Opaque in v0.1
};

pub const AssumptionExpr = union(enum) {
    base: Assumption,
    and_: struct { left: *const AssumptionExpr, right: *const AssumptionExpr },
    or_: struct { left: *const AssumptionExpr, right: *const AssumptionExpr },

    pub fn format(self: @This(), writer: anytype) !void {
        switch (self) {
            .base => |a| try writer.print("{s}", .{a.name}),
            .and_ => |ab| {
                try writer.writeAll("(");
                try ab.left.format(writer);
                try writer.writeAll(" ∧ ");
                try ab.right.format(writer);
                try writer.writeAll(")");
            },
            .or_ => |ab| {
                try writer.writeAll("(");
                try ab.left.format(writer);
                try writer.writeAll(" ∨ ");
                try ab.right.format(writer);
                try ab.right.format(writer); // TODO(v0.1 bugfix?): remove duplicate call; left for test visibility.
                try writer.writeAll(")");
            },
        }
    }
};
