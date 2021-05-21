# Doc from https://github.com/spglib/spglib/blob/d1cb3bd/src/spglib.h#L424-L439
"""
    get_ir_reciprocal_mesh(cell::Cell, mesh, is_shift=falses(3); is_time_reversal=true, symprec=1e-5)

Return k-points mesh and k-point map to the irreducible k-points.

Irreducible reciprocal grid points are searched from uniform
mesh grid points specified by `mesh` and `is_shift`.
`mesh` stores three integers. Reciprocal primitive vectors
are divided by the number stored in `mesh` with (0,0,0) point
centering. The centering can be shifted only half of one mesh
by setting `1` or `true` for each `is_shift` element. If `0` or `false` is set for
`is_shift`, it means there is no shift. This limitation of
shifting enables the irreducible k-point search significantly
faster when the mesh is very dense.

The reducible uniform grid points are returned in reduced
coordinates as `grid_address`. A map between reducible and
irreducible points are returned as `grid_mapping_table` as in the indices of
`grid_address`. The number of the irreducible k-points are
returned as the return value.  The time reversal symmetry is
imposed by setting `is_time_reversal`.
"""
function get_ir_reciprocal_mesh(
    cell::Cell,
    mesh,
    is_shift = falses(3);
    is_time_reversal = true,
    symprec = 1e-5,
)
    # Reference: https://github.com/unkcpz/LibSymspg.jl/blob/e912dd3/src/ir-mesh-api.jl#L1-L32
    @assert length(mesh) == length(is_shift) == 3
    @assert all(isone(x) || iszero(x) for x in is_shift)
    # Prepare for input
    @unpack lattice, positions, types = _expand_cell(cell)
    mesh = Base.cconvert(Vector{Cint}, mesh)
    is_shift = Base.cconvert(Vector{Cint}, is_shift)
    is_time_reversal = Base.cconvert(Cint, is_time_reversal)
    number = Base.cconvert(Cint, length(types))
    # Prepare for output
    npoints = prod(mesh)
    grid_address = Matrix{Cint}(undef, 3, npoints)  # Julia stores multi-dimensional data in column-major, not row-major (C-style) in memory.
    grid_mapping_table = Vector{Cint}(undef, npoints)
    num_ir = ccall(
        (:spg_get_ir_reciprocal_mesh, libsymspg),
        Cint,
        (
            Ptr{Cint},
            Ptr{Cint},
            Ptr{Cint},
            Ptr{Cint},
            Cint,
            Ptr{Cdouble},
            Ptr{Cdouble},
            Ptr{Cint},
            Cint,
            Cdouble,
        ),
        grid_address,
        grid_mapping_table,
        mesh,
        is_shift,
        is_time_reversal,
        lattice,
        positions,
        types,
        number,
        symprec,
    )
    @assert num_ir > 0 "Something wrong happens when finding mesh!"
    return num_ir, grid_mapping_table, grid_address
end

function get_stabilized_reciprocal_mesh(
    rotations::AbstractVector{AbstractMatrix{<:Integer}},
    grid::AbstractVector{<:Integer},
    shift::AbstractVector{<:Integer} = [0, 0, 0];
    qpoints = [[0, 0, 0]],
    is_time_reversal = true,
)
    @assert(length(grid) == length(shift) == 3)
    @assert(all(isone(x) || iszero(x) for x in shift))
    @assert(size(qpoints, 2) == 3)
    npoints = prod(grid)
    grid_address = Matrix{Cint}(undef, npoints, 3)
    mapping = Vector{Cint}(undef, npoints)
    exitcode = ccall(
        (:spg_get_stabilized_reciprocal_mesh, libsymspg),
        Cint,
        (
            Ptr{Cint},
            Ptr{Cint},
            Ptr{Cint},
            Ptr{Cint},
            Cint,
            Cint,
            Ptr{Cint},
            Cint,
            Ptr{Cint},
        ),
        grid_address,
        mapping,
        grid,
        shift,
        is_time_reversal,
        length(rotations),
        rotations,
        length(qpoints),
        qpoints,
    )
    @assert(exitcode > 0, "Something wrong happens when finding mesh!")
    return mapping, grid_address
end