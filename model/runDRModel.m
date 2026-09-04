function [outSample, prediction] = runDRModel(model, inputArg, varargin)
% RUNDRMODEL Executes forward inference to predict Diabetic Retinopathy stage (Level 0-4).
%
% Input Contract:
%   Standardized fundus image preprocessed according to model contract.
%
% Output Contract:
%   Five probabilities corresponding to International Clinical DR stages:
%     Class 0 -> No DR
%     Class 1 -> Mild NPDR
%     Class 2 -> Moderate NPDR
%     Class 3 -> Severe NPDR
%     Class 4 -> Proliferative DR
%
% Usage:
%   prediction = runDRModel(model, imgMatrix)
%   [sample, prediction] = runDRModel(model, sample)
%   sample = runDRModel(model, sample)
%
% Outputs:
%   outSample  - Updated sample struct (if sample passed as input).
%   prediction - Struct containing:
%                  .predictedClass (0, 1, 2, 3, 4)
%                  .classLabel     ("No DR", "Moderate NPDR", etc.)
%                  .probabilities  (1x5 double array summing to 1.0)
%                  .modelName      (string identifier)
%
% Reference:
%   Phase 6: CNN Inference Integration

    if nargin < 1 || isempty(model)
        model = loadDRModel("mock");
    end

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
        if isfield(sample, 'lesionEvidence')
            evidence = sample.lesionEvidence;
        end
    elseif isnumeric(inputArg) || islogical(inputArg)
        workingImg = inputArg;
    else
        error('runDRModel:InvalidInput', 'Input must be a sample struct or an image matrix.');
    end

    % 1. Preprocess input according to model contract
    [prepTensor, ~] = preprocessForModel(workingImg, model.contract);

    % 2. Forward Inference
    if isfield(model, 'isMock') && model.isMock
        % Execute calibrated mock inference based on image / lesion features
        probs = simulateCalibratedInference(workingImg, evidence);
        modelName = model.name;
    else
        % Real Neural Network Forward Pass
        try
            rawPred = predict(model.net, prepTensor);
            % Ensure softmax probability distribution
            if max(rawPred) > 1.0 || min(rawPred) < 0.0 || abs(sum(rawPred) - 1.0) > 0.05
                % Apply softmax if logits were returned
                expVals = exp(rawPred - max(rawPred));
                probs = expVals / sum(expVals);
            else
                probs = rawPred / sum(rawPred);
            end
            probs = double(reshape(probs, [1, 5]));
            modelName = model.name;
        catch ME
            warning('runDRModel:InferenceError', ...
                'Model inference failed (%s). Falling back to calibrated simulator.', ME.message);
            probs = simulateCalibratedInference(workingImg, evidence);
            modelName = model.name + " (Fallback Simulator)";
        end
    end

    % 3. Extract Predicted Class and Description
    [~, maxIdx] = max(probs);
    predictedClass = maxIdx - 1; % 1-indexed to 0-indexed: 0, 1, 2, 3, 4

    labels = model.contract.classes.labels;
    classLabel = labels(predictedClass + 1);

    % 4. Assemble Prediction Struct
    prediction = struct();
    prediction.predictedClass = predictedClass;
    prediction.classLabel     = classLabel;
    prediction.probabilities  = round(probs, 4);
    prediction.modelName      = string(modelName);
    prediction.contract       = model.contract;

    % Update sample struct if applicable
    if isSampleStruct
        sample.prediction = prediction;
        outSample = sample;
    else
        outSample = prediction;
    end
end

%% Helper: Realistic calibrated mock inference
function probs = simulateCalibratedInference(img, evidence)
    % Default prior: healthy fundus
    baseLogits = [2.5, -0.8, -1.5, -2.5, -3.5];

    if ~isempty(evidence) && isstruct(evidence)
        numMA = 0; numHA = 0; numEX = 0; isNV = false;
        if isfield(evidence, 'microaneurysms') && isfield(evidence.microaneurysms, 'count')
            numMA = evidence.microaneurysms.count;
        end
        if isfield(evidence, 'hemorrhages') && isfield(evidence.hemorrhages, 'count')
            numHA = evidence.hemorrhages.count;
        end
        if isfield(evidence, 'exudates') && isfield(evidence.exudates, 'count')
            numEX = evidence.exudates.count;
        end
        if isfield(evidence, 'neovascularization') && isfield(evidence.neovascularization, 'detected')
            isNV = evidence.neovascularization.detected;
        end

        if isNV
            % Level 4: Proliferative DR
            baseLogits = [-3.0, -2.0, -0.5, 1.2, 3.2];
        elseif numHA >= 5 || numEX >= 4
            % Level 3: Severe NPDR
            baseLogits = [-2.8, -1.2, 1.0, 3.0, 0.2];
        elseif numHA >= 1 || numEX >= 1 || numMA >= 4
            % Level 2: Moderate NPDR
            baseLogits = [-1.5, 0.5, 2.8, 0.4, -2.0];
        elseif numMA >= 1
            % Level 1: Mild NPDR
            baseLogits = [-0.5, 2.6, 0.2, -1.8, -3.0];
        else
            % Level 0: No DR
            baseLogits = [3.2, -1.0, -2.0, -3.0, -4.0];
        end
    else
        % Image-based photometric heuristic
        G = double(img(:, :, 2));
        varG = var(G(:));
        if varG > 2200
            baseLogits = [-1.0, 0.2, 2.2, 0.8, -1.5];
        end
    end

    % Softmax
    expL = exp(baseLogits - max(baseLogits));
    probs = expL / sum(expL);
end
