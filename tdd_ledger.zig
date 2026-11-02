const std = @import("std");

// SQLite's C ABI is stable and this ledger uses only this fixed subset.
// Zig 0.17 removed the built-in C translation form used previously; keep
// the existing -lsqlite3 linkage while declaring the consumed ABI explicitly.
const c = struct {
    pub const sqlite3 = opaque {};
    pub const sqlite3_stmt = opaque {};

    pub const SQLITE_OK: c_int = 0;
    pub const SQLITE_ROW: c_int = 100;
    pub const SQLITE_DONE: c_int = 101;
    pub const SQLITE_NULL: c_int = 5;

    pub const SQLITE_OPEN_READWRITE: c_int = 0x00000002;
    pub const SQLITE_OPEN_CREATE: c_int = 0x00000004;

    pub const ExecCallback = *const fn (
        ?*anyopaque,
        c_int,
        [*c][*c]u8,
        [*c][*c]u8,
    ) callconv(.c) c_int;
    pub const Destructor = *const fn (?*anyopaque) callconv(.c) void;
    pub const sqlite3_destructor_type = ?Destructor;

    // SQLite defines SQLITE_TRANSIENT as ((sqlite3_destructor_type)-1).
    pub const SQLITE_TRANSIENT: sqlite3_destructor_type =
        @as(Destructor, @ptrFromInt(std.math.maxInt(usize)));

    pub extern fn sqlite3_open_v2(
        filename: [*:0]const u8,
        db: *?*sqlite3,
        flags: c_int,
        vfs: ?[*:0]const u8,
    ) c_int;
    pub extern fn sqlite3_close(db: *sqlite3) c_int;
    pub extern fn sqlite3_exec(
        db: *sqlite3,
        sql: [*:0]const u8,
        callback: ?ExecCallback,
        callback_arg: ?*anyopaque,
        error_message: ?*[*c]u8,
    ) c_int;
    pub extern fn sqlite3_errmsg(db: *sqlite3) [*:0]const u8;
    pub extern fn sqlite3_prepare_v2(
        db: *sqlite3,
        sql: [*]const u8,
        sql_len: c_int,
        stmt: *?*sqlite3_stmt,
        tail: ?*?[*:0]const u8,
    ) c_int;
    pub extern fn sqlite3_finalize(stmt: *sqlite3_stmt) c_int;
    pub extern fn sqlite3_step(stmt: *sqlite3_stmt) c_int;
    pub extern fn sqlite3_bind_text(
        stmt: *sqlite3_stmt,
        index: c_int,
        text: [*]const u8,
        text_len: c_int,
        destructor: sqlite3_destructor_type,
    ) c_int;
    pub extern fn sqlite3_bind_int64(stmt: *sqlite3_stmt, index: c_int, value: i64) c_int;
    pub extern fn sqlite3_bind_int(stmt: *sqlite3_stmt, index: c_int, value: c_int) c_int;
    pub extern fn sqlite3_bind_null(stmt: *sqlite3_stmt, index: c_int) c_int;
    pub extern fn sqlite3_column_int64(stmt: *sqlite3_stmt, index: c_int) i64;
    pub extern fn sqlite3_column_int(stmt: *sqlite3_stmt, index: c_int) c_int;
    pub extern fn sqlite3_column_type(stmt: *sqlite3_stmt, index: c_int) c_int;
    pub extern fn sqlite3_column_text(stmt: *sqlite3_stmt, index: c_int) ?[*]const u8;
    pub extern fn sqlite3_column_bytes(stmt: *sqlite3_stmt, index: c_int) c_int;
    pub extern fn sqlite3_last_insert_rowid(db: *sqlite3) i64;
};

pub const Status = enum { red, green };

pub const Record = struct {
    test_name: []const u8,
    status: Status,
    note: ?[]const u8 = null,
    command: ?[]const u8 = null,
    exit_code: ?i32 = null,
};

pub const LedgerRow = struct {
    test_name: []const u8,
    status: Status,
    note: ?[]const u8,
    last_command: ?[]const u8,
    last_exit_code: ?i32,
    updated_at: []const u8,

    pub fn deinit(self: *LedgerRow, allocator: std.mem.Allocator) void {
        allocator.free(self.test_name);
        allocator.free(self.updated_at);
        if (self.note) |value| allocator.free(value);
        if (self.last_command) |value| allocator.free(value);
        self.* = undefined;
    }
};

pub const RecordResult = struct {
    event_id: i64,
    row: LedgerRow,

    pub fn deinit(self: *RecordResult, allocator: std.mem.Allocator) void {
        self.row.deinit(allocator);
        self.* = undefined;
    }
};

pub const Ledger = struct {
    db: *c.sqlite3,

    pub fn init(allocator: std.mem.Allocator, db_path: []const u8) !Ledger {
        const path_z = try allocator.dupeZ(u8, db_path);
        defer allocator.free(path_z);

        var db: ?*c.sqlite3 = null;
        const rc = c.sqlite3_open_v2(
            path_z.ptr,
            &db,
            c.SQLITE_OPEN_READWRITE | c.SQLITE_OPEN_CREATE,
            null,
        );
        if (rc != c.SQLITE_OK) {
            if (db) |handle| _ = c.sqlite3_close(handle);
            return error.SqliteError;
        }

        var ledger = Ledger{ .db = db.? };
        try ledger.exec("PRAGMA journal_mode = WAL;");
        try ledger.exec("PRAGMA foreign_keys = ON;");
        try ledger.exec(
            \\CREATE TABLE IF NOT EXISTS ledger (
            \\  test_name TEXT PRIMARY KEY,
            \\  status TEXT NOT NULL CHECK(status IN ('red','green')),
            \\  note TEXT,
            \\  last_command TEXT,
            \\  last_exit_code INTEGER,
            \\  created_at TEXT NOT NULL DEFAULT (datetime('now')),
            \\  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
            \\);
        );
        try ledger.exec(
            \\CREATE TABLE IF NOT EXISTS events (
            \\  id INTEGER PRIMARY KEY AUTOINCREMENT,
            \\  test_name TEXT NOT NULL,
            \\  status TEXT NOT NULL CHECK(status IN ('red','green')),
            \\  note TEXT,
            \\  command TEXT,
            \\  exit_code INTEGER,
            \\  created_at TEXT NOT NULL DEFAULT (datetime('now'))
            \\);
        );
        return ledger;
    }

    pub fn deinit(self: *Ledger) void {
        _ = c.sqlite3_close(self.db);
        self.* = undefined;
    }

    pub fn record(self: *Ledger, rec: Record) !void {
        if (rec.status == .green) try self.requireRedBeforeGreen(rec.test_name);
        try self.execUpsert(rec);
        _ = try self.execEvent(rec);
    }

    pub fn recordWithResult(self: *Ledger, allocator: std.mem.Allocator, rec: Record) !RecordResult {
        if (rec.status == .green) try self.requireRedBeforeGreen(rec.test_name);
        try self.execUpsert(rec);
        const event_id = try self.execEvent(rec);
        const row = try self.fetchLedgerRow(allocator, rec.test_name);
        return .{ .event_id = event_id, .row = row };
    }

    pub fn markRed(self: *Ledger, test_name: []const u8, note: ?[]const u8) !void {
        try self.record(.{ .test_name = test_name, .status = .red, .note = note });
    }

    pub fn markGreen(self: *Ledger, test_name: []const u8, note: ?[]const u8) !void {
        try self.record(.{ .test_name = test_name, .status = .green, .note = note });
    }

    pub fn requireGreen(self: *Ledger) !void {
        if (try self.hasRed()) return error.RedTestsRemain;
    }

    pub fn requireRedBeforeGreen(self: *Ledger, test_name: []const u8) !void {
        if (!try self.hasRedEvent(test_name)) return error.MissingRed;
    }

    pub fn countByStatus(self: *Ledger, status: Status) !usize {
        const sql =
            \\SELECT COUNT(*) FROM ledger WHERE status = ?
        ;
        const stmt = try self.prepare(sql);
        defer _ = c.sqlite3_finalize(stmt);

        try bindText(stmt, 1, statusText(status));
        const rc = c.sqlite3_step(stmt);
        if (rc == c.SQLITE_ROW) {
            const count = c.sqlite3_column_int64(stmt, 0);
            return @intCast(count);
        }
        return error.SqliteError;
    }

    fn exec(self: *Ledger, sql: [:0]const u8) !void {
        const rc = c.sqlite3_exec(self.db, sql, null, null, null);
        if (rc != c.SQLITE_OK) {
            const msg = c.sqlite3_errmsg(self.db);
            std.log.err("sqlite error: {s}", .{std.mem.span(msg)});
            return error.SqliteError;
        }
    }

    fn prepare(self: *Ledger, sql: []const u8) !*c.sqlite3_stmt {
        var stmt: ?*c.sqlite3_stmt = null;
        const rc = c.sqlite3_prepare_v2(self.db, sql.ptr, @intCast(sql.len), &stmt, null);
        if (rc != c.SQLITE_OK) {
            return error.SqliteError;
        }
        return stmt.?;
    }

    fn execUpsert(self: *Ledger, rec: Record) !void {
        const sql =
            \\INSERT INTO ledger (test_name, status, note, last_command, last_exit_code)
            \\VALUES (?, ?, ?, ?, ?)
            \\ON CONFLICT(test_name) DO UPDATE SET
            \\  status=excluded.status,
            \\  note=excluded.note,
            \\  last_command=excluded.last_command,
            \\  last_exit_code=excluded.last_exit_code,
            \\  updated_at=datetime('now')
        ;
        const stmt = try self.prepare(sql);
        defer _ = c.sqlite3_finalize(stmt);

        try bindText(stmt, 1, rec.test_name);
        try bindText(stmt, 2, statusText(rec.status));
        try bindOptionalText(stmt, 3, rec.note);
        try bindOptionalText(stmt, 4, rec.command);
        try bindOptionalInt(stmt, 5, rec.exit_code);
        try stepDone(stmt);
    }

    fn execEvent(self: *Ledger, rec: Record) !i64 {
        const sql =
            \\INSERT INTO events (test_name, status, note, command, exit_code)
            \\VALUES (?, ?, ?, ?, ?)
        ;
        const stmt = try self.prepare(sql);
        defer _ = c.sqlite3_finalize(stmt);

        try bindText(stmt, 1, rec.test_name);
        try bindText(stmt, 2, statusText(rec.status));
        try bindOptionalText(stmt, 3, rec.note);
        try bindOptionalText(stmt, 4, rec.command);
        try bindOptionalInt(stmt, 5, rec.exit_code);
        try stepDone(stmt);
        return c.sqlite3_last_insert_rowid(self.db);
    }

    fn fetchLedgerRow(self: *Ledger, allocator: std.mem.Allocator, test_name: []const u8) !LedgerRow {
        const sql =
            \\SELECT test_name, status, note, last_command, last_exit_code, updated_at
            \\FROM ledger
            \\WHERE test_name = ?
        ;
        const stmt = try self.prepare(sql);
        defer _ = c.sqlite3_finalize(stmt);

        try bindText(stmt, 1, test_name);
        const rc = c.sqlite3_step(stmt);
        if (rc != c.SQLITE_ROW) return error.SqliteError;

        const name = try columnTextOwned(allocator, stmt, 0);
        errdefer allocator.free(name);

        const status_text = try columnTextOwned(allocator, stmt, 1);
        defer allocator.free(status_text);
        const status = try statusFromText(status_text);

        const note = try columnOptionalTextOwned(allocator, stmt, 2);
        errdefer if (note) |value| allocator.free(value);

        const last_command = try columnOptionalTextOwned(allocator, stmt, 3);
        errdefer if (last_command) |value| allocator.free(value);

        const last_exit_code = columnOptionalInt(stmt, 4);

        const updated_at = try columnTextOwned(allocator, stmt, 5);
        errdefer allocator.free(updated_at);

        return .{
            .test_name = name,
            .status = status,
            .note = note,
            .last_command = last_command,
            .last_exit_code = last_exit_code,
            .updated_at = updated_at,
        };
    }

    fn hasRed(self: *Ledger) !bool {
        const sql =
            \\SELECT 1 FROM ledger WHERE status = 'red' LIMIT 1
        ;
        const stmt = try self.prepare(sql);
        defer _ = c.sqlite3_finalize(stmt);

        const rc = c.sqlite3_step(stmt);
        if (rc == c.SQLITE_ROW) return true;
        if (rc == c.SQLITE_DONE) return false;
        return error.SqliteError;
    }

    fn hasRedEvent(self: *Ledger, test_name: []const u8) !bool {
        const sql =
            \\SELECT 1 FROM events WHERE status = 'red' AND test_name = ? LIMIT 1
        ;
        const stmt = try self.prepare(sql);
        defer _ = c.sqlite3_finalize(stmt);

        try bindText(stmt, 1, test_name);
        const rc = c.sqlite3_step(stmt);
        if (rc == c.SQLITE_ROW) return true;
        if (rc == c.SQLITE_DONE) return false;
        return error.SqliteError;
    }

    fn hasRedSince(self: *Ledger, since_epoch: i64) !bool {
        const sql =
            \\SELECT 1 FROM events WHERE status = 'red'
            \\  AND created_at >= datetime(?, 'unixepoch')
            \\LIMIT 1
        ;
        const stmt = try self.prepare(sql);
        defer _ = c.sqlite3_finalize(stmt);

        try bindInt64(stmt, 1, since_epoch);
        const rc = c.sqlite3_step(stmt);
        if (rc == c.SQLITE_ROW) return true;
        if (rc == c.SQLITE_DONE) return false;
        return error.SqliteError;
    }
};

fn statusText(status: Status) []const u8 {
    return switch (status) {
        .red => "red",
        .green => "green",
    };
}

fn statusFromText(text: []const u8) !Status {
    if (std.mem.eql(u8, text, "red")) return .red;
    if (std.mem.eql(u8, text, "green")) return .green;
    return error.InvalidStatus;
}

fn columnTextOwned(allocator: std.mem.Allocator, stmt: *c.sqlite3_stmt, idx: c_int) ![]const u8 {
    const text_ptr = c.sqlite3_column_text(stmt, idx);
    if (text_ptr == null) return error.SqliteError;
    const len = c.sqlite3_column_bytes(stmt, idx);
    const slice = @as([*]const u8, @ptrCast(text_ptr))[0..@intCast(len)];
    return allocator.dupe(u8, slice);
}

fn columnOptionalTextOwned(allocator: std.mem.Allocator, stmt: *c.sqlite3_stmt, idx: c_int) !?[]const u8 {
    if (c.sqlite3_column_type(stmt, idx) == c.SQLITE_NULL) return null;
    return try columnTextOwned(allocator, stmt, idx);
}

fn columnOptionalInt(stmt: *c.sqlite3_stmt, idx: c_int) ?i32 {
    if (c.sqlite3_column_type(stmt, idx) == c.SQLITE_NULL) return null;
    return c.sqlite3_column_int(stmt, idx);
}

fn bindText(stmt: *c.sqlite3_stmt, idx: c_int, text: []const u8) !void {
    const rc = c.sqlite3_bind_text(stmt, idx, text.ptr, @intCast(text.len), c.SQLITE_TRANSIENT);
    if (rc != c.SQLITE_OK) return error.SqliteError;
}

fn bindOptionalText(stmt: *c.sqlite3_stmt, idx: c_int, text: ?[]const u8) !void {
    if (text) |value| return bindText(stmt, idx, value);
    const rc = c.sqlite3_bind_null(stmt, idx);
    if (rc != c.SQLITE_OK) return error.SqliteError;
}

fn bindOptionalInt(stmt: *c.sqlite3_stmt, idx: c_int, value: ?i32) !void {
    if (value) |int_value| {
        const rc = c.sqlite3_bind_int(stmt, idx, int_value);
        if (rc != c.SQLITE_OK) return error.SqliteError;
        return;
    }
    const rc = c.sqlite3_bind_null(stmt, idx);
    if (rc != c.SQLITE_OK) return error.SqliteError;
}

fn bindInt64(stmt: *c.sqlite3_stmt, idx: c_int, value: i64) !void {
    const rc = c.sqlite3_bind_int64(stmt, idx, value);
    if (rc != c.SQLITE_OK) return error.SqliteError;
}

fn stepDone(stmt: *c.sqlite3_stmt) !void {
    const rc = c.sqlite3_step(stmt);
    if (rc != c.SQLITE_DONE) return error.SqliteError;
}

fn runCommand(allocator: std.mem.Allocator, io: std.Io, argv: []const []const u8) !i32 {
    const result = try std.process.run(allocator, io, .{ .argv = argv });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    return switch (result.term) {
        .exited => |code| @intCast(code),
        else => error.CommandFailed,
    };
}

fn joinArgs(allocator: std.mem.Allocator, args: []const []const u8) ![]const u8 {
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);

    for (args, 0..) |arg, idx| {
        if (idx > 0) try out.append(allocator, ' ');
        try out.appendSlice(allocator, arg);
    }
    return out.toOwnedSlice(allocator);
}

pub fn requireRunArgs(run_args: ?[]const []const u8) ![]const []const u8 {
    const raw = run_args orelse return error.MissingRun;
    const args = if (raw.len > 0 and std.mem.eql(u8, raw[0], "--")) raw[1..] else raw;
    if (args.len == 0) return error.MissingRun;
    return args;
}

fn sleepMillis(io: std.Io, ms: u64) !void {
    try io.sleep(.fromMilliseconds(ms), .awake);
}

fn renderBar(buf: []u8, pos: usize) []const u8 {
    var i: usize = 0;
    while (i < buf.len) : (i += 1) {
        buf[i] = if (i == pos) '#' else '-';
    }
    return buf;
}

fn showRedProgress(file: std.Io.File, io: std.Io, red_count: usize) !void {
    const bar_width = 16;
    var bar_buf: [bar_width]u8 = undefined;
    const is_tty = try file.isTty(io);
    const frames: usize = if (is_tty) bar_width * 2 else 1;

    var frame: usize = 0;
    while (frame < frames) : (frame += 1) {
        const pos = frame % bar_width;
        const bar = renderBar(bar_buf[0..], pos);
        var line_buf: [128]u8 = undefined;
        const line = if (is_tty)
            try std.fmt.bufPrint(
                &line_buf,
                "\r\x1b[31m[{s}]\x1b[0m red tests={d}",
                .{ bar, red_count },
            )
        else
            try std.fmt.bufPrint(&line_buf, "[{s}] red tests={d}\n", .{ bar, red_count });
        try file.writeStreamingAll(io, line);
        if (is_tty) try sleepMillis(io, 40);
    }
    if (is_tty) try file.writeStreamingAll(io, "\n");
}

fn writeRecordUpdate(file: std.Io.File, io: std.Io, allocator: std.mem.Allocator, result: *const RecordResult) !void {
    var exit_buf: [32]u8 = undefined;
    const exit_text: []const u8 = if (result.row.last_exit_code) |code|
        try std.fmt.bufPrint(&exit_buf, "{d}", .{code})
    else
        "-";
    const note_text = result.row.note orelse "-";
    const command_text = result.row.last_command orelse "-";
    const status_text = statusText(result.row.status);

    const header = try std.fmt.allocPrint(
        allocator,
        "record updated: test #{d} {s} {s}\n",
        .{ result.event_id, status_text, result.row.test_name },
    );
    defer allocator.free(header);
    try file.writeStreamingAll(io, header);

    const details = try std.fmt.allocPrint(
        allocator,
        "updated_at={s} note={s} command={s} exit_code={s}\n",
        .{ result.row.updated_at, note_text, command_text, exit_text },
    );
    defer allocator.free(details);
    try file.writeStreamingAll(io, details);
}

fn printUsage(file: std.Io.File, io: std.Io) !void {
    try file.writeStreamingAll(io,
        \\Usage:
        \\  zig run tdd_ledger.zig -- [--db path] <command> [args]
        \\
        \\Commands:
        \\  init
        \\  red <test> [--note text] --run -- <cmd...>
        \\  green <test> [--note text] --run -- <cmd...>
        \\  require-green
        \\  require-red-since <unix_epoch>
        \\  status
        \\
        \\Environment:
        \\  TDD_LEDGER_DB defaults the database path if --db is not provided.
        \\
        \\Notes:
        \\  --run is required for red/green to enforce test execution.
        \\  This tool links against sqlite3; compile with -lsqlite3.
        \\
    );
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    const stderr = std.Io.File.stderr();
    const stdout = std.Io.File.stdout();
    const args = try init.minimal.args.toSlice(init.arena.allocator());

    var db_path: []const u8 = init.environ_map.get("TDD_LEDGER_DB") orelse ".tdd_ledger.sqlite";

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--help")) {
            try printUsage(stderr, io);
            return;
        }
        if (std.mem.eql(u8, arg, "--db")) {
            i += 1;
            if (i >= args.len) return error.InvalidArgs;
            db_path = args[i];
            continue;
        }
        break;
    }

    if (i >= args.len) {
        try printUsage(stderr, io);
        return error.InvalidArgs;
    }

    const cmd = args[i];
    i += 1;

    if (std.mem.eql(u8, cmd, "init")) {
        var ledger = try Ledger.init(allocator, db_path);
        ledger.deinit();
        return;
    }

    if (std.mem.eql(u8, cmd, "status")) {
        var ledger = try Ledger.init(allocator, db_path);
        defer ledger.deinit();
        const red = try ledger.countByStatus(.red);
        const green = try ledger.countByStatus(.green);
        const line = try std.fmt.allocPrint(allocator, "red={d} green={d}\n", .{ red, green });
        defer allocator.free(line);
        try stdout.writeStreamingAll(io, line);
        return;
    }

    if (std.mem.eql(u8, cmd, "require-green")) {
        var ledger = try Ledger.init(allocator, db_path);
        defer ledger.deinit();
        const red = try ledger.countByStatus(.red);
        if (red > 0) {
            try showRedProgress(stderr, io, red);
            const line = try std.fmt.allocPrint(allocator, "red tests remain: {d}\n", .{red});
            defer allocator.free(line);
            try stderr.writeStreamingAll(io, line);
            return error.RedTestsRemain;
        }
        return;
    }

    if (std.mem.eql(u8, cmd, "require-red-since")) {
        if (i >= args.len) return error.InvalidArgs;
        const epoch_arg = args[i];
        i += 1;
        const since_epoch = std.fmt.parseInt(i64, epoch_arg, 10) catch return error.InvalidArgs;
        if (since_epoch < 0) return error.InvalidArgs;

        var ledger = try Ledger.init(allocator, db_path);
        defer ledger.deinit();
        const has_red = try ledger.hasRedSince(since_epoch);
        if (!has_red) {
            const line = try std.fmt.allocPrint(
                allocator,
                "no red tests recorded since {d}\n",
                .{since_epoch},
            );
            defer allocator.free(line);
            try stderr.writeStreamingAll(io, line);
            return error.MissingRedSince;
        }
        return;
    }

    if (std.mem.eql(u8, cmd, "red") or std.mem.eql(u8, cmd, "green")) {
        if (i >= args.len) return error.InvalidArgs;
        const test_name = args[i];
        i += 1;

        var note: ?[]const u8 = null;
        var run_args: ?[]const []const u8 = null;
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (std.mem.eql(u8, arg, "--note")) {
                i += 1;
                if (i >= args.len) return error.InvalidArgs;
                note = args[i];
                continue;
            }
            if (std.mem.eql(u8, arg, "--run")) {
                i += 1;
                if (i >= args.len) return error.InvalidArgs;
                run_args = args[i..];
                break;
            }
            return error.InvalidArgs;
        }

        var command: ?[]const u8 = null;
        var exit_code: ?i32 = null;
        const cmd_args = requireRunArgs(run_args) catch |err| {
            if (err == error.MissingRun) {
                try stderr.writeStreamingAll(io, "missing --run command\n");
                return err;
            }
            return err;
        };
        command = try joinArgs(allocator, cmd_args);
        defer allocator.free(command.?);
        const code = try runCommand(allocator, io, cmd_args);
        if (std.mem.eql(u8, cmd, "red")) {
            if (code == 0) return error.ExpectedFailure;
        } else {
            if (code != 0) return error.ExpectedSuccess;
        }
        exit_code = code;

        var ledger = try Ledger.init(allocator, db_path);
        defer ledger.deinit();
        const status: Status = if (std.mem.eql(u8, cmd, "red")) .red else .green;
        var result = try ledger.recordWithResult(allocator, .{
            .test_name = test_name,
            .status = status,
            .note = note,
            .command = command,
            .exit_code = exit_code,
        });
        defer result.deinit(allocator);
        if (status == .red) {
            const red = try ledger.countByStatus(.red);
            try showRedProgress(stdout, io, red);
        }
        try writeRecordUpdate(stdout, io, allocator, &result);
        return;
    }

    try printUsage(stderr, io);
    return error.InvalidArgs;
}
