const std = @import("std");

pub const SecurityLevel = struct { bits: u16 };

pub const CtxKind = enum {
    transcript_bound,
    ciphertext_bound,
    message_bound,
    none,
};

pub const TimingClass = enum {
    constant_time,
    secret_independent,
    data_dependent,
    unknown,
};

pub const FailureMode = enum {
    implicit_reject,
    explicit_reject,
    abort,
};

pub const Scope = enum { session, message };

pub const UseTag = enum { key, nonce, exporter, mac_key, sig_context, other };

pub const EntropyClass = union(enum) {
    uniform: u16,
    min_entropy: u16,
    computational: f64,
    conditioned: struct {
        base: *const EntropyClass,
        ctx_kind: CtxKind,
    },

    pub fn minEntropyBits(self: @This()) u16 {
        return switch (self) {
            .uniform => |n| n,
            .min_entropy => |n| n,
            .computational => 0, // TODO(v0.2+): track ε + min-entropy lower bounds.
            .conditioned => |c| c.base.minEntropyBits(),
        };
    }

    /// Partial order: self entails required iff self is at least as strong.
    pub fn entails(self: @This(), required: @This()) bool {
        return switch (self) {
            .uniform => |n| switch (required) {
                .uniform => |m| n >= m,
                .min_entropy => |m| n >= m,
                .computational => true,
                .conditioned => false, // Rule: non-conditioned cannot entail conditioned.
            },
            .min_entropy => |n| switch (required) {
                .uniform => false,
                .min_entropy => |m| n >= m,
                .computational => true,
                .conditioned => false,
            },
            .conditioned => |c| switch (required) {
                .conditioned => |rc| c.base.entails(rc.base.*) and ctxCompatible(c.ctx_kind, rc.ctx_kind),
                else => c.base.entails(required), // conditioned entails base requirement
            },
            .computational => |e1| switch (required) {
                .computational => |e2| e1 <= e2,
                else => false,
            },
        };
    }
};

pub fn ctxCompatible(actual: CtxKind, required: CtxKind) bool {
    if (required != .none and actual == .none) return false;
    // v0.1: exact match, except required none is always satisfied.
    return actual == required or required == .none;
}

// TODO(v0.2+): richer lattice: allow “more specific satisfies less specific” where sensible.
