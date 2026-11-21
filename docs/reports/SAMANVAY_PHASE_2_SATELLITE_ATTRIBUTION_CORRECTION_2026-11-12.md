# Satellite basemap attribution correction

**Date:** 12 November 2026

The MapLibre satellite basemap has two supported providers:
- MapTiler Hybrid when the build-time `MAPTILER_API_KEY` is configured.
- Esri World Imagery + Esri reference labels when no MapTiler key is configured.

The visible bottom attribution previously always displayed MapTiler on satellite mode. This was incorrect in no-key builds, where the actual raster style is Esri. The UI now displays MapTiler/OSM credits for MapTiler Hybrid and the Esri/Maxar/Earthstar/USDA FSA/USGS/GIS User Community source attribution for the Esri fallback. The existing vector attribution remains OpenFreeMap/OSM.

This is a source-attribution correction; it does not claim to fix imagery coverage, update image dates or change any tile provider.
