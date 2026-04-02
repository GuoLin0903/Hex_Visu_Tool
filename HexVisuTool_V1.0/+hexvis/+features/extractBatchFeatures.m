function T = extractBatchFeatures(D, A, cfg)
%EXTRACTBATCHFEATURES Compute per-event dual-channel features robustly.

    nEv = D.nEvents;
    fs = D.fs;
    ch1 = cfg.channels.S1;
    ch2 = cfg.channels.S2;
    rows = cell(nEv, 1);

    for ev = 1:nEv
        [k0, kEnd] = chooseWindow(ev, D, A, cfg.features);
        sig1 = double(D.wave(k0:kEnd, ch1, ev));
        sig2 = double(D.wave(k0:kEnd, ch2, ev));

        M = struct();
        M.eventID = ev;
        M.k0_samp = k0;
        M.kEnd_samp = kEnd;
        M.win_us = (kEnd - k0 + 1) / fs * 1e6;

        try
            F = hexvis.features.extractTwoChannelFeatures(sig1, sig2, fs, ev, safeEventTime(D, ev), ch1, ch2);
        catch ME
            warning('Feature extraction failed on event %d: %s', ev, ME.message);
            F = localNaNFeatureStruct();
        end

        rows{ev} = hexvis.utils.mergeStruct(M, F);
    end

    T = struct2table(vertcat(rows{:}));
end

function F = localNaNFeatureStruct()
    nms = hexvis.features.featureNames();
    F = struct();
    for p = ["S1_","S2_"]
        for i = 1:numel(nms)
            F.(char(p + nms{i})) = nan;
        end
    end
end

function [k0, kEnd] = chooseWindow(ev, D, A, cfgFeat)
    kEnd = D.nSamples;
    k0 = 1;

    mode = lower(char(cfgFeat.windowMode));
    switch mode
        case 'full_record'
            return;
        case 'aic_to_end'
            if isempty(A) || ~isfield(A, 'idx') || size(A.idx,1) < ev
                return;
            end
            idxPair = A.idx(ev,:);
            idxPair = idxPair(isfinite(idxPair));
            if ~isempty(idxPair)
                k0 = max(1, min(idxPair));
            end
    end
end

function t = safeEventTime(D, ev)
    if ~isempty(D.eventTime) && numel(D.eventTime) >= ev
        t = D.eventTime(ev);
    else
        t = nan;
    end
end
