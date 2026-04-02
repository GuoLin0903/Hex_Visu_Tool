function M = computeCWTMap(sig, fs, C)
%COMPUTECWTMAP Build the CWT map with the same display logic family used in
% Matlab-MAE-CWT-DC plot_dual_view_AGU_curve, but without dispersion overlay.
%
% Output:
%   M.A_lin  : interpolated linear-frequency magnitude map
%   M.A_show : normalized/thresholded/gamma-adjusted map in [0,1]
%   M.t_us   : time axis in us
%   M.f_kHz  : linear frequency axis in kHz
%   M.rawMax : max of A_lin before normalization

    sig = double(sig(:));
    sig(~isfinite(sig)) = 0;
    sig = sig - mean(sig);

    if isempty(sig) || all(sig == 0)
        M = struct('A_lin', [], 'A_show', [], 't_us', [], 'f_kHz', [], 'rawMax', 0);
        return;
    end

    try
        [cfs, f] = cwt(sig, fs, C.wavelet, 'VoicesPerOctave', C.voicesPerOctave);
    catch
        [cfs, f] = cwt(sig, fs, C.wavelet);
    end

    mag = abs(cfs);
    f = f(:);
    if f(1) > f(end)
        f = flipud(f);
        mag = flipud(mag);
    end

    f_lin = linspace(0, C.fmax_kHz * 1000, C.nFreqBins);
    mag_lin = interp1(f, mag, f_lin, 'linear', 0);

    rawMax = max(mag_lin(:));
    if ~(isfinite(rawMax) && rawMax > 0)
        rawMax = 1;
    end

    img_show = mag_lin ./ rawMax;
    img_show(img_show < C.threshold) = 0;
    img_show(img_show > 1) = 1;
    img_show = img_show .^ C.gamma;

    M = struct();
    M.A_lin = mag_lin;
    M.A_show = img_show;
    M.rawMax = rawMax;
    M.t_us = (0:numel(sig)-1) / fs * 1e6;
    M.f_kHz = f_lin / 1000;
end
