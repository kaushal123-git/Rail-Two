LOCO AI — REAL DATA PACK
=========================

This package contains ONLY source-extracted/verified historical data from the
MRVC Mumbai Suburban Rail Passenger Surveys and Analysis report.

PRIMARY SOURCE:
https://mrvc.indianrailways.gov.in/uploads/ExecutiveSummarywilber%20FINAL.pdf

Publisher: Mumbai Railway Vikas Corporation Ltd. / Wilbur Smith Associates.

IMPORTANT:
- These are REAL historical observations and published model forecasts.
- They are NOT current/live 2026 telemetry.
- Do not describe them as live train GPS, current platform assignments, or current crowd density.
- The MRVC study covers selected stations/services and specific survey periods.
- Values were transcribed from the report tables; they were not synthetically generated.

BMC NETWORK SOURCE:
https://data.opencity.in/dataset/mumbai-suburban-network-2025

The BMC/OpenCity page provides public-domain KML resources for Mumbai's suburban
line and station network. The KML binaries were not included because the portal
blocked direct retrieval in this environment. Use the source page above to
download them directly.

Recommended LOCO use:
1. Station crowd/flow prediction -> station entry/exit + hourly data.
2. Congestion prediction -> peak passenger/service distributions.
3. Ticket queue prediction -> queue observations.
4. Route/corridor demand features -> OD forecast.
5. Network mapping -> BMC KML (download separately).

DO NOT combine these historical tables with synthetic/live-looking telemetry
without a clear source_type column.
