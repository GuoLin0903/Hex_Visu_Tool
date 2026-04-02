function fig = launchApp(cfg)
%LAUNCHAPP Create app state, wire callbacks, and start the UI.

    dep = hexvis.utils.assertDeps(cfg);
    ui = hexvis.ui.buildMainUI(cfg);

    app = struct();
    app.cfg = cfg;
    app.dep = dep;
    app.ui = ui;
    app.D = [];
    app.A = [];
    app.T = table();
    app.E = table();
    app.currentEvent = 1;

    guidata(ui.fig, app);

    set(ui.txtStatus, 'String', joinStatus(dep.messages));

    set(ui.btnLoad, 'Callback', @onLoad);
    set(ui.btnAIC, 'Callback', @onRunAIC);
    set(ui.btnFeat, 'Callback', @onRunFeatures);
    set(ui.btnSettings, 'Callback', @onOpenSettings);
    set(ui.btnPrev, 'Callback', @onPrev);
    set(ui.btnNext, 'Callback', @onNext);
    set(ui.tbl, 'CellSelectionCallback', @onTableSelect);
    set(ui.popTF, 'Callback', @onRefreshOnly);
    set(ui.edFmax, 'Callback', @onRefreshOnly);
    set(ui.edStartUs, 'Callback', @onRefreshOnly);
    set(ui.edWinUs, 'Callback', @onRefreshOnly);
    set(ui.chkSharedCB, 'Callback', @onRefreshOnly);

    app = hexvis.ui.refreshUI(app);
    guidata(ui.fig, app);
    fig = ui.fig;

    function onLoad(~, ~)
        app = guidata(ui.fig);
        [f, p] = uigetfile(cfg.io.acceptedExt, 'Select a .wave file');
        if isequal(f, 0), return; end

        fileName = fullfile(p, f);
        set(ui.txtStatus, 'String', sprintf('Loading file...\n%s', fileName));
        drawnow;

        try
            D = hexvis.io.readWaveFile(fileName, cfg.io);
            validateChannels(D, app.cfg.channels);
            E = hexvis.io.buildEventTable(D);
        catch ME
            errordlg(sprintf('Failed to load file:\n%s', ME.message), 'Load Error');
            return;
        end

        app.D = D;
        app.E = E;
        app.A = [];
        app.T = table();
        app.currentEvent = 1;

        set(ui.txtStatus, 'String', sprintf('File loaded successfully.\nEvents = %d', D.nEvents));
        app = hexvis.ui.refreshUI(app);
        guidata(ui.fig, app);
    end

    function onRunAIC(~, ~)
        app = guidata(ui.fig);
        if isempty(app.D)
            errordlg('Please load a .wave file first.', 'No Data');
            return;
        end

        set(ui.txtStatus, 'String', 'Running internal robust AIC ...');
        drawnow;

        try
            validateChannels(app.D, app.cfg.channels);
            A = hexvis.aic.pickAllEvents(app.D.wave, app.D.fs, app.D.preTrigPoints, app.cfg.channels, app.cfg.geom, app.cfg.aic);
        catch ME
            errordlg(sprintf('AIC failed:\n%s', ME.message), 'AIC Error');
            return;
        end

        app.A = A;
        app.E = mergeAICIntoEvents(app.E, A);
        set(ui.txtStatus, 'String', localAICStatus(A));

        app = hexvis.ui.refreshUI(app);
        guidata(ui.fig, app);
    end

    function onRunFeatures(~, ~)
        app = guidata(ui.fig);
        if isempty(app.D)
            errordlg('Please load a .wave file first.', 'No Data');
            return;
        end

        set(ui.txtStatus, 'String', 'Computing features ...');
        drawnow;

        try
            validateChannels(app.D, app.cfg.channels);
            T = hexvis.features.extractBatchFeatures(app.D, app.A, app.cfg);
            app.T = T;
            app.E = mergeFeaturesIntoEvents(app.E, T);
        catch ME
            errordlg(sprintf('Feature extraction failed:\n%s', ME.message), 'Feature Error');
            return;
        end

        set(ui.txtStatus, 'String', sprintf('Features done on %d events.', height(app.T)));
        app = hexvis.ui.refreshUI(app);
        guidata(ui.fig, app);
    end

    function onOpenSettings(~, ~)
        app = guidata(ui.fig);
        newCfg = openSettingsDialog(app.cfg, app.D, ui.fig);
        if isempty(newCfg)
            return;
        end
        app.cfg = newCfg;
        if ~isempty(app.D)
            app.E = hexvis.io.buildEventTable(app.D);
        else
            app.E = table();
        end
        app.A = [];
        app.T = table();
        app.currentEvent = 1;
        set(ui.txtStatus, 'String', sprintf(['Settings updated.\n' ...
            'S1=%d, S2=%d, L=%.1f mm, v=%.1f m/s\n' ...
            'Internal robust AIC parameters updated. Re-run AIC / Features.'], ...
            app.cfg.channels.S1, app.cfg.channels.S2, app.cfg.geom.L_mm, app.cfg.geom.v_ms));
        app = hexvis.ui.refreshUI(app);
        guidata(ui.fig, app);
    end

    function onRefreshOnly(~, ~)
        app = guidata(ui.fig);
        app = hexvis.ui.refreshUI(app);
        guidata(ui.fig, app);
    end

    function onPrev(~, ~)
        app = guidata(ui.fig);
        if isempty(app.E), return; end
        app.currentEvent = max(1, app.currentEvent - 1);
        app = hexvis.ui.refreshUI(app);
        guidata(ui.fig, app);
    end

    function onNext(~, ~)
        app = guidata(ui.fig);
        if isempty(app.E), return; end
        app.currentEvent = min(height(app.E), app.currentEvent + 1);
        app = hexvis.ui.refreshUI(app);
        guidata(ui.fig, app);
    end

    function onTableSelect(~, evt)
        if isempty(evt.Indices), return; end
        row = evt.Indices(1);
        app = guidata(ui.fig);
        if ~isempty(app.E)
            app.currentEvent = max(1, min(row, height(app.E)));
            app = hexvis.ui.refreshUI(app);
            guidata(ui.fig, app);
        end
    end
end

function newCfg = openSettingsDialog(cfg, D, parentFig)
    newCfg = [];

    dlg = dialog('Name', 'HEXVIS Settings', 'Units', 'pixels', ...
        'Position', [120 60 980 700], 'WindowStyle', 'modal', ...
        'Color', [1 1 1], 'Resize', 'on');

    fs = 10;
    fsSmall = 8.5;

    ui.txtGeneral = uicontrol(dlg, 'Style', 'text', 'String', 'General', 'FontWeight', 'bold', ...
        'BackgroundColor', [1 1 1], 'HorizontalAlignment', 'left', 'Units', 'pixels');
    ui.panG = uipanel('Parent', dlg, 'Units', 'pixels', 'BackgroundColor', [1 1 1]);

    ui.lblS1 = mkLabel(ui.panG, 'S1 channel:', [0 0 1 1], fs);
    ui.edS1 = mkEdit(ui.panG, num2str(cfg.channels.S1), [0 0 1 1], fs);
    ui.lblS2 = mkLabel(ui.panG, 'S2 channel:', [0 0 1 1], fs);
    ui.edS2 = mkEdit(ui.panG, num2str(cfg.channels.S2), [0 0 1 1], fs);
    ui.lblL = mkLabel(ui.panG, 'Distance L (mm):', [0 0 1 1], fs);
    ui.edL = mkEdit(ui.panG, num2str(cfg.geom.L_mm), [0 0 1 1], fs);
    ui.lblV = mkLabel(ui.panG, 'Velocity v (m/s):', [0 0 1 1], fs);
    ui.edV = mkEdit(ui.panG, num2str(cfg.geom.v_ms), [0 0 1 1], fs);

    hint = 'Changes here reset previous AIC/features. Channel numbers must exist in the loaded .wave file.';
    if isempty(D)
        hint = 'Changes here reset previous AIC/features. Load a .wave file later to validate channels.';
    end
    ui.txtHint = uicontrol(ui.panG, 'Style', 'text', 'String', hint, 'FontSize', fsSmall, ...
        'BackgroundColor', [1 1 1], 'HorizontalAlignment', 'left', 'Units', 'pixels');

    ui.txtAIC = uicontrol(dlg, 'Style', 'text', 'String', 'Internal robust AIC', 'FontWeight', 'bold', ...
        'BackgroundColor', [1 1 1], 'HorizontalAlignment', 'left', 'Units', 'pixels');
    ui.panA = uipanel('Parent', dlg, 'Units', 'pixels', 'BackgroundColor', [1 1 1]);

    ui.txtFlow = uicontrol(ui.panA, 'Style', 'text', 'String', ...
        'Flow: median filter -> smoothed envelope -> sustained threshold -> local AIC -> backward refinement -> pair refinement', ...
        'FontSize', fsSmall, 'BackgroundColor', [1 1 1], 'HorizontalAlignment', 'left', 'Units', 'pixels');

    ui.lblNoiseSigma = mkLabel(ui.panA, 'noise sigma:', [0 0 1 1], fs);
    ui.edNoiseSigma = mkEdit(ui.panA, num2str(cfg.aic.noiseSigma), [0 0 1 1], fs);
    ui.lblRelAmp = mkLabel(ui.panA, 'rel amp frac:', [0 0 1 1], fs);
    ui.edRelAmp = mkEdit(ui.panA, num2str(cfg.aic.relAmpFrac), [0 0 1 1], fs);
    ui.lblSmooth = mkLabel(ui.panA, 'smooth (us):', [0 0 1 1], fs);
    ui.edSmooth = mkEdit(ui.panA, num2str(cfg.aic.smooth_us), [0 0 1 1], fs);
    ui.lblMinRun = mkLabel(ui.panA, 'min run (us):', [0 0 1 1], fs);
    ui.edMinRun = mkEdit(ui.panA, num2str(cfg.aic.minRun_us), [0 0 1 1], fs);
    ui.lblPrePad = mkLabel(ui.panA, 'pre AIC pad (us):', [0 0 1 1], fs);
    ui.edPrePad = mkEdit(ui.panA, num2str(cfg.aic.preAICPad_us), [0 0 1 1], fs);
    ui.lblPostPad = mkLabel(ui.panA, 'post AIC pad (us):', [0 0 1 1], fs);
    ui.edPostPad = mkEdit(ui.panA, num2str(cfg.aic.postAICPad_us), [0 0 1 1], fs);
    ui.lblMaxSearch = mkLabel(ui.panA, 'max search (us):', [0 0 1 1], fs);
    ui.edMaxSearch = mkEdit(ui.panA, num2str(cfg.aic.maxSearch_us), [0 0 1 1], fs);
    ui.lblPairMaxDt = mkLabel(ui.panA, 'pair max dt factor:', [0 0 1 1], fs);
    ui.edPairMaxDt = mkEdit(ui.panA, num2str(cfg.aic.pair.maxDtFactor), [0 0 1 1], fs);
    ui.lblPairMaxCand = mkLabel(ui.panA, 'pair max candidates:', [0 0 1 1], fs);
    ui.edPairMaxCand = mkEdit(ui.panA, num2str(cfg.aic.pair.maxCandidates), [0 0 1 1], fs);
    ui.chkPair = uicontrol(ui.panA, 'Style', 'checkbox', 'String', 'enable pair refinement', ...
        'Value', double(cfg.aic.pair.enabled), 'FontSize', fs, ...
        'BackgroundColor', [1 1 1], 'Units', 'pixels');

    ui.btnApply = uicontrol(dlg, 'Style', 'pushbutton', 'String', 'Apply', 'FontWeight', 'bold', ...
        'Units', 'pixels', 'Callback', @onApply);
    ui.btnCancel = uicontrol(dlg, 'Style', 'pushbutton', 'String', 'Cancel', ...
        'Units', 'pixels', 'Callback', @(~,~) delete(dlg));

    set(ui.edNoiseSigma, 'TooltipString', 'Noise multiplier for the main onset threshold. Larger value is more conservative.');
    set(ui.edRelAmp, 'TooltipString', 'Extra threshold tied to signal peak level. Prevents overly early picks on tiny fluctuations.');
    set(ui.edSmooth, 'TooltipString', 'Envelope smoothing window in microseconds.');
    set(ui.edMinRun, 'TooltipString', 'Minimum consecutive above-threshold duration to confirm an onset.');
    set(ui.edPrePad, 'TooltipString', 'How far before the first crossing the local AIC window starts.');
    set(ui.edPostPad, 'TooltipString', 'How far after the first crossing the local AIC window ends.');
    set(ui.edMaxSearch, 'TooltipString', 'Maximum search span after the pretrigger zone.');
    set(ui.edPairMaxDt, 'TooltipString', 'Allowed dt multiple relative to the physical L/v limit during pair refinement.');
    set(ui.edPairMaxCand, 'TooltipString', 'How many candidate onsets per channel are retained for pair matching.');
    set(ui.chkPair, 'TooltipString', 'Refine both channels jointly so dt remains physically plausible.');

    set(dlg, 'ResizeFcn', @(~,~) applySettingsLayout());
    applySettingsLayout();
    uiwait(dlg);

    function applySettingsLayout()
        if ~ishghandle(dlg), return; end
        p = get(dlg, 'Position');
        w = max(p(3), 920);
        h = max(p(4), 640);
        if p(3) ~= w || p(4) ~= h
            set(dlg, 'Position', [p(1:2), w, h]);
            p = get(dlg, 'Position');
            w = p(3); h = p(4);
        end

        m = 16; g = 12;
        headerH = 20;
        btnH = 32;
        gH = 138;
        aicH = h - 3*m - gH - headerH - 52 - btnH;
        if aicH < 300
            aicH = 300;
        end
        set(ui.txtGeneral, 'Position', [m, h - m - headerH, 240, headerH]);
        set(ui.panG, 'Position', [m, h - m - headerH - gH - 6, w - 2*m, gH]);
        set(ui.txtAIC, 'Position', [m, h - m - headerH - gH - 6 - 34, 240, headerH]);
        set(ui.panA, 'Position', [m, 58 + btnH, w - 2*m, aicH]);
        set(ui.btnApply, 'Position', [w - m - 220, 18, 100, btnH]);
        set(ui.btnCancel, 'Position', [w - m - 110, 18, 100, btnH]);

        % General panel: 2 rows
        pg = get(ui.panG, 'Position'); pw = pg(3); ph = pg(4);
        left = 18; topPad = 26; rowH = 26; lblW = 118; editW = 84; colGap = 22;
        y1 = ph - topPad - rowH;
        y2 = y1 - 14 - rowH;
        x1 = left;
        x2 = left + 250;
        set(ui.lblS1, 'Position', [x1, y1+3, lblW, rowH]);
        set(ui.edS1, 'Position', [x1+lblW+8, y1, editW, rowH]);
        set(ui.lblS2, 'Position', [x2, y1+3, lblW, rowH]);
        set(ui.edS2, 'Position', [x2+lblW+8, y1, editW, rowH]);
        set(ui.lblL, 'Position', [x1, y2+3, lblW, rowH]);
        set(ui.edL, 'Position', [x1+lblW+8, y2, editW+12, rowH]);
        set(ui.lblV, 'Position', [x2, y2+3, lblW+8, rowH]);
        set(ui.edV, 'Position', [x2+lblW+16, y2, editW+12, rowH]);
        set(ui.txtHint, 'Position', [left, 10, pw - 2*left, 18]);

        % AIC panel: flow + 3x3 grid + checkbox
        pa = get(ui.panA, 'Position'); pw = pa(3); ph = pa(4);
        left = 18; right = 18; topPad = 18; flowH = 18; rowH = 26; rowGap = 16;
        yFlow = ph - topPad - flowH;
        set(ui.txtFlow, 'Position', [left, yFlow, pw - left - right, flowH]);
        cols = 3;
        colW = floor((pw - left - right - 2*colGap) / cols);
        lblW = round(colW * 0.56);
        editW = colW - lblW - 8;
        y = yFlow - 28;
        % row 1
        placePair(1, ui.lblNoiseSigma, ui.edNoiseSigma);
        placePair(2, ui.lblRelAmp, ui.edRelAmp);
        placePair(3, ui.lblSmooth, ui.edSmooth);
        y = y - rowH - rowGap;
        % row 2
        placePair(1, ui.lblMinRun, ui.edMinRun);
        placePair(2, ui.lblPrePad, ui.edPrePad);
        placePair(3, ui.lblPostPad, ui.edPostPad);
        y = y - rowH - rowGap;
        % row 3
        placePair(1, ui.lblMaxSearch, ui.edMaxSearch);
        placePair(2, ui.lblPairMaxDt, ui.edPairMaxDt);
        placePair(3, ui.lblPairMaxCand, ui.edPairMaxCand);
        set(ui.chkPair, 'Position', [left, 18, 220, rowH]);

        function placePair(col, hLbl, hEd)
            x = left + (col-1) * (colW + colGap);
            set(hLbl, 'Position', [x, y+3, lblW, rowH]);
            set(hEd,  'Position', [x+lblW+8, y, editW, rowH]);
        end
    end

    function onApply(~,~)
        try
            tmp = cfg;
            tmp.channels.S1 = readPosInt(ui.edS1, 'S1 channel');
            tmp.channels.S2 = readPosInt(ui.edS2, 'S2 channel');
            tmp.geom.L_mm = readPosNum(ui.edL, 'Distance L');
            tmp.geom.v_ms = readPosNum(ui.edV, 'Velocity v');

            tmp.aic.noiseSigma = readPosNum(ui.edNoiseSigma, 'noise sigma');
            tmp.aic.relAmpFrac = readNonNegNum(ui.edRelAmp, 'rel amp frac');
            tmp.aic.smooth_us = readNonNegNum(ui.edSmooth, 'smooth (us)');
            tmp.aic.minRun_us = readPosNum(ui.edMinRun, 'min run (us)');
            tmp.aic.preAICPad_us = readPosNum(ui.edPrePad, 'pre AIC pad (us)');
            tmp.aic.postAICPad_us = readPosNum(ui.edPostPad, 'post AIC pad (us)');
            tmp.aic.maxSearch_us = readPosNum(ui.edMaxSearch, 'max search (us)');
            tmp.aic.pair.enabled = logical(get(ui.chkPair, 'Value'));
            tmp.aic.pair.maxDtFactor = readPosNum(ui.edPairMaxDt, 'pair max dt factor');
            tmp.aic.pair.maxCandidates = readPosInt(ui.edPairMaxCand, 'pair max candidates');

            if ~isempty(D)
                validateChannels(D, tmp.channels);
            end
            if tmp.channels.S1 == tmp.channels.S2
                error('S1 and S2 must be different channels.');
            end
            newCfg = tmp;
            delete(dlg);
        catch ME
            errordlg(ME.message, 'Settings Error', 'modal');
        end
    end

    if isvalid(dlg)
        % closed with X or Cancel
    end
    try, delete(dlg); catch, end
    if ~isempty(parentFig) && ishghandle(parentFig), figure(parentFig); end
end
function validateChannels(D, channels)
    if isempty(D), return; end
    nCh = D.numCh;
    if channels.S1 < 1 || channels.S1 > nCh || channels.S2 < 1 || channels.S2 > nCh
        error('Selected channels exceed the .wave file channel count (%d).', nCh);
    end
end

function h = mkLabel(parent, str, pos, fs)
    h = uicontrol(parent, 'Style', 'text', 'String', str, 'FontSize', fs, ...
        'BackgroundColor', [1 1 1], 'HorizontalAlignment', 'left', ...
        'Units', 'pixels', 'Position', pos);
end

function h = mkEdit(parent, str, pos, fs)
    h = uicontrol(parent, 'Style', 'edit', 'String', str, 'FontSize', fs, ...
        'BackgroundColor', [1 1 1], 'Units', 'pixels', 'Position', pos);
end

function v = readPosInt(h, name)
    v = round(str2double(get(h, 'String')));
    if ~isfinite(v) || v < 1
        error('%s must be a positive integer.', name);
    end
end

function v = readPosNum(h, name)
    v = str2double(get(h, 'String'));
    if ~isfinite(v) || v <= 0
        error('%s must be > 0.', name);
    end
end

function v = readNonNegNum(h, name)
    v = str2double(get(h, 'String'));
    if ~isfinite(v) || v < 0
        error('%s must be >= 0.', name);
    end
end

function E = mergeAICIntoEvents(E, A)
    if isempty(E), return; end
    E.t0_S1_us = A.t0_S1_us;
    E.t0_S2_us = A.t0_S2_us;
    E.dt_us = A.dt_us;
    E.x_mm = A.x_mm;
    E.loc_valid = A.valid;
    if isfield(A, 'idx')
        E.k0_samp = localRowMinFinite(A.idx);
        bad = ~isfinite(E.k0_samp);
        E.k0_samp(bad) = 1;
    end
end

function v = localRowMinFinite(M)
    v = nan(size(M,1),1);
    for ii = 1:size(M,1)
        row = M(ii,:);
        row = row(isfinite(row));
        if ~isempty(row), v(ii) = min(row); end
    end
end

function E = mergeFeaturesIntoEvents(E, T)
    if isempty(E) || isempty(T), return; end
    [lia, loc] = ismember(T.eventID, E.eventID);
    vars = T.Properties.VariableNames;
    skip = {'eventID'};
    for i = 1:numel(vars)
        v = vars{i};
        if any(strcmp(v, skip)), continue; end
        dest = v;
        if endsWith(dest, 'FC2_kHz')
            dest = strrep(dest, 'FC2', 'FC');
        elseif endsWith(dest, 'PF2_kHz')
            dest = strrep(dest, 'PF2', 'PF');
        end
        if ~ismember(dest, E.Properties.VariableNames)
            E.(dest) = nan(height(E),1);
        end
        tmp = E.(dest);
        src = T.(v);
        if ~isvector(src), src = src(:,1); end
        tmp(loc(lia)) = src(lia);
        E.(dest) = tmp;
    end
end

function msg = joinStatus(messages)
    if isempty(messages)
        msg = 'Ready.';
    else
        msg = strjoin(messages, newline);
    end
end

function msg = localAICStatus(A)
    n = numel(A.valid);
    nValid = sum(A.valid);
    msg = sprintf('Internal robust AIC done.\nValid events: %d / %d\nSource: robust_aic', nValid, n);
end
