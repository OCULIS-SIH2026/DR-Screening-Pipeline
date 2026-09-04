function metrics = evaluateClinicalMetrics(groundTruth, predictions, varargin)
% EVALUATECLINICALMETRICS Computes screening validation metrics for Diabetic Retinopathy.
%
% Clinical Targets (for Referable DR):
%   - Sensitivity > 90% (minimizes missed sight-threatening DR)
%   - Specificity > 85% (minimizes unnecessary specialist clinic overburden)
%
% Usage:
%   metrics = evaluateClinicalMetrics(trueLabels, predClasses)
%   metrics = evaluateClinicalMetrics(trueLabels, predProbMatrix)
%
% Inputs:
%   groundTruth - Nx1 array of true DR stages (0 to 4).
%   predictions - Nx1 array of predicted classes (0 to 4), OR Nx5 probability matrix.
%
% Outputs:
%   metrics - Struct containing:
%               .sensitivity          (Referable DR Recall)
%               .specificity          (Non-referable True Negative Rate)
%               .precision            (Positive Predictive Value)
%               .npv                  (Negative Predictive Value)
%               .f1Score              (Harmonic mean of precision & sensitivity)
%               .accuracy             (Overall binary accuracy)
%               .confusionMatrix2x2   ([TN, FP; FN, TP] for referable DR)
%               .confusionMatrix5x5   (Multi-class 5x5 confusion matrix)
%               .perClassSensitivity  (1x5 recall vector for levels 0, 1, 2, 3, 4)
%               .meetsClinicalTarget  (Logical true if Sens >= 90% & Spec >= 85%)
%
% Reference:
%   Phase 8: Confidence, Referable DR, and Decision Logic

    p = inputParser;
    addRequired(p, 'groundTruth', @isnumeric);
    addRequired(p, 'predictions', @isnumeric);
    parse(p, groundTruth, predictions, varargin{:});

    yTrue = round(reshape(groundTruth, [], 1));

    if size(predictions, 2) == 5
        % Probability matrix provided: argmax for class
        [~, maxIndices] = max(predictions, [], 2);
        yPred = maxIndices - 1;
    else
        yPred = round(reshape(predictions, [], 1));
    end

    numSamples = numel(yTrue);
    if numel(yPred) ~= numSamples
        error('evaluateClinicalMetrics:SizeMismatch', 'groundTruth and predictions must have identical sample count.');
    end

    % 1. Multi-class 5x5 Confusion Matrix (Rows = True, Cols = Pred)
    confMat5x5 = zeros(5, 5);
    for i = 1:numSamples
        t = yTrue(i);
        p = yPred(i);
        if t >= 0 && t <= 4 && p >= 0 && p <= 4
            confMat5x5(t + 1, p + 1) = confMat5x5(t + 1, p + 1) + 1;
        end
    end

    % Per-class Sensitivity (Recall)
    perClassRecall = zeros(1, 5);
    for c = 1:5
        rowTotal = sum(confMat5x5(c, :));
        if rowTotal > 0
            perClassRecall(c) = confMat5x5(c, c) / rowTotal;
        else
            perClassRecall(c) = NaN;
        end
    end

    % 2. Binary Referable DR Mapping: Class >= 2 is Referable (Positive)
    binTrue = (yTrue >= 2);
    binPred = (yPred >= 2);

    TP = sum(binTrue & binPred);
    TN = sum(~binTrue & ~binPred);
    FP = sum(~binTrue & binPred);
    FN = sum(binTrue & ~binPred);

    confMat2x2 = [TN, FP; FN, TP];

    % 3. Clinical Diagnostic Metrics
    % Sensitivity = TP / (TP + FN)
    if (TP + FN) > 0
        sensitivity = TP / (TP + FN);
    else
        sensitivity = 1.0;
    end

    % Specificity = TN / (TN + FP)
    if (TN + FP) > 0
        specificity = TN / (TN + FP);
    else
        specificity = 1.0;
    end

    % Precision (PPV) = TP / (TP + FP)
    if (TP + FP) > 0
        precision = TP / (TP + FP);
    else
        precision = 0.0;
    end

    % Negative Predictive Value (NPV) = TN / (TN + FN)
    if (TN + FN) > 0
        npv = TN / (TN + FN);
    else
        npv = 0.0;
    end

    % F1-Score = 2 * (Precision * Sensitivity) / (Precision + Sensitivity)
    if (precision + sensitivity) > 0
        f1Score = 2 * (precision * sensitivity) / (precision + sensitivity);
    else
        f1Score = 0.0;
    end

    accuracy = (TP + TN) / numSamples;

    % 4. Check Clinical Acceptance Standard
    meetsTarget = (sensitivity >= 0.90) && (specificity >= 0.85);

    metrics = struct();
    metrics.sensitivity          = round(sensitivity, 4);
    metrics.specificity          = round(specificity, 4);
    metrics.precision            = round(precision, 4);
    metrics.npv                  = round(npv, 4);
    metrics.f1Score              = round(f1Score, 4);
    metrics.accuracy             = round(accuracy, 4);
    metrics.confusionMatrix2x2   = confMat2x2;
    metrics.confusionMatrix5x5   = confMat5x5;
    metrics.perClassSensitivity  = round(perClassRecall, 4);
    metrics.meetsClinicalTarget  = meetsTarget;
    metrics.summaryTable = sprintf( ...
        "Sensitivity: %.1f%% (Target > 90%%) | Specificity: %.1f%% (Target > 85%%) | F1-Score: %.3f", ...
        sensitivity * 100, specificity * 100, f1Score);
end
