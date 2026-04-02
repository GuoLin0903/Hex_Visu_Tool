function app = refreshUI(app)
%REFRESHUI Update table, status text, and plots from the current app state.

    ui = app.ui;

    Tdisp = localDisplayTable(app);
    if isempty(Tdisp)
        ui.tbl.Data = cell(0,1);
        ui.tbl.ColumnName = {'eventID'};
    else
        ui.tbl.Data = table2cell(Tdisp);
        ui.tbl.ColumnName = Tdisp.Properties.VariableNames;
        try, ui.tbl.ColumnWidth = 'auto'; catch, end
    end

    nEv = 0;
    if ~isempty(app.E), nEv = height(app.E); end
    if nEv == 0
        app.currentEvent = 1;
        set(ui.txtSelected, 'String', 'Selected: 0 / 0');
    else
        app.currentEvent = max(1, min(app.currentEvent, nEv));
        set(ui.txtSelected, 'String', sprintf('Selected: %d / %d', app.currentEvent, nEv));
    end

    set(ui.txtChannel, 'String', sprintf('S1 = ch %d    S2 = ch %d', app.cfg.channels.S1, app.cfg.channels.S2));
    set(ui.txtGeom, 'String', sprintf('L = %.1f mm    v = %.1f m/s', app.cfg.geom.L_mm, app.cfg.geom.v_ms));

    if isempty(app.D)
        set(ui.txtFile, 'String', '(none)');
        set(ui.txtFileInfo, 'String', 'No file loaded');
    else
        set(ui.txtFile, 'String', app.D.fileName);
        nTotal = app.D.nEvents;
        nValid = nTotal;
        if ~isempty(app.E) && ismember('loc_valid', app.E.Properties.VariableNames)
            vv = app.E.loc_valid;
            if islogical(vv) || isnumeric(vv)
                nValid = sum(logical(vv) & isfinite(vv));
            end
        elseif ~isempty(app.A) && isfield(app.A, 'valid')
            nValid = sum(logical(app.A.valid));
        end
        msg = sprintf('Events: %d/%d   Samples/event: %d   fs: %.3f MHz   preTrig: %g', ...
            nValid, nTotal, app.D.nSamples, app.D.fs/1e6, app.D.preTrigPoints);
        set(ui.txtFileInfo, 'String', msg);
    end

    localDrawPlots(app);
end

function Tdisp = localDisplayTable(app)
    if isempty(app.E) || height(app.E) == 0
        Tdisp = table();
        return;
    end

    E = app.E;
    baseVars = {'eventID', 'hittime_s', 't0_S1_us', 't0_S2_us', 'dt_us', 'x_mm', 'loc_valid', 'k0_samp'};
    baseVars = intersect(baseVars, E.Properties.VariableNames, 'stable');
    otherVars = setdiff(E.Properties.VariableNames, baseVars, 'stable');
    Tdisp = E(:, [baseVars otherVars]);
end

function localDrawPlots(app)
    ui = app.ui;
    axList = [ui.axS1t ui.axS2t ui.axS1f ui.axS2f ui.axS1tf ui.axS2tf];
    if isempty(app.D) || isempty(app.D.wave)
        localDeleteSharedColorbar(ui);
        for ax = axList
            cla(ax); text(ax, 0.5, 0.5, 'No data', 'HorizontalAlignment', 'center'); axis(ax, 'off');
        end
        return;
    end

    ev = max(1, min(app.currentEvent, app.D.nEvents));
    fs = app.D.fs;
    ch1 = app.cfg.channels.S1;
    ch2 = app.cfg.channels.S2;
    raw1 = double(app.D.wave(:, ch1, ev));
    raw2 = double(app.D.wave(:, ch2, ev));

    [start_us, end_us] = localReadWindow(ui, app.cfg.vis.window);
    [sig1, info1] = localCropSignal(raw1, fs, start_us, end_us);
    [sig2, info2] = localCropSignal(raw2, fs, start_us, end_us);

    k1 = nan; k2 = nan;
    if ~isempty(app.A) && isfield(app.A, 'idx') && size(app.A.idx,1) >= ev
        k1 = localShiftPick(app.A.idx(ev,1), info1.startIdx, info1.endIdx);
        k2 = localShiftPick(app.A.idx(ev,2), info2.startIdx, info2.endIdx);
    end

    fmax = localReadFmax(ui, app.cfg.vis.fmax_kHz);
    tfMode = localReadTFMode(ui);
    shareCB = localReadSharedColorbar(ui, app.cfg.vis.sharedColorbar);

    hexvis.vis.plotWaveform(ui.axS1t, sig1, fs, k1, sprintf('Event %d - S1 waveform', ev));
    hexvis.vis.plotWaveform(ui.axS2t, sig2, fs, k2, sprintf('Event %d - S2 waveform', ev));
    hexvis.vis.plotFFT(ui.axS1f, sig1, fs, app.cfg.vis.fftFmax_kHz, 'S1 FFT');
    hexvis.vis.plotFFT(ui.axS2f, sig2, fs, app.cfg.vis.fftFmax_kHz, 'S2 FFT');

    localDeleteSharedColorbar(ui);
    if strcmpi(tfMode, 'cwt')
        localDrawSharedCWT(app, sig1, sig2, fs, k1, k2, fmax, shareCB);
    else
        localDrawTFRSP(app, sig1, sig2, fs, k1, k2, fmax, shareCB);
    end

    localBeautifyPreview(ui);
end

function localBeautifyPreview(ui)
    % Top and middle rows do not need x-axis labels.
    xlabel(ui.axS1t, ''); xlabel(ui.axS2t, '');
    xlabel(ui.axS1f, ''); xlabel(ui.axS2f, '');
    set(ui.axS1t, 'XTickLabelMode', 'auto');
    set(ui.axS2t, 'XTickLabelMode', 'auto');
    set(ui.axS1f, 'XTickLabelMode', 'auto');
    set(ui.axS2f, 'XTickLabelMode', 'auto');

    % Right column omits y-axis labels to reduce crowding.
    ylabel(ui.axS2t, ''); ylabel(ui.axS2f, ''); ylabel(ui.axS2tf, '');

    % Keep titles close to axes, but safely below the panel border.
    localTitlePos(ui.axS1t, 1.01); localTitlePos(ui.axS2t, 1.01);
    localTitlePos(ui.axS1f, 1.01); localTitlePos(ui.axS2f, 1.01);
    localTitlePos(ui.axS1tf, 1.005); localTitlePos(ui.axS2tf, 1.005);
end

function localTitlePos(ax, y)
    try
        th = get(ax, 'Title');
        set(th, 'Units', 'normalized', 'Position', [0.5 y 0], 'VerticalAlignment', 'bottom');
    catch
    end
end

function localDrawSharedCWT(app, sig1, sig2, fs, k1, k2, fmax, shareCB)
    ui = app.ui;
    cfgCWT = app.cfg.vis.cwt;
    cfgCWT.fmax_kHz = fmax;

    M1 = hexvis.vis.computeCWTMap(sig1, fs, cfgCWT);
    M2 = hexvis.vis.computeCWTMap(sig2, fs, cfgCWT);

    if shareCB
        gmax = max([M1.rawMax, M2.rawMax, eps]);
        M1.A_show = localNormalizeMap(M1.A_lin, gmax, cfgCWT);
        M2.A_show = localNormalizeMap(M2.A_lin, gmax, cfgCWT);
        hexvis.vis.drawTFMap(ui.axS1tf, M1, k1, 'S1 CWT', [0 1], cfgCWT, false);
        hexvis.vis.drawTFMap(ui.axS2tf, M2, k2, 'S2 CWT', [0 1], cfgCWT, false);
        linkaxes([ui.axS1tf, ui.axS2tf], 'xy');
        ui.cbTF = colorbar(ui.axS2tf);
        set(ui.cbTF, 'Ticks', 0:0.2:1);
        ui.cbTF.Label.String = 'Norm |CWT|';
    else
        M1.A_show = localNormalizeMap(M1.A_lin, max(M1.rawMax, eps), cfgCWT);
        M2.A_show = localNormalizeMap(M2.A_lin, max(M2.rawMax, eps), cfgCWT);
        hexvis.vis.drawTFMap(ui.axS1tf, M1, k1, 'S1 CWT', [0 1], cfgCWT, true);
        hexvis.vis.drawTFMap(ui.axS2tf, M2, k2, 'S2 CWT', [0 1], cfgCWT, true);
        linkaxes([ui.axS1tf, ui.axS2tf], 'xy');
    end
end

function localDrawTFRSP(app, sig1, sig2, fs, k1, k2, fmax, shareCB)
    ui = app.ui;
    C = app.cfg.vis.quick;
    C.fmax_kHz = fmax;

    if ~shareCB
        hexvis.vis.renderTF(ui.axS1tf, sig1, fs, k1, 'tfrsp', app.cfg.vis, 'S1 TFRSP');
        hexvis.vis.renderTF(ui.axS2tf, sig2, fs, k2, 'tfrsp', app.cfg.vis, 'S2 TFRSP');
        linkaxes([ui.axS1tf, ui.axS2tf], 'xy');
        return;
    end

    [ok1, M1] = localComputeTFRSP(sig1, fs, C);
    [ok2, M2] = localComputeTFRSP(sig2, fs, C);
    if ~(ok1 && ok2)
        hexvis.vis.renderTF(ui.axS1tf, sig1, fs, k1, 'tfrsp', app.cfg.vis, 'S1 TFRSP');
        hexvis.vis.renderTF(ui.axS2tf, sig2, fs, k2, 'tfrsp', app.cfg.vis, 'S2 TFRSP');
        linkaxes([ui.axS1tf, ui.axS2tf], 'xy');
        return;
    end

    clim = [min([M1.A_db(:); M2.A_db(:)]), max([M1.A_db(:); M2.A_db(:)])];
    clim(1) = min(clim(1), C.clim_dB(1));
    clim(2) = max(clim(2), C.clim_dB(2));
    clim = [max(clim(1), C.clim_dB(1)), min(clim(2), C.clim_dB(2))];
    localDrawTFRSPMap(ui.axS1tf, M1, k1, 'S1 TFRSP', clim);
    localDrawTFRSPMap(ui.axS2tf, M2, k2, 'S2 TFRSP', clim);
    linkaxes([ui.axS1tf, ui.axS2tf], 'xy');
    ui.cbTF = colorbar(ui.axS2tf);
    ui.cbTF.Label.String = 'Magnitude (dB)';
end

function [ok, M] = localComputeTFRSP(sig, fs, C)
    ok = false;
    M = struct('A_db', [], 't_us', [], 'f_kHz', []);
    sig = double(sig(:));
    sig = sig - mean(sig);
    if numel(sig) < 8 || exist('tfrsp', 'file') == 0
        return;
    end
    try
        [TFR, t_idx, f_norm] = tfrsp(sig);
    catch
        return;
    end
    A = abs(TFR);
    A = A ./ (max(A(:)) + eps);
    A_db = 20 * log10(A + eps);
    A_db(A_db < C.clim_dB(1)) = C.clim_dB(1);
    A_db(A_db > C.clim_dB(2)) = C.clim_dB(2);
    f_kHz = f_norm(:) * fs / 1e3;
    keep = f_kHz >= 0 & f_kHz <= C.fmax_kHz;
    f_kHz = f_kHz(keep);
    A_db = A_db(keep,:);
    t_us = (t_idx(:).' - 1) / fs * 1e6;
    M = struct('A_db', A_db, 't_us', t_us, 'f_kHz', f_kHz);
    ok = true;
end

function localDrawTFRSPMap(ax, M, pickIdx, ttl, clim)
    cla(ax);
    imagesc(ax, M.t_us, M.f_kHz, M.A_db);
    axis(ax, 'xy');
    xlim(ax, [0 M.t_us(end)]);
    ylim(ax, [0 max(M.f_kHz)]);
    caxis(ax, clim);
    colormap(ax, jet(256));
    xlabel(ax, 'Time (\mus)');
    ylabel(ax, 'Frequency (kHz)');
    title(ax, ttl, 'Interpreter', 'none');
    box(ax, 'on'); grid(ax, 'on');
    if isfinite(pickIdx) && pickIdx >= 1 && pickIdx <= numel(M.t_us)
        hold(ax, 'on');
        xline(ax, M.t_us(pickIdx), 'w--', 'LineWidth', 1.0);
        hold(ax, 'off');
    end
end

function Ashow = localNormalizeMap(Alin, normBase, cfgCWT)
    Ashow = Alin ./ (normBase + eps);
    Ashow(Ashow < cfgCWT.threshold) = 0;
    Ashow(Ashow > 1) = 1;
    Ashow = Ashow .^ cfgCWT.gamma;
end

function localDeleteSharedColorbar(ui)
    try, delete(findall(ancestor(ui.axS2tf, 'figure'), 'Type', 'ColorBar')); catch, end
end

function [sig, info] = localCropSignal(raw, fs, start_us, end_us)
    n = numel(raw);
    startIdx = max(1, floor(start_us * 1e-6 * fs) + 1);
    if isinf(end_us)
        endIdx = n;
    else
        endIdx = min(n, floor(end_us * 1e-6 * fs) + 1);
    end
    if endIdx < startIdx, endIdx = startIdx; end
    sig = raw(startIdx:endIdx);
    info = struct('startIdx', startIdx, 'endIdx', endIdx);
end

function kLocal = localShiftPick(kAbs, startIdx, endIdx)
    if ~isfinite(kAbs) || kAbs < startIdx || kAbs > endIdx
        kLocal = nan;
    else
        kLocal = kAbs - startIdx + 1;
    end
end

function fmax = localReadFmax(ui, defaultVal)
    fmax = str2double(get(ui.edFmax, 'String'));
    if ~isfinite(fmax) || fmax <= 0, fmax = defaultVal; end
end

function [start_us, end_us] = localReadWindow(ui, defaultWin)
    start_us = str2double(get(ui.edStartUs, 'String'));
    end_us = str2double(get(ui.edWinUs, 'String'));
    defStart = 0;
    defEnd = inf;
    if isfield(defaultWin, 'start_us') && isfinite(defaultWin.start_us)
        defStart = defaultWin.start_us;
    end
    if isfield(defaultWin, 'end_us') && isfinite(defaultWin.end_us)
        defEnd = defaultWin.end_us;
    elseif isfield(defaultWin, 'length_us') && isfinite(defaultWin.length_us)
        defEnd = defStart + defaultWin.length_us;
    end
    if ~isfinite(start_us) || start_us < 0, start_us = defStart; end
    if isempty(get(ui.edWinUs, 'String')) || strcmpi(strtrim(get(ui.edWinUs, 'String')), 'inf')
        end_us = inf;
    elseif ~isfinite(end_us) || end_us <= start_us
        end_us = defEnd;
    end
end

function tfMode = localReadTFMode(ui)
    v = get(ui.popTF, 'Value');
    strs = get(ui.popTF, 'String');
    if iscell(strs)
        tfMode = strs{v};
    else
        tfMode = strs;
    end
end

function shareCB = localReadSharedColorbar(ui, defaultVal)
    try
        shareCB = logical(get(ui.chkSharedCB, 'Value'));
    catch
        shareCB = defaultVal;
    end
end
