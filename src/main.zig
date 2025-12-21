const std = @import("std");
const composer = @import("composer");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try usage();
        return;
    }

    const cmd = args[1];

    if (std.mem.eql(u8, cmd, "help")) {
        try usage();
        return;
    }

    // TODO(v0.2+): real CLI parsing, schema selection, file IO, and artifact output.
    // For v0.1 we just print that the binary is alive.
    try std.io.getStdOut().writer().print("crypto-compose v0.1: command '{s}' not implemented (TODO)\n", .{cmd});
}

fn usage() !void {
    const w = std.io.getStdOut().writer();
    try w.writeAll(
        \crypto-compose v0.1
        \
        \Commands (TODO):
        \  check
        \  emit
        \  catalog
        \  enumerate
        \  help
        \
    );
}
