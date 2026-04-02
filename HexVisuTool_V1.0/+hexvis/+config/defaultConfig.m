function cfg = defaultConfig()
%DEFAULTCONFIG Default configuration for modular HEXVIS.

    cfg.app.name = 'HEXVIS Modular Phase-1';
    cfg.app.figurePosition = [10 10 1680 940];

    cfg.channels.S1 = 1;
    cfg.channels.S2 = 3;
    cfg.geom.L_mm = 120;
    cfg.geom.v_ms = 7338;

    cfg.io.acceptedExt = '*.wave';
    cfg.io.forceDouble = true;

    cfg.deps.waveReaderRequired = true;
    cfg.deps.extractFeatureRequired = false;
    cfg.deps.externalAICPreferred = false;

    % ---------- Internal robust AIC ----------
    % Design intent:
    % 1) robust baseline removal using pretrigger median
    % 2) spike suppression using a short median filter
    % 3) onset pre-detection on a smoothed envelope
    % 4) local AIC minimization around the first sustained crossing
    % 5) backward refinement to an earlier low-threshold sustained point
    % 6) dual-channel pair refinement with a physical dt limit
    cfg.aic.method = 'internal_robust';
    cfg.aic.noiseSigma = 5.0;
    cfg.aic.relAmpFrac = 0.05;
    cfg.aic.smooth_us = 2.0;
    cfg.aic.minRun_us = 3.0;
    cfg.aic.preAICPad_us = 40.0;
    cfg.aic.postAICPad_us = 12.0;
    cfg.aic.maxSearch_us = 500.0;
    cfg.aic.refineLowFrac = 0.50;   % low threshold = refineLowFrac * high threshold
    cfg.aic.medfilt_us = 1.0;
    cfg.aic.pair.enabled = true;
    cfg.aic.pair.maxDtFactor = 2.0;
    cfg.aic.pair.maxCandidates = 5;
    cfg.aic.pair.penaltyDt = 0.75;
    cfg.aic.pair.penaltyLate = 1.00;

    cfg.features.windowMode = 'aic_to_end';
    cfg.features.requireAICForSegmented = false;

    cfg.vis.fmax_kHz = 500;
    cfg.vis.fftFmax_kHz = 500;
    cfg.vis.window.start_us = 0;
    cfg.vis.window.end_us = 500;
    cfg.vis.sharedColorbar = true;

    cfg.vis.cwt.wavelet = 'amor';
    cfg.vis.cwt.voicesPerOctave = 32;
    cfg.vis.cwt.threshold = 0.01;
    cfg.vis.cwt.gamma = 1.0;
    cfg.vis.cwt.clip = [0 1];
    cfg.vis.cwt.fmax_kHz = 500;
    cfg.vis.cwt.nFreqBins = 400;
    cfg.vis.cwt.showColorbar = false;
    cfg.vis.cwt.colormapName = 'jet';

    cfg.vis.quick.fmax_kHz = 500;
    cfg.vis.quick.clim_dB = [-60 0];
    cfg.vis.quick.nfft = 1024;
    cfg.vis.quick.windowLength = 128;
    cfg.vis.quick.overlap = 120;

    cfg.vis.defaultTFMode = 'cwt';

    cfg.ui.tableMaxColumns = inf;
    cfg.ui.showAdvancedStatus = true;
end
