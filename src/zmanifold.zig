const std = @import("std");
const Alloc = std.mem.Allocator;
const options = @import("zmanifold_options");
const c = @cImport({
    if (!options.manifold_export) @cDefine("MANIFOLD_NO_IOSTREAM", "");
    @cInclude("manifold/manifoldc.h");
    @cInclude("manifold/types.h");
});

const opaque_alignment: std.mem.Alignment = .@"16";

fn allocOpaque(alloc: Alloc, size: usize) ![]align(16) u8 {
    return alloc.alignedAlloc(u8, opaque_alignment, size);
}

fn freeOpaque(alloc: Alloc, pointer: anytype, size: usize) void {
    const bytes: [*]align(16) u8 = @ptrCast(@alignCast(pointer));
    alloc.free(bytes[0..size]);
}

// Maps to ManifoldOpType
pub const BooleanOperation = enum {
    add,
    subtract,
    intersect,
};

// Maps to ManifoldError
pub const ManifoldStatus = enum {
    no_error,
    non_finite_vertex,
    not_manifold,
    vertex_index_out_of_bounds,
    properties_wrong_length,
    missing_position_properties,
    merge_vectors_different_lengths,
    merge_index_out_of_bounds,
    transform_wrong_length,
    run_index_wrong_length,
    face_id_wrong_length,
    invalid_construction,
    result_too_large,
    invalid_tangents,
    cancelled,
};

pub const Vec2 = c.ManifoldVec2;
pub const Vec3 = c.ManifoldVec3;

//----------------------------------------------------------------------------------------------------------
//
// Manifold
//
//----------------------------------------------------------------------------------------------------------

pub const Manifold = opaque {
    pub fn initEmpty(alloc: Alloc) !*Manifold {
        const mem = try allocOpaque(alloc, c.manifold_manifold_size());
        return @as(*Manifold, @ptrCast(c.manifold_empty(mem.ptr)));
    }

    pub fn deinit(self: *Manifold, alloc: Alloc) void {
        c.manifold_destruct_manifold(@as(?*c.ManifoldManifold, @ptrCast(self)));
        freeOpaque(alloc, self, c.manifold_manifold_size());
    }

    pub fn initCopy(original: *Manifold, alloc: Alloc) !*Manifold {
        const mem = try allocOpaque(alloc, c.manifold_manifold_size());
        return @as(*Manifold, @ptrCast(c.manifold_copy(mem.ptr, @as(?*c.ManifoldManifold, @ptrCast(original)))));
    }

    pub fn initFromMeshGL(alloc: Alloc, mesh_gl: *MeshGL) !*Manifold {
        const mem = try allocOpaque(alloc, c.manifold_manifold_size());
        return @as(*Manifold, @ptrCast(c.manifold_of_meshgl(mem.ptr, @as(?*c.ManifoldMeshGL, @ptrCast(mesh_gl)))));
    }

    pub fn initFromMeshGL64(alloc: Alloc, mesh_gl: *MeshGL64) !*Manifold {
        const mem = try allocOpaque(alloc, c.manifold_manifold_size());
        return @as(*Manifold, @ptrCast(c.manifold_of_meshgl64(mem.ptr, @as(?*c.ManifoldMeshGL64, @ptrCast(mesh_gl)))));
    }

    //----- SHAPES -----------------------------------------------------------------------------------//

    pub fn initTetrahedron(alloc: Alloc) !*Manifold {
        const mem = try allocOpaque(alloc, c.manifold_manifold_size());
        return @as(*Manifold, @ptrCast(c.manifold_tetrahedron(mem.ptr)));
    }

    pub fn initCube(alloc: Alloc, x: f64, y: f64, z: f64, center: bool) !*Manifold {
        const mem = try allocOpaque(alloc, c.manifold_manifold_size());
        return @as(*Manifold, @ptrCast(c.manifold_cube(mem.ptr, x, y, z, if (center) 1 else 0)));
    }

    pub fn initCylinder(alloc: Alloc, height: f64, rad_lo: f64, rad_hi: f64, segments: i32, center: bool) !*Manifold {
        const mem = try allocOpaque(alloc, c.manifold_manifold_size());
        return @as(*Manifold, @ptrCast(
            c.manifold_cylinder(mem.ptr, height, rad_lo, rad_hi, segments, if (center) 1 else 0),
        ));
    }

    pub fn initCone(alloc: Alloc, height: f64, rad_lo: f64, segments: i32, center: bool) !*Manifold {
        const mem = try allocOpaque(alloc, c.manifold_manifold_size());
        return @as(*Manifold, @ptrCast(
            c.manifold_cylinder(mem.ptr, height, rad_lo, 0, segments, if (center) 1 else 0),
        ));
    }

    pub fn initSphere(alloc: Alloc, radius: f64, circular_segments: i32) !*Manifold {
        const mem = try allocOpaque(alloc, c.manifold_manifold_size());
        return @as(*Manifold, @ptrCast(
            c.manifold_sphere(mem.ptr, radius, circular_segments),
        ));
    }

    //----- POLYGONS: 2D<-->3D -----------------------------------------------------------------------//

    pub fn initRevolution(alloc: Alloc, polygons: *Polygons, segments: i32, degrees: f64) !*Manifold {
        const mem = try allocOpaque(alloc, c.manifold_manifold_size());
        return @as(*Manifold, @ptrCast(c.manifold_revolve(mem.ptr, @as(?*c.ManifoldPolygons, @ptrCast(polygons)), segments, degrees)));
    }

    pub fn project(self: *Manifold, alloc: Alloc) !*Polygons {
        const mem = try allocOpaque(alloc, c.manifold_polygons_size());
        return @as(*Polygons, @ptrCast(c.manifold_project(mem.ptr, @as(?*c.ManifoldManifold, @ptrCast(self)))));
    }

    //----- BOOLEAN OPERATIONS -----------------------------------------------------------------------//

    pub fn boolean(self: *Manifold, alloc: Alloc, other: *Manifold, operation: BooleanOperation) !*Manifold {
        const mem = try allocOpaque(alloc, c.manifold_manifold_size());
        const first = @as(?*c.ManifoldManifold, @ptrCast(self));
        const second = @as(?*c.ManifoldManifold, @ptrCast(other));
        return @as(*Manifold, @ptrCast(c.manifold_boolean(mem.ptr, first, second, @intFromEnum(operation))));
    }

    pub fn batchBoolean(alloc: Alloc, vec: *ManifoldVec, operation: BooleanOperation) !*Manifold {
        const mem = try allocOpaque(alloc, c.manifold_manifold_size());
        const c_vec = @as(?*c.ManifoldManifoldVec, @ptrCast(vec));
        return @as(*Manifold, @ptrCast(c.manifold_batch_boolean(mem.ptr, c_vec, @intFromEnum(operation))));
    }

    pub fn trimByPlane(self: *Manifold, alloc: Alloc, nx: f64, ny: f64, nz: f64, offset: f64) !*Manifold {
        const mem = try allocOpaque(alloc, c.manifold_manifold_size());
        const original = @as(?*c.ManifoldManifold, @ptrCast(self));
        return @as(*Manifold, @ptrCast(c.manifold_trim_by_plane(mem.ptr, original, nx, ny, nz, offset)));
    }

    //----- TRANSFORMATIONS --------------------------------------------------------------------------//

    pub fn scale(self: *Manifold, alloc: Alloc, x: f64, y: f64, z: f64) !*Manifold {
        const mem = try allocOpaque(alloc, c.manifold_manifold_size());
        const original = @as(?*c.ManifoldManifold, @ptrCast(self));
        return @as(*Manifold, @ptrCast(c.manifold_scale(mem.ptr, original, x, y, z)));
    }

    pub fn rotate(self: *Manifold, alloc: Alloc, x: f64, y: f64, z: f64) !*Manifold {
        const mem = try allocOpaque(alloc, c.manifold_manifold_size());
        const original = @as(?*c.ManifoldManifold, @ptrCast(self));
        return @as(*Manifold, @ptrCast(c.manifold_rotate(mem.ptr, original, x, y, z)));
    }

    pub fn translate(self: *Manifold, alloc: Alloc, x: f64, y: f64, z: f64) !*Manifold {
        const mem = try allocOpaque(alloc, c.manifold_manifold_size());
        const original = @as(?*c.ManifoldManifold, @ptrCast(self));
        return @as(*Manifold, @ptrCast(c.manifold_translate(mem.ptr, original, x, y, z)));
    }

    //----- MESH EXTRACTION --------------------------------------------------------------------------//

    pub const VertFunc = fn (?*f64, c.ManifoldVec3, ?*const f64, ?*anyopaque) callconv(.c) void;
    pub fn setVertProperties(self: *Manifold, alloc: Alloc, num_prop: i32, fun: VertFunc, ctx: ?*anyopaque) !*Manifold {
        const mem = try allocOpaque(alloc, c.manifold_manifold_size());
        const original = @as(?*c.ManifoldManifold, @ptrCast(self));
        return @as(*Manifold, @ptrCast(c.manifold_set_properties(mem.ptr, original, num_prop, fun, ctx)));
    }

    pub fn calculateNormals(self: *Manifold, alloc: Alloc, normal_idx: i32, min_sharp_angle: f64) !*Manifold {
        const mem = try allocOpaque(alloc, c.manifold_manifold_size());
        const original = @as(?*c.ManifoldManifold, @ptrCast(self));
        return @as(*Manifold, @ptrCast(c.manifold_calculate_normals(mem.ptr, original, normal_idx, min_sharp_angle)));
    }

    pub fn getMeshGL(self: *Manifold, alloc: Alloc) !*MeshGL {
        const mem = try allocOpaque(alloc, c.manifold_meshgl_size());
        return @as(*MeshGL, @ptrCast(c.manifold_get_meshgl(mem.ptr, @as(?*c.ManifoldManifold, @ptrCast(self)))));
    }

    //----- INFO GETTERS -----------------------------------------------------------------------------//

    pub fn isEmpty(self: *Manifold) bool {
        return c.manifold_is_empty(@as(?*c.ManifoldManifold, @ptrCast(self))) != 0;
    }

    pub fn status(self: *Manifold) ManifoldStatus {
        return @enumFromInt(c.manifold_status(@as(?*c.ManifoldManifold, @ptrCast(self))));
    }

    pub fn getNumVerts(self: *Manifold) usize {
        return c.manifold_num_vert(@as(?*c.ManifoldManifold, @ptrCast(self)));
    }

    pub fn getTolerance(self: *Manifold) f64 {
        return c.manifold_get_tolerance(@as(?*c.ManifoldManifold, @ptrCast(self)));
    }

    //----- MISC -------------------------------------------------------------------------------------//

    pub fn asOriginal(self: *Manifold, alloc: Alloc) !*Manifold {
        const mem = try allocOpaque(alloc, c.manifold_manifold_size());
        return @as(*Manifold, @ptrCast(c.manifold_as_original(mem.ptr, @as(?*c.ManifoldManifold, @ptrCast(self)))));
    }
};

//----------------------------------------------------------------------------------------------------------
//
// ManifoldVec
//
//----------------------------------------------------------------------------------------------------------

pub const ManifoldVec = opaque {
    pub fn initEmpty(alloc: Alloc) !*ManifoldVec {
        const mem = try allocOpaque(alloc, c.manifold_manifold_vec_size());
        return @as(*ManifoldVec, @ptrCast(c.manifold_manifold_empty_vec(mem.ptr)));
    }

    pub fn initSize(alloc: Alloc, size: usize) !*ManifoldVec {
        const mem = try allocOpaque(alloc, c.manifold_manifold_vec_size());
        return @as(*ManifoldVec, @ptrCast(c.manifold_manifold_vec(mem.ptr, size)));
    }

    pub fn deinit(self: *ManifoldVec, alloc: Alloc) void {
        c.manifold_destruct_manifold_vec(@as(?*c.ManifoldManifoldVec, @ptrCast(self)));
        freeOpaque(alloc, self, c.manifold_manifold_vec_size());
    }

    pub fn reserve(self: *ManifoldVec, size: usize) void {
        c.manifold_manifold_vec_reserve(@as(?*c.ManifoldManifoldVec, @ptrCast(self)), size);
    }

    pub fn len(self: *ManifoldVec) usize {
        return c.manifold_manifold_vec_length(@as(?*c.ManifoldManifoldVec, @ptrCast(self)));
    }

    pub fn get(self: *ManifoldVec, alloc: Alloc, index: usize) !*Manifold {
        const mem = try allocOpaque(alloc, c.manifold_manifold_size());
        const mani = c.manifold_manifold_vec_get(mem.ptr, @as(?*c.ManifoldManifoldVec, @ptrCast(self)), index);
        return @as(*Manifold, @ptrCast(mani));
    }

    pub fn set(self: *ManifoldVec, index: usize, manifold: *Manifold) void {
        c.manifold_manifold_vec_set(
            @as(?*c.ManifoldManifoldVec, @ptrCast(self)),
            index,
            @as(*c.ManifoldManifold, @ptrCast(manifold)),
        );
    }

    pub fn pushBack(self: *ManifoldVec, manifold: *Manifold) void {
        c.manifold_manifold_vec_push_back(
            @as(?*c.ManifoldManifoldVec, @ptrCast(self)),
            @as(*c.ManifoldManifold, @ptrCast(manifold)),
        );
    }
};

//----------------------------------------------------------------------------------------------------------
//
// MeshGL
//
//----------------------------------------------------------------------------------------------------------

pub const MeshGL = opaque {
    pub fn init(alloc: Alloc, vert_props: [*]f32, n_verts: usize, n_props: usize, indices: []u32) !*MeshGL {
        const mem = try allocOpaque(alloc, c.manifold_meshgl_size());
        return @as(*MeshGL, @ptrCast(c.manifold_meshgl(
            mem.ptr,
            vert_props,
            n_verts,
            n_props,
            indices.ptr,
            indices.len / 3,
        )));
    }
    pub fn deinit(self: *MeshGL, alloc: Alloc) void {
        c.manifold_destruct_meshgl(@as(?*c.ManifoldMeshGL, @ptrCast(self)));
        freeOpaque(alloc, self, c.manifold_meshgl_size());
    }

    pub fn merge(self: *MeshGL, alloc: Alloc) !*MeshGL {
        const mem = try allocOpaque(alloc, c.manifold_meshgl_size());
        return @as(*MeshGL, @ptrCast(c.manifold_meshgl_merge(mem.ptr, @as(?*c.ManifoldMeshGL, @ptrCast(self)))));
    }

    pub fn getNumProps(self: *MeshGL) usize {
        return c.manifold_meshgl_num_prop(@as(*c.ManifoldMeshGL, @ptrCast(self)));
    }
    pub fn getNumVerts(self: *MeshGL) usize {
        return c.manifold_meshgl_num_vert(@as(*c.ManifoldMeshGL, @ptrCast(self)));
    }
    pub fn getNumTris(self: *MeshGL) usize {
        return c.manifold_meshgl_num_tri(@as(*c.ManifoldMeshGL, @ptrCast(self)));
    }

    pub fn getVertPropertiesLength(self: *MeshGL) usize {
        return c.manifold_meshgl_vert_properties_length(@as(*c.ManifoldMeshGL, @ptrCast(self)));
    }
    pub fn getVertProperties(self: *MeshGL, alloc: Alloc) ![]f32 {
        const num_floats = self.getVertPropertiesLength();
        const mem = try alloc.alloc(f32, num_floats);
        return c.manifold_meshgl_vert_properties(mem.ptr, @as(*c.ManifoldMeshGL, @ptrCast(self)))[0..num_floats];
    }

    pub fn getTriangleVertIndicesLength(self: *MeshGL) usize {
        return c.manifold_meshgl_tri_length(@as(*c.ManifoldMeshGL, @ptrCast(self)));
    }
    pub fn getTriangleVertIndices(self: *MeshGL, alloc: Alloc) ![]u32 {
        const num_uints = self.getTriangleVertIndicesLength();
        const mem = try alloc.alloc(u32, num_uints);
        return c.manifold_meshgl_tri_verts(mem.ptr, @as(*c.ManifoldMeshGL, @ptrCast(self)))[0..num_uints];
    }
};

//----------------------------------------------------------------------------------------------------------
//
// MeshGL64
//
//----------------------------------------------------------------------------------------------------------

pub const MeshGL64 = opaque {
    pub fn init(alloc: Alloc, vert_props: [*]f64, n_verts: usize, n_props: usize, indices: []u64) !*MeshGL64 {
        const mem = try allocOpaque(alloc, c.manifold_meshgl64_size());
        return @as(*MeshGL64, @ptrCast(c.manifold_meshgl64(
            mem.ptr,
            vert_props,
            n_verts,
            n_props,
            indices.ptr,
            indices.len / 3,
        )));
    }

    pub fn deinit(self: *MeshGL64, alloc: Alloc) void {
        c.manifold_destruct_meshgl64(@as(?*c.ManifoldMeshGL64, @ptrCast(self)));
        freeOpaque(alloc, self, c.manifold_meshgl64_size());
    }
};

//----------------------------------------------------------------------------------------------------------
//
// Polygons
//
//----------------------------------------------------------------------------------------------------------

pub const Polygons = opaque {
    pub fn initFromSimples(alloc: Alloc, polys: []const *SimplePolygon) !*Polygons {
        const mem = try allocOpaque(alloc, c.manifold_polygons_size());
        return @as(*Polygons, @ptrCast(c.manifold_polygons(mem.ptr, @as(?*?*c.ManifoldSimplePolygon, @ptrCast(@constCast(polys.ptr))), polys.len)));
    }

    pub fn deinit(self: *Polygons, alloc: Alloc) void {
        c.manifold_destruct_polygons(@as(?*c.ManifoldPolygons, @ptrCast(self)));
        freeOpaque(alloc, self, c.manifold_polygons_size());
    }

    pub fn getNumSimplePolygons(self: *Polygons) usize {
        return c.manifold_polygons_length(@as(?*c.ManifoldPolygons, @ptrCast(self)));
    }

    pub fn getSimplePolygonNumPoints(self: *Polygons, simple_idx: usize) usize {
        return c.manifold_polygons_simple_length(@as(?*c.ManifoldPolygons, @ptrCast(self)), simple_idx);
    }

    pub fn getPoint(self: *Polygons, simple_idx: usize, point_idx: usize) [2]f64 {
        const vec2 = c.manifold_polygons_get_point(@as(?*c.ManifoldPolygons, @ptrCast(self)), simple_idx, point_idx);
        return .{ vec2.x, vec2.y };
    }
};

//----------------------------------------------------------------------------------------------------------
//
// SimplePolygon
//
//----------------------------------------------------------------------------------------------------------

pub const SimplePolygon = opaque {
    pub fn init(alloc: Alloc, points: []const Vec2) !*SimplePolygon {
        const mem = try allocOpaque(alloc, c.manifold_simple_polygon_size());
        return @as(*SimplePolygon, @ptrCast(c.manifold_simple_polygon(mem.ptr, @constCast(points.ptr), points.len)));
    }

    pub fn deinit(self: *SimplePolygon, alloc: Alloc) void {
        c.manifold_destruct_simple_polygon(@as(?*c.ManifoldSimplePolygon, @ptrCast(self)));
        freeOpaque(alloc, self, c.manifold_simple_polygon_size());
    }
};

//----------------------------------------------------------------------------------------------------------
//
// CrossSection
//
//----------------------------------------------------------------------------------------------------------

pub const CrossSection = opaque {
    // Maps to ManifoldFillRule
    pub const FillRule = enum {
        even_odd,
        non_zero,
        positive,
        negative,
    };
    // Maps to ManifoldJoinType
    pub const JoinType = enum {
        square,
        round,
        miter,
        bevel,
    };

    pub fn deinit(self: *CrossSection, alloc: Alloc) void {
        c.manifold_destruct_cross_section(@as(?*c.ManifoldCrossSection, @ptrCast(self)));
        freeOpaque(alloc, self, c.manifold_cross_section_size());
    }

    pub fn fromPolygons(alloc: Alloc, polygons: *Polygons, fill_rule: FillRule) !*CrossSection {
        const mem = try allocOpaque(alloc, c.manifold_cross_section_size());
        return @as(*CrossSection, @ptrCast(c.manifold_cross_section_of_polygons(
            mem.ptr,
            @as(?*c.ManifoldPolygons, @ptrCast(polygons)),
            @intFromEnum(fill_rule),
        )));
    }
    pub fn toPolygons(self: *CrossSection, alloc: Alloc) !*Polygons {
        const mem = try allocOpaque(alloc, c.manifold_polygons_size());
        return @as(*Polygons, @ptrCast(c.manifold_cross_section_to_polygons(
            mem.ptr,
            @as(?*c.ManifoldCrossSection, @ptrCast(self)),
        )));
    }

    pub fn simplify(self: *CrossSection, alloc: Alloc, epsilon: f64) !*CrossSection {
        const mem = try allocOpaque(alloc, c.manifold_cross_section_size());
        const original = @as(?*c.ManifoldCrossSection, @ptrCast(self));
        return @as(*CrossSection, @ptrCast(c.manifold_cross_section_simplify(mem.ptr, original, epsilon)));
    }
};

//----------------------------------------------------------------------------------------------------------
//
// Tests
//
//----------------------------------------------------------------------------------------------------------

test {
    std.testing.refAllDecls(@This());
}

test "zmanifold.init" {
    const manifold = try Manifold.initTetrahedron(std.testing.allocator);
    defer manifold.deinit(std.testing.allocator);

    const num_verts = manifold.getNumVerts();
    try std.testing.expect(num_verts == 4);
}

test "opaque C++ storage remains aligned in an arena" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const alloc = arena_state.allocator();

    _ = try alloc.alloc(u8, 3);
    const manifold = try Manifold.initCube(alloc, 1, 1, 1, true);
    defer manifold.deinit(alloc);
    try std.testing.expectEqual(@as(usize, 0), @intFromPtr(manifold) % opaque_alignment.toByteUnits());

    _ = try alloc.alloc(u8, 5);
    const mesh = try manifold.getMeshGL(alloc);
    defer mesh.deinit(alloc);
    try std.testing.expectEqual(@as(usize, 0), @intFromPtr(mesh) % opaque_alignment.toByteUnits());
}

test "zmanifold.trim_tetrahedron" {
    const tetra = try Manifold.initTetrahedron(std.testing.allocator);
    defer tetra.deinit(std.testing.allocator);

    const sliced = try tetra.trimByPlane(std.testing.allocator, 0, 0, 1, 0.5);
    defer sliced.deinit(std.testing.allocator);

    const num_verts = sliced.getNumVerts();
    try std.testing.expect(num_verts == 6);
}

test "zmanifold.boolean operations and manifold vectors" {
    const alloc = std.testing.allocator;

    const cube = try Manifold.initCube(alloc, 2, 2, 2, true);
    defer cube.deinit(alloc);
    const shifted = try cube.translate(alloc, 1, 0, 0);
    defer shifted.deinit(alloc);

    const joined = try cube.boolean(alloc, shifted, .add);
    defer joined.deinit(alloc);
    const overlap = try cube.boolean(alloc, shifted, .intersect);
    defer overlap.deinit(alloc);
    const cut = try cube.boolean(alloc, shifted, .subtract);
    defer cut.deinit(alloc);

    try std.testing.expectEqual(ManifoldStatus.no_error, joined.status());
    try std.testing.expectEqual(ManifoldStatus.no_error, overlap.status());
    try std.testing.expectEqual(ManifoldStatus.no_error, cut.status());
    try std.testing.expect(!joined.isEmpty());
    try std.testing.expect(!overlap.isEmpty());
    try std.testing.expect(!cut.isEmpty());

    const manifolds = try ManifoldVec.initEmpty(alloc);
    defer manifolds.deinit(alloc);
    manifolds.reserve(2);
    manifolds.pushBack(cube);
    manifolds.pushBack(shifted);
    try std.testing.expectEqual(@as(usize, 2), manifolds.len());

    const first = try manifolds.get(alloc, 0);
    defer first.deinit(alloc);
    try std.testing.expectEqual(cube.getNumVerts(), first.getNumVerts());

    const sized_manifolds = try ManifoldVec.initSize(alloc, 2);
    defer sized_manifolds.deinit(alloc);
    sized_manifolds.set(0, cube);
    sized_manifolds.set(1, shifted);

    const batched = try Manifold.batchBoolean(alloc, sized_manifolds, .add);
    defer batched.deinit(alloc);
    try std.testing.expectEqual(ManifoldStatus.no_error, batched.status());
    try std.testing.expectEqual(joined.getNumVerts(), batched.getNumVerts());

    const copied = try Manifold.initCopy(batched, alloc);
    defer copied.deinit(alloc);
    const original = try copied.asOriginal(alloc);
    defer original.deinit(alloc);
    try std.testing.expectEqual(ManifoldStatus.no_error, original.status());
}

test "zmanifold.mesh round trip and extraction" {
    const alloc = std.testing.allocator;

    const cube = try Manifold.initCube(alloc, 1, 1, 1, false);
    defer cube.deinit(alloc);
    const mesh = try cube.getMeshGL(alloc);
    defer mesh.deinit(alloc);

    const num_props = mesh.getNumProps();
    const num_verts = mesh.getNumVerts();
    const num_tris = mesh.getNumTris();
    try std.testing.expectEqual(num_props * num_verts, mesh.getVertPropertiesLength());
    try std.testing.expectEqual(num_tris * 3, mesh.getTriangleVertIndicesLength());

    const vert_props = try mesh.getVertProperties(alloc);
    defer alloc.free(vert_props);
    const indices = try mesh.getTriangleVertIndices(alloc);
    defer alloc.free(indices);

    const input_mesh = try MeshGL.init(alloc, vert_props.ptr, num_verts, num_props, indices);
    defer input_mesh.deinit(alloc);
    const round_trip = try Manifold.initFromMeshGL(alloc, input_mesh);
    defer round_trip.deinit(alloc);

    try std.testing.expectEqual(ManifoldStatus.no_error, round_trip.status());
    try std.testing.expectEqual(cube.getNumVerts(), round_trip.getNumVerts());
}

test "zmanifold.MeshGL64 preserves a fine tolerance over a large build volume" {
    const alloc = std.testing.allocator;

    var vertices = [_]f64{
        -1_000_000, -1_000_000, 0,
        1_000_000,  -1_000_000, 0,
        1_000_000,  1_000_000,  0,
        -1_000_000, 1_000_000,  0,
        -1_000_000, -1_000_000, 1,
        1_000_000,  -1_000_000, 1,
        1_000_000,  1_000_000,  1,
        -1_000_000, 1_000_000,  1,
    };
    var indices = [_]u64{
        0, 2, 1, 0, 3, 2,
        4, 5, 6, 4, 6, 7,
        0, 1, 5, 0, 5, 4,
        1, 2, 6, 1, 6, 5,
        2, 3, 7, 2, 7, 6,
        3, 0, 4, 3, 4, 7,
    };

    const mesh = try MeshGL64.init(alloc, &vertices, 8, 3, &indices);
    defer mesh.deinit(alloc);
    const manifold = try Manifold.initFromMeshGL64(alloc, mesh);
    defer manifold.deinit(alloc);

    try std.testing.expectEqual(ManifoldStatus.no_error, manifold.status());
    try std.testing.expectEqual(@as(usize, 8), manifold.getNumVerts());
    try std.testing.expect(manifold.getTolerance() < 0.001);
}

test "zmanifold.vertex properties and normals" {
    const alloc = std.testing.allocator;

    const cube = try Manifold.initCube(alloc, 1, 1, 1, true);
    defer cube.deinit(alloc);
    const with_properties = try cube.setVertProperties(alloc, 7, testVertProperties, null);
    defer with_properties.deinit(alloc);
    const with_normals = try with_properties.calculateNormals(alloc, 0, 0);
    defer with_normals.deinit(alloc);
    const mesh = try with_normals.getMeshGL(alloc);
    defer mesh.deinit(alloc);

    try std.testing.expectEqual(@as(usize, 10), mesh.getNumProps());
    try std.testing.expect(mesh.getNumVerts() > 0);
    try std.testing.expectEqual(ManifoldStatus.no_error, with_normals.status());
}

fn testVertProperties(new: ?*f64, _: Vec3, old: ?*const f64, _: ?*anyopaque) callconv(.c) void {
    const output: [*]f64 = @ptrCast(new.?);
    if (old) |existing| {
        const input: [*]const f64 = @ptrCast(existing);
        output[0] = input[0];
        output[1] = input[1];
        output[2] = input[2];
    }
    output[3] = 0.25;
    output[4] = 0.5;
    output[5] = 0.75;
    output[6] = 1;
}

test "zmanifold subtraction orients preserved cavity normals" {
    const alloc = std.testing.allocator;

    const outer = try Manifold.initCube(alloc, 4, 4, 4, true);
    defer outer.deinit(alloc);
    const outer_properties = try outer.setVertProperties(alloc, 7, testVertProperties, null);
    defer outer_properties.deinit(alloc);
    const outer_normals = try outer_properties.calculateNormals(alloc, 0, 0);
    defer outer_normals.deinit(alloc);

    const inner = try Manifold.initCube(alloc, 2, 2, 2, true);
    defer inner.deinit(alloc);
    const inner_normals = try inner.calculateNormals(alloc, 0, 0);
    defer inner_normals.deinit(alloc);
    const inner_properties = try inner_normals.setVertProperties(alloc, 7, testVertProperties, null);
    defer inner_properties.deinit(alloc);

    const hollow = try outer_normals.boolean(alloc, inner_properties, .subtract);
    defer hollow.deinit(alloc);
    const mesh = try hollow.getMeshGL(alloc);
    defer mesh.deinit(alloc);
    const vertices = try mesh.getVertProperties(alloc);
    defer alloc.free(vertices);

    const stride = mesh.getNumProps();
    try std.testing.expectEqual(@as(usize, 10), stride);
    var cavity_vertices: usize = 0;
    for (0..mesh.getNumVerts()) |vertex| {
        const properties = vertices[vertex * stride ..][0..stride];
        const position = properties[0..3];
        const normal = properties[3..6];
        const max_abs_position = @max(@abs(position[0]), @abs(position[1]), @abs(position[2]));
        if (max_abs_position < 1.001) {
            cavity_vertices += 1;
            const alignment = position[0] * normal[0] +
                position[1] * normal[1] +
                position[2] * normal[2];
            try std.testing.expect(alignment < -0.9);
        }
    }
    try std.testing.expect(cavity_vertices > 0);
}

test "zmanifold.polygons, cross sections, and revolution" {
    const alloc = std.testing.allocator;
    const points = [_]Vec2{
        .{ .x = 1, .y = 0 },
        .{ .x = 2, .y = 0 },
        .{ .x = 2, .y = 1 },
        .{ .x = 1, .y = 1 },
    };

    const simple = try SimplePolygon.init(alloc, &points);
    defer simple.deinit(alloc);
    const polygons = try Polygons.initFromSimples(alloc, &.{simple});
    defer polygons.deinit(alloc);

    try std.testing.expectEqual(@as(usize, 1), polygons.getNumSimplePolygons());
    try std.testing.expectEqual(@as(usize, points.len), polygons.getSimplePolygonNumPoints(0));
    try std.testing.expectEqual([2]f64{ 2, 1 }, polygons.getPoint(0, 2));

    const cross_section = try CrossSection.fromPolygons(alloc, polygons, .positive);
    defer cross_section.deinit(alloc);
    const simplified = try cross_section.simplify(alloc, 0.0001);
    defer simplified.deinit(alloc);
    const output_polygons = try simplified.toPolygons(alloc);
    defer output_polygons.deinit(alloc);
    try std.testing.expectEqual(@as(usize, 1), output_polygons.getNumSimplePolygons());

    const revolved = try Manifold.initRevolution(alloc, polygons, 16, 360);
    defer revolved.deinit(alloc);
    try std.testing.expectEqual(ManifoldStatus.no_error, revolved.status());
    try std.testing.expect(!revolved.isEmpty());
}
