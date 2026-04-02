function fig = run_hexvis()
%RUN_HEXVIS Entry point for the modular dual-channel AE visualizer.
%
% Phase 1 target:
%   - stable startup
%   - modular code layout
%   - AIC isolated in +hexvis/+aic
%   - feature extraction isolated in +hexvis/+features
%   - visualization isolated in +hexvis/+vis
%   - UI isolated in +hexvis/+ui
%   - first priority: make the whole program run cleanly
%
% Usage:
%   >> run_hexvis

    startup_hexvis();
    cfg = hexvis.config.defaultConfig();
    cfg = hexvis.config.validateConfig(cfg);
    fig = hexvis.controller.launchApp(cfg);
end
