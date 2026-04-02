function A = pickAllEvents(wave, fs, preTrigPoints, channels, geom, cfgAIC)
%PICKALLEVENTS Internal robust dual-channel AIC picker.
%
% This implementation intentionally avoids the external AE_Tools_V3 path.
% Pipeline per channel:
%   baseline removal -> short median filter -> smoothed envelope ->
%   first sustained crossing -> local AIC minimum -> backward low-threshold
%   refinement. Then the two channels are pair-refined under a physical dt
%   constraint.

    if nargin < 6 || isempty(cfgAIC)
        cfgAIC = hexvis.config.defaultConfig().aic;
    end

    nEv = size(wave, 3);
    A = struct();
    A.idx = nan(nEv, 2);
    A.t0_S1_us = nan(nEv, 1);
    A.t0_S2_us = nan(nEv, 1);
    A.dt_us = nan(nEv, 1);
    A.x_mm = nan(nEv, 1);
    A.valid = false(nEv, 1);
    A.source = repmat("robust_aic", nEv, 1);
    A.debug = cell(nEv, 2);

    if isempty(preTrigPoints) || ~isscalar(preTrigPoints) || ~isfinite(preTrigPoints)
        preTrigPoints = 0;
    end

    % -------- pick each channel independently first --------
    for ev = 1:nEv
        s1 = double(wave(:, channels.S1, ev));
        s2 = double(wave(:, channels.S2, ev));

        [k1, dbg1] = localPickOneRobust(s1, fs, preTrigPoints, cfgAIC);
        [k2, dbg2] = localPickOneRobust(s2, fs, preTrigPoints, cfgAIC);

        A.idx(ev,:) = [k1, k2];
        A.debug{ev,1} = dbg1;
        A.debug{ev,2} = dbg2;
    end

    % -------- dual-channel pair refinement --------
    if isfield(cfgAIC,'pair') && isfield(cfgAIC.pair,'enabled') && cfgAIC.pair.enabled
        A = localPairRefine(A, wave, fs, preTrigPoints, channels, geom, cfgAIC);
    end

    % -------- finalize dt / location --------
    A = localFinalize(A, fs, geom, cfgAIC);
end

function [idx, dbg] = localPickOneRobust(x, fs, preTrigPoints, C)
    x = double(x(:));
    x(~isfinite(x)) = 0;
    n = numel(x);
    idx = nan;
    dbg = struct('threshold', nan, 'lowThreshold', nan, 'preN', nan, ...
        'kCross', nan, 'kAIC', nan, 'kRefined', nan, 'noiseSigma', nan, ...
        'env', [], 'xf', []);

    if n < 12
        idx = 1;
        return;
    end

    preN = round(preTrigPoints);
    preN = max(8, min(preN, n-4));

    % baseline removal using pretrigger median
    x = x - median(x(1:preN), 'omitnan');

    % short median filter to suppress spike noise
    medN = max(1, round(C.medfilt_us * 1e-6 * fs));
    if mod(medN,2) == 0, medN = medN + 1; end
    if medN > 1 && exist('medfilt1','file') ~= 0
        xf = medfilt1(x, medN, 'truncate');
    else
        xf = x;
    end

    % smoothed envelope for stable trigger search
    env = abs(localHilbertSafe(xf));
    smoothN = max(1, round(C.smooth_us * 1e-6 * fs));
    if smoothN > 1
        env = movmean(env, smoothN);
    end

    noiseEnv = env(1:preN);
    noiseSigma = 1.4826 * mad(noiseEnv, 1);
    if ~isfinite(noiseSigma) || noiseSigma <= 0
        noiseSigma = std(noiseEnv, 0, 'omitnan');
    end
    if ~isfinite(noiseSigma) || noiseSigma <= 0
        noiseSigma = eps;
    end

    maxSearch = min(n, preN + max(5, round(C.maxSearch_us * 1e-6 * fs)));
    peakRef = max(prctile(env(preN+1:maxSearch), 99.5), max(env(preN+1:maxSearch)));
    highThr = max(C.noiseSigma * noiseSigma, C.relAmpFrac * peakRef);
    lowThr = max(C.refineLowFrac * highThr, 1.5 * noiseSigma);
    minRun = max(1, round(C.minRun_us * 1e-6 * fs));

    kCross = localFirstRun(env(preN+1:maxSearch) >= highThr, minRun);
    if isempty(kCross)
        [~, loc] = max(env(preN+1:maxSearch));
        kCross = loc;
    end
    kCross = preN + kCross;

    % local AIC window around first crossing
    k1 = max(preN + 1, kCross - round(C.preAICPad_us * 1e-6 * fs));
    k2 = min(n, kCross + round(C.postAICPad_us * 1e-6 * fs));
    seg = xf(k1:k2);
    aicCurve = localAIC(seg);
    [~, kMin] = min(aicCurve);
    kAIC = k1 + kMin - 1;

    % backward refinement: search for first sustained low-threshold crossing
    kBack1 = max(preN + 1, kAIC - round(C.preAICPad_us * 1e-6 * fs));
    kBack2 = min(kAIC, maxSearch);
    kRef = localFirstRun(env(kBack1:kBack2) >= lowThr, minRun);
    if isempty(kRef)
        idx = kAIC;
    else
        idx = kBack1 + kRef - 1;
    end

    idx = max(1, min(n, idx));

    dbg.threshold = highThr;
    dbg.lowThreshold = lowThr;
    dbg.preN = preN;
    dbg.kCross = kCross;
    dbg.kAIC = kAIC;
    dbg.kRefined = idx;
    dbg.noiseSigma = noiseSigma;
    dbg.env = env;
    dbg.xf = xf;
end

function A = localPairRefine(A, wave, fs, preTrigPoints, channels, geom, C)
    nEv = size(wave, 3);
    dtPhys_us = geom.L_mm / geom.v_ms * 1e3;
    dtMax_us = max(1e-6, C.pair.maxDtFactor * dtPhys_us);
    dtMax_samp = max(1, round(dtMax_us * 1e-6 * fs));

    for ev = 1:nEv
        s1 = double(wave(:, channels.S1, ev));
        s2 = double(wave(:, channels.S2, ev));
        dbg1 = A.debug{ev,1};
        dbg2 = A.debug{ev,2};
        c1 = localCandidatesFromDebug(dbg1, fs, C);
        c2 = localCandidatesFromDebug(dbg2, fs, C);
        if isempty(c1) || isempty(c2)
            continue;
        end
        [k1, k2, ok] = localBestPair(c1, c2, A.idx(ev,1), A.idx(ev,2), dtMax_samp, C.pair);
        if ok
            A.idx(ev,:) = [k1, k2];
        end
    end
end

function cands = localCandidatesFromDebug(dbg, fs, C)
    cands = [];
    if isempty(dbg) || ~isfield(dbg,'env') || isempty(dbg.env)
        return;
    end
    env = dbg.env(:);
    n = numel(env);
    preN = max(1, min(dbg.preN, n-2));
    searchEnd = min(n, preN + max(5, round(C.maxSearch_us * 1e-6 * fs)));
    minRun = max(1, round(C.minRun_us * 1e-6 * fs));
    mask = env(preN+1:searchEnd) >= dbg.lowThreshold;
    d = diff([false; mask(:); false]);
    i1 = find(d == 1);
    i2 = find(d == -1) - 1;
    len = i2 - i1 + 1;
    i1 = i1(len >= minRun);
    if isempty(i1)
        cands = dbg.kRefined;
        return;
    end
    cands = preN + i1;
    % keep a few earliest plus the current refined point
    cands = unique([cands(:); dbg.kRefined], 'stable');
    cands = cands(1:min(numel(cands), C.pair.maxCandidates));
end

function [best1, best2, ok] = localBestPair(c1, c2, init1, init2, dtMax_samp, P)
    best1 = nan; best2 = nan; ok = false;
    bestScore = inf;

    if isfinite(init1) && isfinite(init2)
        initDt = init2 - init1;
    else
        initDt = 0;
    end

    for i = 1:numel(c1)
        for j = 1:numel(c2)
            dt = c2(j) - c1(i);
            if abs(dt) > dtMax_samp
                continue;
            end
            score = P.penaltyLate * (c1(i) + c2(j)) + P.penaltyDt * abs(dt);
            if isfinite(init1) && isfinite(init2)
                score = score + 0.35 * abs(dt - initDt) + 0.15 * abs(c1(i)-init1) + 0.15 * abs(c2(j)-init2);
            end
            if score < bestScore
                bestScore = score;
                best1 = c1(i);
                best2 = c2(j);
                ok = true;
            end
        end
    end

    if ~ok && isfinite(init1) && isfinite(init2)
        best1 = init1;
        best2 = init2;
        ok = true;
    end
end

function A = localFinalize(A, fs, geom, C)
    nEv = size(A.idx,1);
    dtPhys_us = geom.L_mm / geom.v_ms * 1e3;
    if isfield(C,'pair') && isfield(C.pair,'maxDtFactor')
        dtFactor = C.pair.maxDtFactor;
    else
        dtFactor = 2.0;
    end
    for ev = 1:nEv
        k1 = A.idx(ev,1);
        k2 = A.idx(ev,2);
        if isfinite(k1), A.t0_S1_us(ev) = (k1 - 1) / fs * 1e6; end
        if isfinite(k2), A.t0_S2_us(ev) = (k2 - 1) / fs * 1e6; end
        if isfinite(k1) && isfinite(k2)
            A.dt_us(ev) = A.t0_S2_us(ev) - A.t0_S1_us(ev);
            A.x_mm(ev) = (geom.L_mm - geom.v_ms * A.dt_us(ev) * 1e-3) / 2;
            A.valid(ev) = isfinite(A.x_mm(ev)) && abs(A.dt_us(ev)) <= dtFactor * dtPhys_us;
        end
    end
end

function y = localHilbertSafe(x)
    if exist('hilbert','file') ~= 0 || exist('hilbert','builtin') ~= 0
        y = hilbert(x);
    else
        y = x;
    end
end

function k = localFirstRun(mask, runLength)
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
    if n < 6
        return;
    end
    for k = 2:n-2
        v1 = var(seg(1:k), 1);
        v2 = var(seg(k+1:end), 1);
        if v1 <= 0, v1 = eps; end
        if v2 <= 0, v2 = eps; end
        aicVal(k) = k * log(v1) + (n-k-1) * log(v2);
    end
end
