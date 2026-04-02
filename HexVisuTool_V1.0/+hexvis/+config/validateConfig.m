function cfg = validateConfig(cfg)
%VALIDATECONFIG Lightweight validation to catch easy mistakes early.

    mustBePositiveIntegerScalar(cfg.channels.S1, 'cfg.channels.S1');
    mustBePositiveIntegerScalar(cfg.channels.S2, 'cfg.channels.S2');

    if cfg.channels.S1 == cfg.channels.S2
        error('cfg.channels.S1 and cfg.channels.S2 must be different.');
    end

    if ~isnumeric(cfg.geom.L_mm) || ~isscalar(cfg.geom.L_mm) || cfg.geom.L_mm <= 0
        error('cfg.geom.L_mm must be a positive scalar.');
    end

    if ~isnumeric(cfg.geom.v_ms) || ~isscalar(cfg.geom.v_ms) || cfg.geom.v_ms <= 0
        error('cfg.geom.v_ms must be a positive scalar.');
    end

    if ~ischar(cfg.vis.defaultTFMode) && ~isstring(cfg.vis.defaultTFMode)
        error('cfg.vis.defaultTFMode must be text.');
    end
end

function mustBePositiveIntegerScalar(x, name)
    if ~isnumeric(x) || ~isscalar(x) || x < 1 || abs(x-round(x)) > 0
        error('%s must be a positive integer scalar.', name);
    end
end
