function plotFFT(ax, sig, fs, fmax_kHz, ttl)
%PLOTFFT Fast normalized FFT preview.

    cla(ax);
    [f_kHz, magN] = hexvis.utils.oneSidedFFT(sig, fs);
    idx = true(size(f_kHz));
    if nargin >= 4 && ~isempty(fmax_kHz)
        idx = f_kHz <= fmax_kHz;
    end

    plot(ax, f_kHz(idx), magN(idx), 'b-', 'LineWidth', 1.0);
    grid(ax, 'on');
    box(ax, 'on');
    xlabel(ax, 'Frequency (kHz)');
    ylabel(ax, 'Norm. |FFT|');
    title(ax, ttl, 'Interpreter', 'none');
end
