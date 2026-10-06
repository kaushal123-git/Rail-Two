"""
LOCO S2 Geospatial Engine & Geodesic Distance Utilities
Implements standard S2 projection, cell token encoding, and spherical geodesic calculations
for urban rail transit spatial indexing.
"""
import math
from typing import Tuple

EARTH_RADIUS_METERS = 6371000.0


def calculate_haversine_distance(
    lat1: float,
    lon1: float,
    lat2: float,
    lon2: float,
) -> float:
    """
    Computes great-circle distance between two coordinates in meters using Haversine formula.
    """
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    a = (
        math.sin(delta_phi / 2.0) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2.0) ** 2
    )
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return EARTH_RADIUS_METERS * c


def lat_lng_to_xyz(lat: float, lon: float) -> Tuple[float, float, float]:
    """Convert degrees latitude and longitude to 3D Cartesian coordinates on unit sphere."""
    lat_r = math.radians(lat)
    lon_r = math.radians(lon)
    cos_lat = math.cos(lat_r)
    x = cos_lat * math.cos(lon_r)
    y = cos_lat * math.sin(lon_r)
    z = math.sin(lat_r)
    return x, y, z


def xyz_to_face(x: float, y: float, z: float) -> int:
    """Determine S2 cube face index (0..5) for 3D point."""
    abs_x, abs_y, abs_z = abs(x), abs(y), abs(z)
    if abs_x > abs_y:
        if abs_x > abs_z:
            return 0 if x > 0 else 3
        else:
            return 2 if z > 0 else 5
    else:
        if abs_y > abs_z:
            return 1 if y > 0 else 4
        else:
            return 2 if z > 0 else 5


def valid_face_uv(face: int, x: float, y: float, z: float) -> Tuple[float, float]:
    """Convert 3D point on unit sphere to (u, v) on [-1, 1] on given face."""
    if face == 0:
        return y / x, z / x
    elif face == 1:
        return -x / y, z / y
    elif face == 2:
        return -x / z, -y / z
    elif face == 3:
        return z / x, y / x
    elif face == 4:
        return z / y, -x / y
    else:  # face == 5
        return -y / z, -x / z


def uv_to_st(u: float) -> float:
    """Quadratic transformation from UV coordinates to ST range [0, 1]."""
    if u >= 0:
        return 0.5 * math.sqrt(1.0 + 3.0 * u)
    else:
        return 1.0 - 0.5 * math.sqrt(1.0 - 3.0 * u)


# Hilbert curve lookup tables for 2-bit cells
# Given orientation and (i, j) subcell, returns (subcell_index, new_orientation)
_IJ_TO_SUBCELL = [
    [0, 1, 3, 2],  # Orientation 0
    [0, 2, 3, 1],  # Orientation 1
    [3, 2, 0, 1],  # Orientation 2
    [3, 1, 0, 2],  # Orientation 3
]

_SUBCELL_TO_BITS = [
    [0, 1, 3, 2],
    [0, 2, 3, 1],
    [3, 2, 0, 1],
    [3, 1, 0, 2],
]

_LOOKUP_ORIENTATION = [
    [1, 0, 0, 3],
    [0, 1, 1, 2],
    [3, 2, 2, 1],
    [2, 3, 3, 0],
]


def lat_lng_to_s2_cell_id(lat: float, lon: float, level: int = 15) -> int:
    """
    Computes 64-bit S2 Cell ID for coordinates at given level (default level 15, ~150-300m cells).
    """
    x, y, z = lat_lng_to_xyz(lat, lon)
    face = xyz_to_face(x, y, z)
    u, v = valid_face_uv(face, x, y, z)

    # Convert to ST [0, 1]
    s = 0.5 * (u + 1.0)
    t = 0.5 * (v + 1.0)
    s = max(0.0, min(1.0, s))
    t = max(0.0, min(1.0, t))

    # Scale to 30-bit integers
    max_size = 1 << 30
    si = min(max_size - 1, int(s * max_size))
    ti = min(max_size - 1, int(t * max_size))

    # Traverse Hilbert curve down to level
    cell_id = face << 60
    orientation = 0

    for i in range(29, 29 - level, -1):
        bit_s = (si >> i) & 1
        bit_t = (ti >> i) & 1
        pos = (bit_s << 1) | bit_t

        subcell = _IJ_TO_SUBCELL[orientation][pos]
        orientation = _LOOKUP_ORIENTATION[orientation][subcell]

        # Shift cell_id
        shift = 2 * (30 - (30 - i))
        cell_id |= subcell << (2 * i + 1)

    # Set the sentinel bit at level
    cell_id |= 1 << (2 * (30 - level))
    return cell_id


def cell_id_to_token(cell_id: int) -> str:
    """
    Converts 64-bit S2 Cell ID to hex string token (without trailing zeros).
    """
    hex_str = f"{cell_id:016x}".rstrip("0")
    return hex_str if hex_str else "0"


def get_s2_cell_token(lat: float, lon: float, level: int = 15) -> str:
    """
    High-level convenience function returning S2 token string for given lat/lon.
    """
    cell_id = lat_lng_to_s2_cell_id(lat, lon, level=level)
    return cell_id_to_token(cell_id)
