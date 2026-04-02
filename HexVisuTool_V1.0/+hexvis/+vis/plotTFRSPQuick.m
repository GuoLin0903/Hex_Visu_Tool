function plotTFRSPQuick(ax, sig, fs, pickIdx, C, ttl)
%PLOTTFRSPQUICK Quick preview using TFTB tfrsp when available.

    cla(ax);
    sig = double(sig(:));
    sig = sig - mean(sig);
    if numel(sig) < 8
        text(ax, 0.5, 0.5, 'Signal too short', 'HorizontalAlignment', 'center');
        axis(ax, 'off');
        return;
    end
    if exist('tfrsp', 'file') == 0
        text(ax, 0.5, 0.5, 'tfrsp not found on path', 'HorizontalAlignment', 'center');
        axis(ax, 'off');
        return;
    end

    try
        [TFR, t_idx, f_norm] = tfrsp(sig);
    catch ME
        cla(ax);
        text(ax, 0.5, 0.5, sprintf('tfrsp failed:\n%s', ME.message), 'HorizontalAlignment', 'center');
        axis(ax, 'off');
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

    imagesc(ax, t_us, f_kHz, A_db);
    set(ax, 'YDir', 'normal');
    caxis(ax, C.clim_dB);
    colormap(ax, jet(256));
    colorbar(ax);
    grid(ax, 'on');
    box(ax, 'on');
    xlabel(ax, 'Time (\mus)');
    ylabel(ax, 'Frequency (kHz)');
    title(ax, ttl, 'Interpreter', 'none');

    if nargin >= 4 && isfinite(pickIdx) && pickIdx >= 1 && pickIdx <= numel(sig)
        hold(ax, 'on');
        xline(ax, (pickIdx-1)/fs*1e6, 'w--', 'LineWidth', 1.0);
        hold(ax, 'off');
    end
end
