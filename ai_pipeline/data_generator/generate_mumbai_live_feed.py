"""
Mumbai Suburban Railway Live Telemetry & Timetable Data Generator
Generates schedule-accurate and physics-grounded real-time feeds
for Mumbai Suburban Western & Central Lines.
"""

import json
import random
import time
from datetime import datetime, timedelta

# Official Western Railway Line Station Distances (from Churchgate in km)
WESTERN_LINE_STATIONS = [
    {"id": "churchgate", "name": "Churchgate", "code": "CCG", "dist_km": 0.0, "platforms": 4, "is_junction": False},
    {"id": "marine_lines", "name": "Marine Lines", "code": "MEL", "dist_km": 1.4, "platforms": 4, "is_junction": False},
    {"id": "charni_road", "name": "Charni Road", "code": "CYR", "dist_km": 2.4, "platforms": 4, "is_junction": False},
    {"id": "grant_road", "name": "Grant Road", "code": "GTR", "dist_km": 3.8, "platforms": 4, "is_junction": False},
    {"id": "mumbai_central", "name": "Mumbai Central", "code": "MMCT", "dist_km": 4.6, "platforms": 5, "is_junction": True},
    {"id": "mahalaxmi", "name": "Mahalaxmi", "code": "MX", "dist_km": 6.2, "platforms": 3, "is_junction": False},
    {"id": "lower_parel", "name": "Lower Parel", "code": "PL", "dist_km": 7.8, "platforms": 3, "is_junction": False},
    {"id": "prabhadevi", "name": "Prabhadevi", "code": "PBHD", "dist_km": 9.1, "platforms": 2, "is_junction": False},
    {"id": "dadar_wr", "name": "Dadar (WR / CR)", "code": "DDR", "dist_km": 10.2, "platforms": 8, "is_junction": True},
    {"id": "matunga_road", "name": "Matunga Road", "code": "MRU", "dist_km": 11.5, "platforms": 2, "is_junction": False},
    {"id": "mahim", "name": "Mahim", "code": "MM", "dist_km": 13.0, "platforms": 4, "is_junction": True},
    {"id": "bandra", "name": "Bandra", "code": "BA", "dist_km": 14.8, "platforms": 7, "is_junction": True},
    {"id": "khar_road", "name": "Khar Road", "code": "KHAR", "dist_km": 16.4, "platforms": 4, "is_junction": False},
    {"id": "santa_cruz", "name": "Santa Cruz", "code": "STC", "dist_km": 18.0, "platforms": 4, "is_junction": False},
    {"id": "vile_parle", "name": "Vile Parle", "code": "VLP", "dist_km": 20.0, "platforms": 4, "is_junction": False},
    {"id": "andheri", "name": "Andheri", "code": "ADH", "dist_km": 21.8, "platforms": 9, "is_junction": True},
    {"id": "jogeshwari", "name": "Jogeshwari", "code": "JOS", "dist_km": 23.9, "platforms": 4, "is_junction": False},
    {"id": "ram_mandir", "name": "Ram Mandir", "code": "RMAR", "dist_km": 25.2, "platforms": 4, "is_junction": False},
    {"id": "goregaon", "name": "Goregaon", "code": "GMN", "dist_km": 26.6, "platforms": 7, "is_junction": True},
    {"id": "malad", "name": "Malad", "code": "MDD", "dist_km": 29.8, "platforms": 4, "is_junction": False},
    {"id": "kandivali", "name": "Kandivali", "code": "KILE", "dist_km": 31.7, "platforms": 4, "is_junction": False},
    {"id": "borivali", "name": "Borivali", "code": "BVI", "dist_km": 34.0, "platforms": 10, "is_junction": True},
    {"id": "dahisar", "name": "Dahisar", "code": "DIC", "dist_km": 36.6, "platforms": 4, "is_junction": False},
    {"id": "mira_road", "name": "Mira Road", "code": "MIRA", "dist_km": 40.0, "platforms": 4, "is_junction": False},
    {"id": "bhayandar", "name": "Bhayandar", "code": "BYR", "dist_km": 43.4, "platforms": 6, "is_junction": True},
    {"id": "naigaon", "name": "Naigaon", "code": "NIG", "dist_km": 48.0, "platforms": 2, "is_junction": False},
    {"id": "vasai_road", "name": "Vasai Road", "code": "BSR", "dist_km": 52.0, "platforms": 7, "is_junction": True},
    {"id": "nalasopara", "name": "Nalasopara", "code": "NSP", "dist_km": 56.1, "platforms": 4, "is_junction": False},
    {"id": "virar", "name": "Virar", "code": "VR", "dist_km": 60.0, "platforms": 8, "is_junction": True},
]

# Fast trains only halt at major stations
FAST_HALT_STATIONS = {"virar", "vasai_road", "bhayandar", "borivali", "andheri", "bandra", "dadar_wr", "mumbai_central", "grant_road", "charni_road", "marine_lines", "churchgate"}

def is_peak_hour(dt: datetime) -> bool:
    hour = dt.hour
    return (8 <= hour <= 11) or (17 <= hour <= 21)

def generate_live_schedule(base_time: datetime = None, num_services: int = 24):
    """
    Generates a full schedule of live trains running on the Western Line corridor.
    Includes physics parameters: target speed, scheduled vs actual arrival, dwell time,
    coach crowding factors, and delay deviations.
    """
    if base_time is None:
        base_time = datetime.now()

    services = []
    
    train_templates = [
        {"prefix": "90", "type": "Fast Local", "cars": 15, "is_ac": False, "speed": 68.0},
        {"prefix": "92", "type": "AC EMU", "cars": 12, "is_ac": True, "speed": 65.0},
        {"prefix": "94", "type": "Slow Local", "cars": 12, "is_ac": False, "speed": 52.0},
    ]

    for i in range(num_services):
        tmpl = train_templates[i % len(train_templates)]
        train_num = f"{tmpl['prefix']}{random.randint(100, 999)}"
        direction = "Southbound" if (i % 2 == 0) else "Northbound"
        
        origin = "Virar" if direction == "Southbound" else "Churchgate"
        destination = "Churchgate" if direction == "Southbound" else "Virar"
        
        # Calculate departure offset
        dep_offset_min = (i * 4) - 15  # Some already running, some upcoming
        dep_time = base_time + timedelta(minutes=dep_offset_min)
        
        # Simulation delay (0-4 mins normally, 6-12 mins during simulated congestion)
        has_delay = random.random() < 0.25
        delay_min = random.choice([2, 3, 5, 7]) if has_delay else 0
        
        # Station halts list
        halts = []
        cumulative_min = 0.0
        
        station_list = WESTERN_LINE_STATIONS if direction == "Southbound" else list(reversed(WESTERN_LINE_STATIONS))
        prev_dist = 0.0
        
        for idx, st in enumerate(station_list):
            is_fast = tmpl["type"] == "Fast Local"
            
            # If Fast Local and not a major halt, skip
            if is_fast and st["id"] not in FAST_HALT_STATIONS:
                continue
                
            dist_delta = abs(st["dist_km"] - prev_dist)
            prev_dist = st["dist_km"]
            
            # Transit time in minutes based on distance & average suburban speed
            travel_time_min = (dist_delta / tmpl["speed"]) * 60.0 if dist_delta > 0 else 0.0
            cumulative_min += travel_time_min
            
            # Dwell time at station (longer at Dadar/Andheri/Borivali during peak)
            dwell_seconds = 45 if (st["is_junction"] and is_peak_hour(base_time)) else 25
            cumulative_min += (dwell_seconds / 60.0)
            
            sched_arr = dep_time + timedelta(minutes=cumulative_min)
            actual_arr = sched_arr + timedelta(minutes=delay_min)
            
            halts.append({
                "station_id": st["id"],
                "station_name": st["name"],
                "station_code": st["code"],
                "platform": random.randint(1, st["platforms"]),
                "scheduled_time": sched_arr.strftime("%I:%M %p"),
                "estimated_time": actual_arr.strftime("%I:%M %p"),
                "dwell_seconds": dwell_seconds,
            })

        # Calculate current position of the train relative to base_time
        current_st_idx = 0
        current_status = "Scheduled"
        for h_idx, halt in enumerate(halts):
            halt_dt = datetime.strptime(halt["estimated_time"], "%I:%M %p").replace(
                year=base_time.year, month=base_time.month, day=base_time.day
            )
            if halt_dt <= base_time:
                current_st_idx = h_idx
                current_status = "In Transit"

        # Crowd prediction vector across 12/15 coaches
        coach_count = tmpl["cars"]
        peak = is_peak_hour(base_time)
        base_crowd = 140 if (peak and not tmpl["is_ac"]) else (65 if tmpl["is_ac"] else 80)
        
        coach_crowd = []
        for c in range(1, coach_count + 1):
            # Middle coaches (near FOB stairs) are notoriously more crowded
            is_middle = (coach_count // 3) <= c <= (2 * coach_count // 3)
            multiplier = 1.35 if is_middle else 0.85
            load_pct = min(220, int(base_crowd * multiplier + random.randint(-15, 15)))
            coach_crowd.append({
                "coach_no": f"C{c}",
                "crowd_pct": load_pct,
                "density_category": "Very High" if load_pct > 150 else ("High" if load_pct > 110 else ("Moderate" if load_pct > 70 else "Low"))
            })

        services.append({
            "service_id": f"WR-{train_num}",
            "train_number": train_num,
            "train_type": tmpl["type"],
            "line": "Western",
            "is_ac": tmpl["is_ac"],
            "cars": tmpl["cars"],
            "origin": origin,
            "destination": destination,
            "current_station": halts[min(current_st_idx, len(halts) - 1)]["station_name"],
            "next_station": halts[min(current_st_idx + 1, len(halts) - 1)]["station_name"],
            "delay_minutes": delay_min,
            "status": "On Time" if delay_min == 0 else f"Delayed +{delay_min}m",
            "halts": halts,
            "coach_crowd_telemetry": coach_crowd,
            "generated_timestamp": base_time.isoformat(),
        })

    return services

if __name__ == "__main__":
    now = datetime.now()
    feed = generate_live_schedule(now, num_services=30)
    
    output_path = "assets/mumbai_live_rail_feed.json"
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(feed, f, indent=2)
        
    print(f"Successfully generated {len(feed)} live Mumbai train services to {output_path}")
