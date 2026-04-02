function renderTF(ax, sig, fs, varargin)
%RENDERTF Dispatch TF visualization robustly.
% Supports both call forms:
%   renderTF(ax,sig,fs,pickIdx,modeName,cfgVis,ttl)
%   renderTF(ax,sig,fs,modeName,cfgVis,ttl)

    pickIdx = nan;
    modeName = 'cwt';
    cfgVis = struct();
    ttl = '';

    if numel(varargin) == 4
        pickIdx  = varargin{1};
        modeName = varargin{2};
        cfgVis   = varargin{3};
        ttl      = varargin{4};
    elseif numel(varargin) == 3
        modeName = varargin{1};
        cfgVis   = varargin{2};
        ttl      = varargin{3};
    else
        error('renderTF:BadInput', 'Expected 3 or 4 extra inputs.');
    end

    modeName = localModeName(modeName);

    switch modeName
        case 'cwt'
            hexvis.vis.plotCWTModal(ax, sig, fs, pickIdx, cfgVis.cwt, ttl);
        case 'tfrsp'
            hexvis.vis.plotTFRSPQuick(ax, sig, fs, pickIdx, cfgVis.quick, ttl);
        otherwise
            hexvis.vis.plotCWTModal(ax, sig, fs, pickIdx, cfgVis.cwt, ttl);
    end
end

function s = localModeName(x)
    if isstring(x) || ischar(x)
        s = char(x);
    elseif iscell(x) && ~isempty(x)
        s = localModeName(x{1});
        return;
    elseif isstruct(x)
        if isfield(x, 'mode')
            s = localModeName(x.mode);
            return;
        else
            s = 'cwt';
        end
    else
        s = 'cwt';
    end
    s = lower(strtrim(s));
    if contains(s, 'tfr') || contains(s, 'sp')
        s = 'tfrsp';
    else
        s = 'cwt';
    end
end
