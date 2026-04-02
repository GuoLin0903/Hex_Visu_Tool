function plotTFRSTFTQuick(ax, sig, fs, pickIdx, C, ttl)
%PLOTTFRSTFTQUICK Fast preview STFT.
%
% For phase-1 stability, this function prioritizes MATLAB-native spectrogram.
% A hook for TFTB can be reintroduced later if needed.

    cla(ax);
    sig = double(sig(:));
    sig = sig - mean(sig);
    if numel(sig) < 8
        text(ax, 0.5, 0.5, 'Signal too short', 'HorizontalAlignment', 'center');
        axis(ax, 'off');
        return;
    end

    wlen = min(C.windowLength, numel(sig));
    wlen = max(32, wlen);
    noverlap = min(C.overlap, wlen-1);
    nfft = max(C.nfft, 2^nextpow2(wlen));

    [S, F, T] = spectrogram(sig, hamming(wlen), noverlap, nfft, fs, 'yaxis');
    A = abs(S);
    A = A ./ (max(A(:)) + eps);
    A_db = 20 * log10(A + eps);

    f_kHz = F(:) / 1e3;
    idxF = f_kHz <= C.fmax_kHz;
    imagesc(ax, T*1e6, f_kHz(idxF), A_db(idxF,:));
    set(ax, 'YDir', 'normal');
    caxis(ax, C.clim_dB);
    colorbar(ax);
    grid(ax, 'on');
    box(ax, 'on');
    xlabel(ax, 'Time (\mus)');
    ylabel(ax, 'Frequency (kHz)');
    title(ax, ttl, 'Interpreter', 'none');
    colormap(ax, jet);

    if nargin >= 4 && isfinite(pickIdx) && pickIdx >= 1 && pickIdx <= numel(sig)
        hold(ax, 'on');
        xline(ax, (pickIdx-1)/fs*1e6, 'w--', 'LineWidth', 1.0);
        hold(ax, 'off');
    end
end
