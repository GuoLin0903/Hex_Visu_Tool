HEXVIS modular package (current build)
=====================================

Purpose
-------
This folder is a clean modular rebuild of the dual-channel AE visualizer for
Hexagon .wave files.

Current priorities of this build:
1) stable running,
2) cleaner UI separation,
3) internal robust AIC picker,
4) feature extraction separated from UI,
5) CWT and tfrsp preview kept lightweight.

How to use
----------
Place this folder on the MATLAB path together with the following dependencies:
    waveReader.p      (required)
    ExtractFeati_OPT.m (optional but recommended)
    tfrsp.m            (optional, only needed for TF mode = tfrsp)

Then in MATLAB:
    >> run_hexvis

What is implemented now
-----------------------
- Main entry: run_hexvis.m
- Config module: +hexvis/+config
- Wave loading wrapper: +hexvis/+io/readWaveFile.m
- Event table creation: +hexvis/+io/buildEventTable.m
- Internal robust AIC picker:
  +hexvis/+aic/pickAllEvents.m
  Pipeline: median filter -> smoothed envelope -> sustained threshold ->
  local AIC -> backward refinement -> dual-channel pair refinement
- Feature wrapper:
  +hexvis/+features/extractBatchFeatures.m
- Visualization:
  +hexvis/+vis/plotCWTModal.m
  +hexvis/+vis/plotTFRSPQuick.m
- UI/controller separation:
  +hexvis/+ui/layoutMainUI.m
  +hexvis/+ui/buildMainUI.m
  +hexvis/+ui/refreshUI.m
  +hexvis/+controller/launchApp.m

Design note
-----------
This build no longer depends on external AE_Tools_V3 for onset picking.
The AIC logic is internal so the tool behavior is easier to maintain and tune.

Next likely optimization steps
------------------------------
1) add current-event AIC diagnostic preview,
2) expose a confidence score / suspicious-event flag,
3) improve source-location logic beyond constant-velocity 1D positioning,
4) add export of screenshots + matrices,
5) add optional dispersion overlays later.
