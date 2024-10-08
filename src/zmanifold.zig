const std = @import("std");
const Alloc = std.mem.Allocator;
const options = @import("zmanifold_options");
const c = @cImport({
    if (options.manifold_export) @cDefine("MANIFOLD_EXPORT", "");
    @cInclude("manifoldc.h");
    @cInclude("types.h");
});

pub const BooleanOperation = enum {
    add,
    subtract,
    intersect,
};

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
};

pub const Vec3 = c.ManifoldVec3;

//----------------------------------------------------------------------------------------------------------
//
// Manifold
//
//----------------------------------------------------------------------------------------------------------

pub const Manifold = opaque {

    //----- INIT/DEINIT ------------------------------------------------------------------------------//

    pub fn initEmpty(alloc: Alloc) !*Manifold {
        const mem = try alloc.alloc(u8, c.manifold_manifold_size());
        return @as(*Manifold, @ptrCast(c.manifold_empty(mem.ptr)));
    }

    pub fn initCopy(original: *Manifold, alloc: Alloc) !*Manifold {
        const mem = try alloc.alloc(u8, c.manifold_manifold_size());
        return @as(*Manifold, @ptrCast(c.manifold_copy(mem.ptr, @as(?*c.ManifoldManifold, @ptrCast(original)))));
    }

    pub fn deinit(self: *Manifold, alloc: Alloc) void {
        c.manifold_destruct_manifold(@as(?*c.ManifoldManifold, @ptrCast(self)));
        const many_ptr = @as([*]u8, @ptrCast(self));
        alloc.free(many_ptr[0..c.manifold_manifold_size()]);
    }

    //----- SHAPES -----------------------------------------------------------------------------------//

    pub fn initTetrahedron(alloc: Alloc) !*Manifold {
        const mem = try alloc.alloc(u8, c.manifold_manifold_size());
        return @as(*Manifold, @ptrCast(c.manifold_tetrahedron(mem.ptr)));
    }

    pub fn initCube(alloc: Alloc, x: f64, y: f64, z: f64, center: bool) !*Manifold {
        const mem = try alloc.alloc(u8, c.manifold_manifold_size());
        return @as(*Manifold, @ptrCast(c.manifold_cube(mem.ptr, x, y, z, if (center) 1 else 0)));
    }

    pub fn initCylinder(alloc: Alloc, height: f64, rad_lo: f64, rad_hi: f64, segments: i32, center: bool) !*Manifold {
        const mem = try alloc.alloc(u8, c.manifold_manifold_size());
        return @as(*Manifold, @ptrCast(
            c.manifold_cylinder(mem.ptr, height, rad_lo, rad_hi, segments, if (center) 1 else 0),
        ));
    }

    //----- BOOLEAN OPERATIONS -----------------------------------------------------------------------//

    pub fn boolean(self: *Manifold, alloc: Alloc, other: *Manifold, operation: BooleanOperation) !*Manifold {
        const mem = try alloc.alloc(u8, c.manifold_manifold_size());
        const first = @as(?*c.ManifoldManifold, @ptrCast(self));
        const second = @as(?*c.ManifoldManifold, @ptrCast(other));
        return @as(*Manifold, @ptrCast(c.manifold_boolean(mem.ptr, first, second, @intFromEnum(operation))));
    }

    pub fn batchBoolean(alloc: Alloc, vec: *ManifoldVec, operation: BooleanOperation) !*Manifold {
        const mem = try alloc.alloc(u8, c.manifold_manifold_size());
        const c_vec = @as(?*c.ManifoldManifoldVec, @ptrCast(vec));
        return @as(*Manifold, @ptrCast(c.manifold_batch_boolean(mem.ptr, c_vec, @intFromEnum(operation))));
    }

    pub fn trimByPlane(self: *Manifold, alloc: Alloc, nx: f64, ny: f64, nz: f64, offset: f64) !*Manifold {
        const mem = try alloc.alloc(u8, c.manifold_manifold_size());
        const original = @as(?*c.ManifoldManifold, @ptrCast(self));
        return @as(*Manifold, @ptrCast(c.manifold_trim_by_plane(mem.ptr, original, nx, ny, nz, offset)));
    }

    //----- TRANSFORMATIONS --------------------------------------------------------------------------//

    pub fn scale(self: *Manifold, alloc: Alloc, x: f64, y: f64, z: f64) !*Manifold {
        const mem = try alloc.alloc(u8, c.manifold_manifold_size());
        const original = @as(?*c.ManifoldManifold, @ptrCast(self));
        return @as(*Manifold, @ptrCast(c.manifold_scale(mem.ptr, original, x, y, z)));
    }

    pub fn rotate(self: *Manifold, alloc: Alloc, x: f64, y: f64, z: f64) !*Manifold {
        const mem = try alloc.alloc(u8, c.manifold_manifold_size());
        const original = @as(?*c.ManifoldManifold, @ptrCast(self));
        return @as(*Manifold, @ptrCast(c.manifold_rotate(mem.ptr, original, x, y, z)));
    }

    pub fn translate(self: *Manifold, alloc: Alloc, x: f64, y: f64, z: f64) !*Manifold {
        const mem = try alloc.alloc(u8, c.manifold_manifold_size());
        const original = @as(?*c.ManifoldManifold, @ptrCast(self));
        return @as(*Manifold, @ptrCast(c.manifold_translate(mem.ptr, original, x, y, z)));
    }

    //----- MESH EXTRACTION --------------------------------------------------------------------------//

    pub const VertFunc = fn (?*f64, c.ManifoldVec3, ?*const f64, ?*anyopaque) callconv(.C) void;
    pub fn setVertProperties(self: *Manifold, alloc: Alloc, num_prop: i32, fun: VertFunc, ctx: ?*anyopaque) !*Manifold {
        const mem = try alloc.alloc(u8, c.manifold_manifold_size());
        const original = @as(?*c.ManifoldManifold, @ptrCast(self));
        return @as(*Manifold, @ptrCast(c.manifold_set_properties(mem.ptr, original, num_prop, fun, ctx)));
    }

    pub fn calculateNormals(self: *Manifold, alloc: Alloc, normal_idx: i32, min_sharp_angle: i32) !*Manifold {
        const mem = try alloc.alloc(u8, c.manifold_manifold_size());
        const original = @as(?*c.ManifoldManifold, @ptrCast(self));
        return @as(*Manifold, @ptrCast(c.manifold_calculate_normals(mem.ptr, original, normal_idx, min_sharp_angle)));
    }

    pub fn getMeshGL(self: *Manifold, alloc: Alloc) !*MeshGL {
        const mem = try alloc.alloc(u8, c.manifold_meshgl_size());
        return @as(*MeshGL, @ptrCast(c.manifold_get_meshgl(mem.ptr, @as(?*c.ManifoldManifold, @ptrCast(self)))));
    }

    pub fn project(self: *Manifold, alloc: Alloc) !*Polygons {
        const mem = try alloc.alloc(u8, c.manifold_polygons_size());
        return @as(*Polygons, @ptrCast(c.manifold_project(mem.ptr, @as(?*c.ManifoldManifold, @ptrCast(self)))));
    }

    //----- INFO GETTERS -----------------------------------------------------------------------------//

    pub fn isEmpty(self: *Manifold) bool {
        return c.manifold_is_empty(@as(?*c.ManifoldManifold, @ptrCast(self))) != 0;
    }

    pub fn status(self: *Manifold) ManifoldStatus {
        return @enumFromInt(c.manifold_status(@as(?*c.ManifoldManifold, @ptrCast(self))));
    }

    pub fn getNumVerts(self: *Manifold) i32 {
        return c.manifold_num_vert(@as(?*c.ManifoldManifold, @ptrCast(self)));
    }

    //----- MISC -------------------------------------------------------------------------------------//

    pub fn asOriginal(self: *Manifold, alloc: Alloc) !*Manifold {
        const mem = try alloc.alloc(u8, c.manifold_manifold_size());
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
        const mem = try alloc.alloc(u8, c.manifold_manifold_vec_size());
        return @as(*ManifoldVec, @ptrCast(c.manifold_manifold_empty_vec(mem.ptr)));
    }

    pub fn initSize(alloc: Alloc, size: usize) !*ManifoldVec {
        const mem = try alloc.alloc(u8, c.manifold_manifold_vec_size());
        return @as(*ManifoldVec, @ptrCast(c.manifold_manifold_vec(mem.ptr, size)));
    }

    pub fn deinit(self: *ManifoldVec, alloc: Alloc) void {
        c.manifold_destruct_manifold_vec(@as(?*c.ManifoldManifoldVec, @ptrCast(self)));
        const many_ptr = @as([*]u8, @ptrCast(self));
        alloc.free(many_ptr[0..c.manifold_manifold_vec_size()]);
    }

    pub fn reserve(self: *ManifoldVec, size: usize) void {
        c.manifold_manifold_vec_reserve(@as(?*c.ManifoldManifoldVec, @ptrCast(self)), size);
    }

    pub fn len(self: *ManifoldVec) usize {
        return c.manifold_manifold_vec_length(@as(?*c.ManifoldManifoldVec, @ptrCast(self)));
    }

    pub fn get(self: *ManifoldVec, alloc: Alloc, index: i32) !*Manifold {
        const mem = try alloc.alloc(u8, c.manifold_manifold_size());
        const mani = c.manifold_manifold_vec_get(mem.ptr, @as(?*c.ManifoldManifoldVec, @ptrCast(self)), index);
        return @as(*Manifold, @ptrCast(mani));
    }

    pub fn set(self: *ManifoldVec, index: i32, manifold: *Manifold) void {
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
    pub fn deinit(self: *MeshGL, alloc: Alloc) void {
        c.manifold_destruct_meshgl(@as(?*c.ManifoldMeshGL, @ptrCast(self)));
        const many_ptr = @as([*]u8, @ptrCast(self));
        alloc.free(many_ptr[0..c.manifold_meshgl_size()]);
    }

    pub fn getNumProps(self: *MeshGL) i32 {
        return c.manifold_meshgl_num_prop(@as(*c.ManifoldMeshGL, @ptrCast(self)));
    }
    pub fn getNumVerts(self: *MeshGL) i32 {
        return c.manifold_meshgl_num_vert(@as(*c.ManifoldMeshGL, @ptrCast(self)));
    }
    pub fn getNumTris(self: *MeshGL) i32 {
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
// Polygon
//
//----------------------------------------------------------------------------------------------------------

pub const Polygons = opaque {
    pub fn deinit(self: *Polygons, alloc: Alloc) void {
        c.manifold_destruct_polygons(@as(?*c.ManifoldPolygons, @ptrCast(self)));
        const many_ptr = @as([*]u8, @ptrCast(self));
        alloc.free(many_ptr[0..c.manifold_polygons_size()]);
    }

    pub fn getNumSimplePolygons(self: *Polygons) usize {
        return c.manifold_polygons_length(@as(?*c.ManifoldPolygons, @ptrCast(self)));
    }

    pub fn getSimplePolygonNumPoints(self: *Polygons, simple_idx: i32) usize {
        return c.manifold_polygons_simple_length(@as(?*c.ManifoldPolygons, @ptrCast(self)), simple_idx);
    }

    pub fn getPoint(self: *Polygons, simple_idx: i32, point_idx: i32) [2]f64 {
        const vec2 = c.manifold_polygons_get_point(@as(?*c.ManifoldPolygons, @ptrCast(self)), simple_idx, point_idx);
        return .{ vec2.x, vec2.y };
    }
};

//----------------------------------------------------------------------------------------------------------
//
// CrossSection
//
//----------------------------------------------------------------------------------------------------------

pub const CrossSection = opaque {
    pub const FillRule = enum {
        even_odd,
        non_zero,
        positive,
        negative,
    };

    pub fn deinit(self: *CrossSection, alloc: Alloc) void {
        c.manifold_destruct_cross_section(@as(?*c.ManifoldCrossSection, @ptrCast(self)));
        const many_ptr = @as([*]u8, @ptrCast(self));
        alloc.free(many_ptr[0..c.manifold_cross_section_size()]);
    }

    pub fn fromPolygons(alloc: Alloc, polygons: *Polygons, fill_rule: FillRule) !*CrossSection {
        const mem = try alloc.alloc(u8, c.manifold_cross_section_size());
        return @as(*CrossSection, @ptrCast(c.manifold_cross_section_of_polygons(
            mem.ptr,
            @as(?*c.ManifoldPolygons, @ptrCast(polygons)),
            @intFromEnum(fill_rule),
        )));
    }
    pub fn toPolygons(self: *CrossSection, alloc: Alloc) !*Polygons {
        const mem = try alloc.alloc(u8, c.manifold_polygons_size());
        return @as(*Polygons, @ptrCast(c.manifold_cross_section_to_polygons(
            mem.ptr,
            @as(?*c.ManifoldCrossSection, @ptrCast(self)),
        )));
    }

    pub fn simplify(self: *CrossSection, alloc: Alloc, epsilon: f64) !*CrossSection {
        const mem = try alloc.alloc(u8, c.manifold_cross_section_size());
        const original = @as(?*c.ManifoldCrossSection, @ptrCast(self));
        return @as(*CrossSection, @ptrCast(c.manifold_cross_section_simplify(mem.ptr, original, epsilon)));
    }
};

//----------------------------------------------------------------------------------------------------------
//
// Tests
//
//----------------------------------------------------------------------------------------------------------

test "zmanifold.decls" {
    std.testing.refAllDeclsRecursive(@This());
}

test "zmanifold.init" {
    const manifold = try Manifold.initTetrahedron(std.testing.allocator);
    defer manifold.deinit(std.testing.allocator);

    const num_verts = manifold.getNumVerts();
    try std.testing.expect(num_verts == 4);
}

test "zmanifold.trim_tetrahedron" {
    const tetra = try Manifold.initTetrahedron(std.testing.allocator);
    defer tetra.deinit(std.testing.allocator);

    const sliced = try tetra.trimByPlane(std.testing.allocator, 0, 0, 1, 0.5);
    defer sliced.deinit(std.testing.allocator);

    const num_verts = sliced.getNumVerts();
    try std.testing.expect(num_verts == 6);
}
