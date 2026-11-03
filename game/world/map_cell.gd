class_name MapCell
extends Resource
## One streaming cell of a map (written by tools/cell_map.gd): the meshes of
## one render category whose centres lie in one square of the grid, and the
## map nodes they belong to. The resident map keeps those nodes with no mesh;
## MapStreamer gives each node its mesh while the cell is loaded.

## Path of each node from the map's root, in the order of `meshes`.
@export var nodes: Array[NodePath] = []
@export var meshes: Array[Mesh] = []
