function [outSample, heatmap, overlayImg] = generateGradCAM(model, inputArg, varargin)
% GENERATEGRADCAM Master engine for CNN explainability via Grad-CAM heatmaps.
%
% Shows WHY the CNN produced its Diabetic Retinopathy prediction by visualizing
% convolutional feature activations contributing most strongly to the classification.
%
% Usage:
%   sample = generateGradCAM(model, sample)
%   [sample, heatmap, overlay] = generateGradCAM(model, sample)
%   [sample, heatmap, overlay] = generateGradCAM(model, sample, 'TargetClass', 2)
%   [heatmap, overlay, info]   = generateGradCAM(model, rawImageMatrix)
%
% Name-Value Parameters:
%   'TargetClass'  - Integer class to explain (0-4). Defaults to model prediction.
%   'FeatureLayer' - String name of conv layer to tap (defaults to contract layer).
%   'Alpha'        - Heatmap blending opacity in [0, 1] (default: 0.45).
%   'Colormap'     - 'jet' (default), 'turbo', or 'hot'.
%
% Outputs:
%   outSample      - Updated sample struct with sample.gradCAM populated.
%   heatmap        - 2D double matrix [H, W] normalized in [0.0, 1.0].
%   overlayImg     - RGB fundus composite image with heatmap overlay (uint8).
%
% Reference:
%   Phase 7: Explainability and Grad-CAM

    if nargin < 1 || isempty(model)
        model = loadDRModel("mock");
    end

    p = inputParser;
    addRequired(p, 'model');
    addRequired(p, 'inputArg');
    addParameter(p, 'TargetClass', [], @(x) isempty(x) || isnumeric(x));
    addParameter(p, 'FeatureLayer', "", @(x) ischar(x) || isstring(x));
    addParameter(p, 'Alpha', 0.45, @(x) isnumeric(x) && x >= 0 && x <= 1);
    addParameter(p, 'Colormap', 'jet', @(x) ischar(x) || isstring(x));
    parse(p, model, inputArg, varargin{:});

    targetClass = p.Results.TargetClass;
    featLayer   = string(p.Results.FeatureLayer);
    alpha       = p.Results.Alpha;
    cmapChoice  = char(p.Results.Colormap);

    isSampleStruct = isstruct(inputArg) && isfield(inputArg, 'image');
    sample = [];
    evidence = [];

    if isSampleStruct
        sample = inputArg;
        if isfield(sample, 'enhancementInfo') && sample.enhancementInfo.applied && ...
           ~isempty(sample.enhancedImage)
            workingImg = sample.enhancedImage;
        else
            workingImg = sample.image;
        end

        % Extract retina mask
        if isfield(sample, 'quality') && isfield(sample.quality, 'retinaMask') && ...
           ~isempty(sample.quality.retinaMask)
            retinaMask = sample.quality.retinaMask;
        else
            [~, ~, retinaMask] = assessFOV(workingImg);
        end

        % Extract lesion evidence if present
        if isfield(sample, 'lesionEvidence')
            evidence = sample.lesionEvidence;
        end

        % Determine target class from prediction if not explicitly provided
        if isempty(targetClass)
            if ~isfield(sample, 'prediction') || isempty(sample.prediction.predictedClass) || ...
               isnan(sample.prediction.predictedClass)
                sample = runDRModel(model, sample);
            end
            targetClass = sample.prediction.predictedClass;
        end
    elseif isnumeric(inputArg) || islogical(inputArg)
        workingImg = inputArg;
        [~, ~, retinaMask] = assessFOV(workingImg);
        if isempty(targetClass)
            pred = runDRModel(model, workingImg);
            targetClass = pred.predictedClass;
        end
    else
        error('generateGradCAM:InvalidInput', 'Input must be a sample struct or image matrix.');
    end

    if featLayer == ""
        featLayer = model.contract.gradCAMLayer;
    end

    % 1. Compute 2D Grad-CAM Heatmap
    heatmap = computeGradCAMMap(model, workingImg, targetClass, ...
        'FeatureLayer', featLayer, 'Evidence', evidence);

    % 2. Blend Heatmap with Fundus Photograph
    overlayImg = overlayHeatmap(workingImg, heatmap, ...
        'Alpha', alpha, 'RetinaMask', retinaMask, 'Colormap', cmapChoice);

    % 3. Formulate Clinical Interpretation Text
    labels = model.contract.classes.labels;
    targetLabel = labels(targetClass + 1);

    if targetClass == 0
        explanationText = sprintf( ...
            "Grad-CAM demonstrates diffuse, non-focal activation across normal retinal vascular arcades consistent with No Diabetic Retinopathy (Class 0).");
    else
        explanationText = sprintf( ...
            "Grad-CAM highlights focal activation peaks corresponding to regions that drove the model's prediction for %s (Class %d).", ...
            targetLabel, targetClass);
    end

    % 4. Assemble Grad-CAM Struct
    gradCAMStruct = struct();
    gradCAMStruct.heatmap     = heatmap;
    gradCAMStruct.overlay     = overlayImg;
    gradCAMStruct.targetClass = targetClass;
    gradCAMStruct.classLabel  = targetLabel;
    gradCAMStruct.targetLayer = featLayer;
    gradCAMStruct.explanation = explanationText;

    % Update sample struct if applicable
    if isSampleStruct
        sample.gradCAM = gradCAMStruct;
        outSample = sample;
    else
        outSample = gradCAMStruct;
    end
end
