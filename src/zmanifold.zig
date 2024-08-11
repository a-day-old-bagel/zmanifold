const std = @import("std");
const Alloc = std.mem.Allocator;
const options = @import("zmanifold_options");
const c = @cImport({
    if (options.manifold_export) @cDefine("MANIFOLD_EXPORT", "");
    @cInclude("manifoldc.h");
    @cInclude("types.h");
});

pub const Manifold = opaque {
    pub fn initEmpty(alloc: Alloc) !*Manifold {
        const mem = try alloc.alloc(u8, c.manifold_manifold_size());
        return @as(*Manifold, @ptrCast(c.manifold_empty(mem.ptr)));
    }

    pub fn initTetrahedron(alloc: Alloc) !*Manifold {
        const mem = try alloc.alloc(u8, c.manifold_manifold_size());
        return @as(*Manifold, @ptrCast(c.manifold_tetrahedron(mem.ptr)));
    }

    pub fn deinit(self: *Manifold, alloc: Alloc) void {
        c.manifold_destruct_manifold(@as(?*c.ManifoldManifold, @ptrCast(self)));
        const many_ptr = @as([*]u8, @ptrCast(self));
        alloc.free(many_ptr[0..c.manifold_manifold_size()]);
    }

    pub fn getNumVerts(self: *Manifold) i32 {
        return c.manifold_num_vert(@as(?*c.ManifoldManifold, @ptrCast(self)));
    }
};

test "zmanifold.decls" {
    std.testing.refAllDeclsRecursive(@This());
}

test "zmanifold.init" {
    const manifold = try Manifold.initTetrahedron(std.testing.allocator);
    defer manifold.deinit(std.testing.allocator);

    const num_verts = manifold.getNumVerts();
    try std.testing.expect(num_verts == 4);
}
