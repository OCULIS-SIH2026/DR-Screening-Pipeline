function contract = getModelContract(varargin)
% GETMODELCONTRACT Defines the standard interface contract between CNN and Engine.
%
% Specification:
%   - Input Dimensions: [224, 224, 3] (configurable via .env / arguments)
%   - Color Format:     RGB
%   - Normalization:    'imagenet' ([img/255 - mean] / std)
%   - Output Format:    5 softmax class probabilities [P0, P1, P2, P3, P4]
%
% Usage:
%   contract = getModelContract()
%   contract = getModelContract('InputSize', [299, 299, 3], 'Normalization', 'rescale')
%
% Reference:
%   Phase 6: CNN Inference Integration

    cfg = getConfig();

    p = inputParser;
    addParameter(p, 'InputSize', [cfg.TARGET_SIZE, 3], @(x) isnumeric(x) && (numel(x) == 2 || numel(x) == 3));
    addParameter(p, 'Normalization', 'imagenet', @(x) ischar(x) || isstring(x));
    addParameter(p, 'ModelName', "ResNet50_DR_Classifier", @(x) ischar(x) || isstring(x));
    addParameter(p, 'GradCAMLayer', "res5c_relu", @(x) ischar(x) || isstring(x));
    parse(p, varargin{:});

    sz = p.Results.InputSize;
    if numel(sz) == 2
        sz = [sz(1), sz(2), 3];
    end

    contract = struct();
    contract.inputSize     = sz;
    contract.colorSpace    = "RGB";
    contract.normalization = lower(string(p.Results.Normalization));
    contract.modelName     = string(p.Results.ModelName);
    contract.gradCAMLayer  = string(p.Results.GradCAMLayer);

    % Standard 5-Level Diabetic Retinopathy International Clinical Staging
    contract.classes = struct( ...
        'indices', [0, 1, 2, 3, 4], ...
        'labels', ["No DR", "Mild NPDR", "Moderate NPDR", "Severe NPDR", "Proliferative DR"], ...
        'descriptions', [ ...
            "No visible retinal abnormalities", ...
            "Microaneurysms only", ...
            "More than microaneurysms but less than severe NPDR", ...
            "Any of: >20 intraretinal hemorrhages in 4 quadrants, definite venous beading in 2+ quadrants, prominent IRMA in 1+ quadrant", ...
            "Neovascularization or vitreous/preretinal hemorrhage" ...
        ] ...
    );

    % ImageNet Normalization Constants
    contract.imageNetMean = [0.485, 0.456, 0.406];
    contract.imageNetStd  = [0.229, 0.224, 0.225];
end
