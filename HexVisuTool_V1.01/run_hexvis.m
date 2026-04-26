function fig = run_hexvis()
%RUN_HEXVIS Entry point for HexVisuTool V1.01.
% V1.01 keeps the V1.0 UI and adds an optional DC dispersion overlay.

    startup_hexvis();

    cfg = hexvis.config.defaultConfig();
    cfg = hexvis.config.validateConfig(cfg);

    fig = hexvis.controller.launchApp(cfg);

    % Add V1.01 overlay controls after the original V1.0 app is launched.
    hexvis.disp.installOverlayControls(fig);
end
