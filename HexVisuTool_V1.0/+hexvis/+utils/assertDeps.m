function dep = assertDeps(cfg)
%ASSERTDEPS Check required and optional dependencies.

    dep = struct();
    dep.waveReader = exist('waveReader', 'file') ~= 0;
    dep.extractOpt = exist('ExtractFeati_OPT', 'file') ~= 0;
    dep.externalAIC = exist('AE_Tools_V3', 'class') ~= 0 || exist('AE_Tools_V3', 'file') ~= 0;
    dep.cwt = exist('cwt', 'file') ~= 0 || exist('cwt', 'builtin') ~= 0;
    dep.tfrstft = exist('tfrstft', 'file') ~= 0;
    dep.tfrsp = exist('tfrsp', 'file') ~= 0;
    dep.messages = {};

    if isfield(cfg,'deps') && isfield(cfg.deps,'waveReaderRequired') && cfg.deps.waveReaderRequired && ~dep.waveReader
        dep.messages{end+1} = 'Missing required dependency: waveReader'; %#ok<AGROW>
    end
    if ~dep.cwt
        dep.messages{end+1} = 'Wavelet Toolbox function cwt not found'; %#ok<AGROW>
    end
    if ~dep.extractOpt
        dep.messages{end+1} = 'ExtractFeati_OPT not found: internal feature wrapper will be used'; %#ok<AGROW>
    end
    useExternalMsg = false;
    if isfield(cfg,'deps') && isfield(cfg.deps,'externalAICPreferred')
        useExternalMsg = logical(cfg.deps.externalAICPreferred);
    end
    if useExternalMsg && ~dep.externalAIC
        dep.messages{end+1} = 'AE_Tools_V3 not found: internal robust AIC will be used'; %#ok<AGROW>
    end
end
