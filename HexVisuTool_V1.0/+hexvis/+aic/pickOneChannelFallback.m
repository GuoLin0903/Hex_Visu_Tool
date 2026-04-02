function [idx, t_us, dbg] = pickOneChannelFallback(x, fs, preTrigPoints, C)
%PICKONECHANNELFALLBACK Minimal robust fallback picker.
%
% This is not intended to replace your final AIC research version.
% It exists so that the modular app still runs even when AE_Tools_V3 is
% absent or temporarily broken.

    x = double(x(:));
    n = numel(x);
    idx = nan;
    t_us = nan;
    dbg = struct();

    if n < 8 || all(~isfinite(x))
        return;
    end

    x(~isfinite(x)) = 0;
    x = x - median(x, 'omitnan');

    preN = round(preTrigPoints);
    preN = max(1, min(preN, n-2));
    noise = x(1:preN);
    noiseStd = std(noise);
    absx = abs(x);

    minRun = max(1, round(C.minRun_us * 1e-6 * fs));
    maxSearch = max(preN + 2, min(n, preN + round(C.maxSearch_us * 1e-6 * fs)));

    thr = max(C.noiseSigma * noiseStd, C.relAmpFrac * max(absx));

    mask = absx(preN+1:maxSearch) >= thr;
    kCand = findFirstRun(mask, minRun);
    if isempty(kCand)
        [~, loc] = max(absx(preN+1:maxSearch));
        kCross = preN + loc;
    else
        kCross = preN + kCand;
    end

    k1 = max(preN + 1, kCross - round(C.preAICPad_us * 1e-6 * fs));
    k2 = min(n, kCross + round(C.postAICPad_us * 1e-6 * fs));

    seg = x(k1:k2);
    if numel(seg) >= 6
        aicCurve = localAIC(seg);
        [~, kMin] = min(aicCurve);
        idx = k1 + kMin - 1;
    else
        idx = kCross;
        aicCurve = [];
    end

    idx = max(1, min(n, idx));
    t_us = (idx - 1) / fs * 1e6;

    dbg.threshold = thr;
    dbg.noiseStd = noiseStd;
    dbg.kCross = kCross;
    dbg.aicCurve = aicCurve;
end

function k = findFirstRun(mask, runLength)
    k = [];
    if isempty(mask)
        return;
    end
    d = diff([false; mask(:); false]);
    i1 = find(d == 1);
    i2 = find(d == -1) - 1;
    len = i2 - i1 + 1;
    hit = find(len >= runLength, 1, 'first');
    if ~isempty(hit)
        k = i1(hit);
    end
end

function aicVal = localAIC(seg)
    seg = double(seg(:));
    n = numel(seg);
    aicVal = inf(n,1);
    for k = 2:n-2
        v1 = var(seg(1:k), 1);
        v2 = var(seg(k+1:end), 1);
        if v1 <= 0, v1 = eps; end
        if v2 <= 0, v2 = eps; end
        aicVal(k) = k * log(v1) + (n-k-1) * log(v2);
    end
end
