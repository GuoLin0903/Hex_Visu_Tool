function S = extractTwoChannelFeatures(sig1, sig2, fs, eventID, eventTime, ch1, ch2)
%EXTRACTTWOCHANNELFEATURES Robust internal feature extraction for two channels.
% This phase keeps the feature logic close to ExtractFeati_OPT, but removes
% dependency on external function signatures so the UI stays stable.

    names = hexvis.features.featureNames();
    S = struct();
    S = hexvis.utils.mergeStruct(S, localOne(sig1, fs, eventID, eventTime, ch1, 'S1_', names));
    S = hexvis.utils.mergeStruct(S, localOne(sig2, fs, eventID, eventTime, ch2, 'S2_', names));
end

function S = localOne(sig, fs, eventID, eventTime, ch, prefix, names)
    sig = double(sig(:));
    sig(~isfinite(sig)) = 0;
    Nt = numel(sig);
    T2 = (0:Nt-1)' / fs;
    heads_info = {fs, ch, eventID, eventTime};
    vec = localExtractFeatiCompat(T2, sig, [], heads_info, names);

    S = struct();
    vec = vec(:).';
    for i = 1:numel(names)
        if i <= numel(vec)
            v = vec(i);
            if isempty(v) || ~isscalar(v) || ~isfinite(v)
                if isempty(v) || ~isscalar(v)
                    v = nan;
                end
            end
            S.([prefix names{i}]) = v;
        else
            S.([prefix names{i}]) = nan;
        end
    end
end

function Feat = localExtractFeatiCompat(T2, V2, E2, heads_info, names)
%LOCAL EXTRACT Robust scalar-only compatibility implementation.

    fs = double(heads_info{1,1});
    channel = double(heads_info{1,2});
    hit = double(heads_info{1,3});
    hittime = double(heads_info{1,4});

    V2 = double(V2(:));
    T2 = double(T2(:));
    LV2 = numel(V2);
    nOut = numel(names);
    Feat = nan(nOut,1);

    Feat(1:min(3,nOut)) = [hit; hittime; channel];
    if LV2 < 8 || numel(T2) ~= LV2 || fs <= 0
        return;
    end

    fMAX = 1e6;
    intf = 1e3 * [0 100 250 500 1000]';
    roll_off_factor = 0.95;
    roll_on_factor  = 0.05;

    % ---------- time features ----------
    [Araw, bAmp] = max(abs(V2));
    Araw = localScalar(Araw);
    bAmp = min(max(localScalar(bAmp,1),1),LV2);
    D = T2(end);

    if ~isempty(E2)
        idx = min(max(LV2,1), numel(E2));
        E = localScalar(E2(idx));
    else
        E = sum(V2.^2, 'omitnan');
    end

    c = (V2(1:LV2-1) <= 0) & (V2(2:LV2) > 0);
    ZC = sum(c);
    ZCR = 100 * ZC / LV2;
    RT = T2(bAmp);

    V2_RMS = abs(V2) / sqrt(LV2);
    denomTC = sum(V2_RMS);
    if denomTC > eps
        TC = sum(T2 .* V2_RMS) / denomTC;
    else
        TC = nan;
    end

    [~, bRMS] = max(V2_RMS);
    if bRMS < LV2 - 1
        xFit = T2(bRMS+1:end);
        yFit = V2_RMS(bRMS+1:end);
        if numel(xFit) >= 2 && all(isfinite(xFit(:))) && all(isfinite(yFit(:)))
            try
                p = polyfit(xFit, yFit, 1);
                alpha = -localScalar(p(1));
            catch
                alpha = nan;
            end
        else
            alpha = nan;
        end
    else
        alpha = nan;
    end

    % ---------- spectral features ----------
    NFFT = 2^nextpow2(LV2);
    Yc = fft(V2, NFFT) / LV2;
    f = fs/2 * linspace(0, 1, NFFT/2 + 1);
    Yabs = abs(Yc(1:NFFT/2+1)).';
    FcFull = f(:);

    idxUse = (FcFull > 0) & (FcFull <= fMAX);
    Fc = FcFull(idxUse);
    Y = Yabs(idxUse);
    Y = Y(:);
    Fc = Fc(:);

    PP2 = nan(4,1);
    FC2 = nan; PF2 = nan; SSpread = nan; SSkew = nan; SKurt = nan;
    SSlope = nan; SRoff = nan; SSpreadP = nan; SSkewP = nan; SKurtP = nan; SRon = nan;

    if ~isempty(Fc) && ~isempty(Y) && any(isfinite(Y)) && any(Y > 0)
        Ptot = sum(Y, 'omitnan');
        if Ptot > eps
            for i = 1:length(intf)-1
                PP2(i) = 100 * sum(Y(Fc >= intf(i) & Fc < intf(i+1)), 'omitnan') / Ptot;
            end
            FC2 = sum(Fc .* Y, 'omitnan') / Ptot;
            PF2 = localPeakFreq(Fc, Y);
            SSpread = sqrt(max(sum(((Fc-FC2).^2).*Y, 'omitnan') / Ptot, 0));
            if isfinite(SSpread) && isscalar(SSpread) && SSpread > eps
                SSkew = sum(((Fc-FC2).^3).*Y, 'omitnan') / Ptot / (SSpread^3);
                SKurt = sum(((Fc-FC2).^4).*Y, 'omitnan') / Ptot / (SSpread^4);
            end
            yNorm = Y / max(Y);
            if numel(Fc) >= 2 && all(isfinite(yNorm(:)))
                try
                    p = polyfit(Fc/fMAX, yNorm, 1);
                    SSlope = localScalar(p(1));
                catch
                    SSlope = nan;
                end
            end
            cum_energy = cumsum(Y);
            indroff = find(cum_energy < roll_off_factor * max(cum_energy), 1, 'last');
            if isempty(indroff), indroff = numel(Fc); end
            SRoff = localScalar(Fc(indroff));
            SSpreadP = sqrt(max(sum(((Fc-PF2).^2).*Y, 'omitnan') / Ptot, 0));
            if isfinite(SSpreadP) && isscalar(SSpreadP) && SSpreadP > eps
                SSkewP = sum(((Fc-PF2).^3).*Y, 'omitnan') / Ptot / (SSpreadP^3);
                SKurtP = sum(((Fc-PF2).^4).*Y, 'omitnan') / Ptot / (SSpreadP^4);
            end
            indron = find(cum_energy < roll_on_factor * max(cum_energy), 1, 'last');
            if isempty(indron), indron = 1; end
            SRon = localScalar(Fc(indron));
        end
    end

    % ---------- unit conversion ----------
    A = 20 * log10(max(Araw, eps) * 1e6) - 42;
    D  = D * 1e6;
    RT = RT * 1e6;
    TC = TC * 1e6;
    FC2 = FC2 / 1000;
    PF2 = PF2 / 1000;
    SRoff = SRoff / 1000;
    SRon = SRon / 1000;
    SSpread = SSpread / 1000;
    SSpreadP = SSpreadP / 1000;

    % ---------- wavelet packet features ----------
    Ewp = nan(8,1);
    try
        if exist('wpdec', 'file') ~= 0 && exist('wenergy', 'file') ~= 0
            Twp = wpdec(V2, 3, 'sym8', 'shannon');
            Ewp0 = wenergy(Twp);
            Ewp0 = Ewp0(:);
            m = min(8, numel(Ewp0));
            Ewp(1:m) = Ewp0(1:m);
        end
    catch
        Ewp(:) = nan;
    end

    % ---------- entropy ----------
    Entropy = nan;
    try
        N = histcounts(abs(V2), 100);
        L = N(N ~= 0);
        if ~isempty(L)
            L = L / max(LV2, 1);
            Entropy = -sum(L .* log2(L), 'omitnan');
        end
    catch
        Entropy = nan;
    end

    core = [hit; hittime; channel; A; D; E; ZCR; RT; TC; alpha; ...
            PP2(:); FC2; PF2; SSpread; SSkew; SKurt; SSlope; SRoff; ...
            sqrt(SSpreadP); SSkewP; SKurtP; SRon; Ewp(:); Entropy];
    core = arrayfun(@(x) localScalar(x), core(:));

    n = min(numel(core), nOut);
    Feat(1:n) = core(1:n);
end

function pf = localPeakFreq(Fc, Y)
    pf = nan;
    if isempty(Fc) || isempty(Y)
        return;
    end
    [~, idx] = max(Y(:));
    if isempty(idx) || ~isfinite(idx)
        return;
    end
    pf = localScalar(Fc(idx));
end

function x = localScalar(x, defaultValue)
    if nargin < 2
        defaultValue = nan;
    end
    if isempty(x) || ~isnumeric(x)
        x = defaultValue;
        return;
    end
    x = x(1);
    if isempty(x) || ~isfinite(x)
        x = defaultValue;
    end
end
