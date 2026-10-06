import heapq
import hashlib
from datetime import datetime, timezone
from typing import Dict, List, Optional, Set, Tuple
from app.models.station import Station
from app.models.railway_line import RailwayLine
from app.models.station_connection import StationConnection
from app.schemas.routing import RouteLegRead, RouteOptionRead
from app.core.logging import logger


class RailwayEdge:
    def __init__(
        self,
        from_station_id: str,
        to_station_id: str,
        line_id: Optional[str],
        line_code: str,
        line_name: str,
        line_color: str,
        distance_km: float,
        travel_seconds: int,
        is_transfer: bool = False,
    ):
        self.from_station_id = from_station_id
        self.to_station_id = to_station_id
        self.line_id = line_id
        self.line_code = line_code
        self.line_name = line_name
        self.line_color = line_color
        self.distance_km = distance_km
        self.travel_seconds = travel_seconds
        self.is_transfer = is_transfer


class RailwayGraph:
    """In-memory weighted graph G=(V,E) constructed from PostgreSQL network models."""

    def __init__(self):
        self.adjacency: Dict[str, List[RailwayEdge]] = {}
        self.stations: Dict[str, Station] = {}
        self.lines: Dict[str, RailwayLine] = {}
        self.version = "1.0.0"

    def build(
        self,
        stations: List[Station],
        lines: List[RailwayLine],
        connections: List[StationConnection],
    ):
        self.stations = {s.id: s for s in stations}
        # Also index by uppercase station code
        for s in stations:
            self.stations[s.code.upper()] = s

        self.lines = {l.id: l for l in lines}
        self.adjacency = {s.id: [] for s in stations}

        for conn in connections:
            if not conn.is_active:
                continue
            line = self.lines.get(conn.line_id) if conn.line_id else None
            edge = RailwayEdge(
                from_station_id=conn.from_station_id,
                to_station_id=conn.to_station_id,
                line_id=conn.line_id,
                line_code=line.code if line else "TRANSFER",
                line_name=line.name if line else "Interchange Walk",
                line_color=line.color_code if line else "#9E9E9E",
                distance_km=conn.distance_km,
                travel_seconds=conn.scheduled_travel_seconds,
                is_transfer=conn.is_transfer,
            )
            if conn.from_station_id in self.adjacency:
                self.adjacency[conn.from_station_id].append(edge)

        logger.info(
            "Constructed RailwayGraph with %d stations and %d active edges.",
            len(stations),
            sum(len(e) for e in self.adjacency.values()),
        )

    def resolve_station(self, identifier: str) -> Optional[Station]:
        cleaned = identifier.strip()
        if cleaned in self.stations:
            return self.stations[cleaned]
        upper = cleaned.upper()
        if upper in self.stations:
            return self.stations[upper]
        return None


class RoutingEngine:
    """
    Authoritative Railway Route Calculation & Ranking Engine.
    Implements Dijkstra and Multi-Objective Shortest Path over the Railway Graph.
    """

    def __init__(self, graph: RailwayGraph):
        self.graph = graph

    def search_routes(
        self,
        origin_id: str,
        destination_id: str,
        departure_time: Optional[datetime] = None,
        preferences: str = "FASTEST",
    ) -> List[RouteOptionRead]:
        origin = self.graph.resolve_station(origin_id)
        destination = self.graph.resolve_station(destination_id)

        if not origin or not destination:
            return []

        if origin.id == destination.id:
            return []

        routes: List[RouteOptionRead] = []

        # 1. Calculate Primary Path (Fastest / Least travel time)
        fastest_path = self._dijkstra(
            origin.id,
            destination.id,
            weight_mode="TIME",
            transfer_penalty_sec=180,
        )
        if fastest_path:
            route_opt = self._build_route_option(
                fastest_path,
                title="FASTEST",
                badge_text="⚡ Fastest",
                service_type="FAST",
            )
            routes.append(route_opt)

        # 2. Calculate Fewest Transfers Path (Heavy transfer penalty: 15 mins)
        fewest_transfers_path = self._dijkstra(
            origin.id,
            destination.id,
            weight_mode="FEWEST_TRANSFERS",
            transfer_penalty_sec=900,
        )
        if fewest_transfers_path and not self._is_duplicate_path(fastest_path, fewest_transfers_path):
            route_opt = self._build_route_option(
                fewest_transfers_path,
                title="FEWEST_TRANSFERS",
                badge_text="🎯 Direct / Fewest Transfers",
                service_type="SLOW",
            )
            routes.append(route_opt)

        # 3. Calculate Shortest Physical Distance Path
        shortest_dist_path = self._dijkstra(
            origin.id,
            destination.id,
            weight_mode="DISTANCE",
            transfer_penalty_sec=60,
        )
        if shortest_dist_path and not any(self._is_duplicate_path(p, shortest_dist_path) for p in [fastest_path, fewest_transfers_path]):
            route_opt = self._build_route_option(
                shortest_dist_path,
                title="SHORTEST_DISTANCE",
                badge_text="📍 Shortest Track",
                service_type="SLOW",
            )
            routes.append(route_opt)

        # 4. Generate AC EMU Comfort Option if routes exist
        if routes:
            base_opt = routes[0]
            ac_route = self._build_ac_comfort_option(base_opt)
            routes.append(ac_route)

        # 5. Route Ranking based on user preference
        return self._rank_routes(routes, preferences)

    def _dijkstra(
        self,
        start_id: str,
        goal_id: str,
        weight_mode: str = "TIME",
        transfer_penalty_sec: int = 180,
        exclude_edges: Optional[Set[Tuple[str, str]]] = None,
    ) -> Optional[List[RailwayEdge]]:
        """Weighted shortest-path search with transfer and line-switch awareness."""
        exclude = exclude_edges or set()

        # Priority Queue elements: (cost, current_node_id, current_line_id, edge_path)
        pq: List[Tuple[float, str, Optional[str], List[RailwayEdge]]] = [
            (0.0, start_id, None, [])
        ]
        best_costs: Dict[Tuple[str, Optional[str]], float] = {(start_id, None): 0.0}

        while pq:
            curr_cost, curr_node, curr_line, path = heapq.heappop(pq)

            if curr_node == goal_id:
                return path

            state_key = (curr_node, curr_line)
            if curr_cost > best_costs.get(state_key, float("inf")):
                continue

            for edge in self.graph.adjacency.get(curr_node, []):
                if (edge.from_station_id, edge.to_station_id) in exclude:
                    continue

                # Calculate incremental weight
                if weight_mode == "DISTANCE":
                    inc_cost = edge.distance_km
                    if curr_line and edge.line_id and curr_line != edge.line_id:
                        inc_cost += 1.0  # Transfer penalty in km
                else:  # TIME or FEWEST_TRANSFERS
                    inc_cost = edge.travel_seconds
                    if edge.is_transfer:
                        inc_cost += transfer_penalty_sec
                    elif curr_line and edge.line_id and curr_line != edge.line_id:
                        inc_cost += transfer_penalty_sec

                next_cost = curr_cost + inc_cost
                next_line = edge.line_id or curr_line
                next_key = (edge.to_station_id, next_line)

                if next_cost < best_costs.get(next_key, float("inf")):
                    best_costs[next_key] = next_cost
                    heapq.heappush(pq, (next_cost, edge.to_station_id, next_line, path + [edge]))

        return None

    def _build_route_option(
        self,
        edges: List[RailwayEdge],
        title: str,
        badge_text: str,
        service_type: str = "SLOW",
    ) -> RouteOptionRead:
        if not edges:
            raise ValueError("Empty edge path cannot form a route option.")

        origin_st = self.graph.stations[edges[0].from_station_id]
        dest_st = self.graph.stations[edges[-1].to_station_id]

        legs: List[RouteLegRead] = []
        curr_leg_edges: List[RailwayEdge] = []
        transfers_count = 0
        total_dist = 0.0
        total_time_sec = 0

        for edge in edges:
            total_dist += edge.distance_km
            total_time_sec += edge.travel_seconds

            if not curr_leg_edges:
                curr_leg_edges.append(edge)
            elif curr_leg_edges[0].line_id == edge.line_id and not edge.is_transfer:
                curr_leg_edges.append(edge)
            else:
                # Flush previous leg
                legs.append(self._compile_leg(curr_leg_edges, len(legs) + 1, service_type))
                if edge.is_transfer or (curr_leg_edges[0].line_id and edge.line_id and curr_leg_edges[0].line_id != edge.line_id):
                    transfers_count += 1
                curr_leg_edges = [edge]

        if curr_leg_edges:
            legs.append(self._compile_leg(curr_leg_edges, len(legs) + 1, service_type))

        # Check for direct single-line route
        if len(legs) == 1 and not legs[0].is_transfer:
            badge_text = "⚡ Direct Local"

        # Estimated fare (standard base suburban ₹10, AC ₹65)
        # 10 for <= 15km, 15 for 15-30km, 20 for > 30km
        base_fare = 10 if total_dist <= 15 else (15 if total_dist <= 30 else 20)
        ac_fare = base_fare * 6

        # Deterministic route ID
        hasher = hashlib.sha256()
        hasher.update(f"{origin_st.code}:{dest_st.code}:{len(edges)}:{title}".encode("utf-8"))
        route_id = f"route_{hasher.hexdigest()[:16]}"

        return RouteOptionRead(
            route_id=route_id,
            title=title,
            badge_text=badge_text,
            origin_station_id=origin_st.id,
            origin_station_code=origin_st.code,
            origin_station_name=origin_st.name,
            destination_station_id=dest_st.id,
            destination_station_code=dest_st.code,
            destination_station_name=dest_st.name,
            total_duration_seconds=total_time_sec,
            total_duration_minutes=round(total_time_sec / 60),
            total_distance_km=round(total_dist, 2),
            transfers_count=transfers_count,
            total_stops=len(edges),
            legs=legs,
            fare_estimate=base_fare,
            ac_fare_estimate=ac_fare,
            service_status="ACTIVE",
            network_version=self.graph.version,
            calculated_at=datetime.now(timezone.utc),
        )

    def _compile_leg(
        self,
        leg_edges: List[RailwayEdge],
        leg_index: int,
        service_type: str,
    ) -> RouteLegRead:
        first = leg_edges[0]
        last = leg_edges[-1]
        from_st = self.graph.stations[first.from_station_id]
        to_st = self.graph.stations[last.to_station_id]

        # Station names and codes in order
        station_sequence: List[str] = [from_st.name]
        station_codes: List[str] = [from_st.code]
        for e in leg_edges:
            st = self.graph.stations[e.to_station_id]
            station_sequence.append(st.name)
            station_codes.append(st.code)

        leg_dist = sum(e.distance_km for e in leg_edges)
        leg_time = sum(e.travel_seconds for e in leg_edges)

        transfer_inst = None
        if first.is_transfer:
            transfer_inst = f"Change platforms via Foot Overbridge at {from_st.name} ({round(leg_time / 60)} min transfer)"

        return RouteLegRead(
            leg_index=leg_index,
            line_id=first.line_id,
            line_code=first.line_code,
            line_name=first.line_name,
            line_color=first.line_color,
            from_station_id=from_st.id,
            from_station_code=from_st.code,
            from_station_name=from_st.name,
            to_station_id=to_st.id,
            to_station_code=to_st.code,
            to_station_name=to_st.name,
            station_sequence=station_sequence,
            station_codes=station_codes,
            duration_seconds=leg_time,
            duration_minutes=round(leg_time / 60),
            distance_km=round(leg_dist, 2),
            is_transfer=first.is_transfer,
            transfer_instructions=transfer_inst,
            service_type=service_type if not first.is_transfer else "TRANSFER",
        )

    def _build_ac_comfort_option(self, base_route: RouteOptionRead) -> RouteOptionRead:
        hasher = hashlib.sha256()
        hasher.update(f"{base_route.route_id}:AC_COMFORT".encode("utf-8"))
        ac_route_id = f"route_{hasher.hexdigest()[:16]}"

        ac_legs: List[RouteLegRead] = []
        for leg in base_route.legs:
            ac_legs.append(
                RouteLegRead(
                    leg_index=leg.leg_index,
                    line_id=leg.line_id,
                    line_code=leg.line_code,
                    line_name=leg.line_name,
                    line_color=leg.line_color,
                    from_station_id=leg.from_station_id,
                    from_station_code=leg.from_station_code,
                    from_station_name=leg.from_station_name,
                    to_station_id=leg.to_station_id,
                    to_station_code=leg.to_station_code,
                    to_station_name=leg.to_station_name,
                    station_sequence=leg.station_sequence,
                    station_codes=leg.station_codes,
                    duration_seconds=leg.duration_seconds,
                    duration_minutes=leg.duration_minutes,
                    distance_km=leg.distance_km,
                    is_transfer=leg.is_transfer,
                    transfer_instructions=leg.transfer_instructions,
                    service_type="AC_FAST" if not leg.is_transfer else "TRANSFER",
                )
            )

        return RouteOptionRead(
            route_id=ac_route_id,
            title="AC_COMFORT",
            badge_text="❄️ AC Local EMU",
            origin_station_id=base_route.origin_station_id,
            origin_station_code=base_route.origin_station_code,
            origin_station_name=base_route.origin_station_name,
            destination_station_id=base_route.destination_station_id,
            destination_station_code=base_route.destination_station_code,
            destination_station_name=base_route.destination_station_name,
            total_duration_seconds=base_route.total_duration_seconds,
            total_duration_minutes=base_route.total_duration_minutes,
            total_distance_km=base_route.total_distance_km,
            transfers_count=base_route.transfers_count,
            total_stops=base_route.total_stops,
            legs=ac_legs,
            fare_estimate=base_route.ac_fare_estimate,
            ac_fare_estimate=base_route.ac_fare_estimate,
            service_status="ACTIVE",
            network_version=base_route.network_version,
            calculated_at=datetime.now(timezone.utc),
        )

    def _is_duplicate_path(
        self,
        p1: Optional[List[RailwayEdge]],
        p2: Optional[List[RailwayEdge]],
    ) -> bool:
        if not p1 or not p2:
            return False
        if len(p1) != len(p2):
            return False
        return all(
            e1.from_station_id == e2.from_station_id and e1.to_station_id == e2.to_station_id
            for e1, e2 in zip(p1, p2)
        )

    def _rank_routes(self, routes: List[RouteOptionRead], preference: str) -> List[RouteOptionRead]:
        """Rank routes according to user preference."""
        if preference == "FEWEST_TRANSFERS":
            routes.sort(key=lambda r: (r.transfers_count, r.total_duration_seconds))
        elif preference == "SHORTEST_DISTANCE":
            routes.sort(key=lambda r: (r.total_distance_km, r.total_duration_seconds))
        else:  # FASTEST
            routes.sort(key=lambda r: (r.total_duration_seconds, r.transfers_count))

        return routes
