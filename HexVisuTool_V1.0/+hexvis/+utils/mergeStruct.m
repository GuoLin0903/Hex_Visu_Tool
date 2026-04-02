function S = mergeStruct(varargin)
%MERGESTRUCT Merge scalar structs from left to right.

    S = struct();
    for k = 1:nargin
        if isempty(varargin{k}), continue; end
        fn = fieldnames(varargin{k});
        for i = 1:numel(fn)
            S.(fn{i}) = varargin{k}.(fn{i});
        end
    end
end
