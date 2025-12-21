pub const kems = @import("kems.zig");
pub const kdfs = @import("kdfs.zig");
pub const aeads = @import("aeads.zig");
pub const sigs = @import("sigs.zig");

const contracts = @import("../types/contracts.zig");

pub const Catalog = struct {
    pub fn findKEM(self: *const Catalog, name: []const u8) ?*const contracts.KEMContract {
        _ = self;
        return kems.findByName(name);
    }
    pub fn findKDF(self: *const Catalog, name: []const u8) ?*const contracts.KDFContract {
        _ = self;
        return kdfs.findByName(name);
    }
    pub fn findAEAD(self: *const Catalog, name: []const u8) ?*const contracts.AEADContract {
        _ = self;
        return aeads.findByName(name);
    }
    pub fn findSig(self: *const Catalog, name: []const u8) ?*const contracts.SigContract {
        _ = self;
        return sigs.findByName(name);
    }
};

pub const DefaultCatalog = Catalog{};
