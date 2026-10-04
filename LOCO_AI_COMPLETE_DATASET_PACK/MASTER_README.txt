LOCO AI — COMPLETE DATASET PACK
=================================

This ZIP combines the earlier development dataset pack with the verified real-data
pack.

IMPORTANT:
- 01_SYNTHETIC_DEVELOPMENT_DATA = synthetic/derived prototype data. DO NOT call it
  official railway data.
- 02_REAL_VERIFIED_MRVC_DATA = data transcribed/extracted from the published MRVC
  Mumbai Suburban Rail Passenger Surveys and Analysis report.
- Historical MRVC data is not live 2026 telemetry.
- The BMC Mumbai Suburban Network 2025 KML source is referenced in the real-data
  pack but was not copied into this ZIP because direct binary download was not
  available in the runtime.
- Before production use, add source_url/source_type/date columns to every dataset.

PRIMARY REAL SOURCE:
https://mrvc.indianrailways.gov.in/uploads/ExecutiveSummarywilber%20FINAL.pdf

The MRVC report documents surveys covering station entry/exit counts, FOB counts,
boarding/alighting, selected train services, and 25,000 commuter feedback samples.

Use the REAL folder first for your academic evidence. Use the SYNTHETIC folder
only where public real data is unavailable and label it accordingly.
