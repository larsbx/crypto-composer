const std = @import("std");
const composer = @import("composer");

pub fn main(init: std.process.Init) !void {
    _ = composer;

    const allocator = init.gpa;
    const io = init.io;
    const args = try init.minimal.args.toSlice(init.arena.allocator());

    if (args.len < 2) {
        try usage(io);
        return;
    }

    const cmd = args[1];

    if (std.mem.eql(u8, cmd, "help")) {
        try usage(io);
        return;
    }

    // TODO(v0.2+): real CLI parsing, schema selection, file IO, and artifact output.
    // For v0.1 we just print that the binary is alive.
    const line = try std.fmt.allocPrint(
        allocator,
        "crypto-compose v0.1: command '{s}' not implemented (TODO)\n",
        .{cmd},
    );
    defer allocator.free(line);
    try std.Io.File.stdout().writeStreamingAll(io, line);
}

fn usage(io: std.Io) !void {
    try std.Io.File.stdout().writeStreamingAll(
        io,
        \\crypto-compose v0.1
        \\
        \\Commands (TODO):
        \\  check
        \\  emit
        \\  catalog
        \\  enumerate
        \\  help
        \\
    );
}
