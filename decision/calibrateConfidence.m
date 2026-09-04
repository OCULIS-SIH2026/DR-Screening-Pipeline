function [calibratedProbs, confidence, entropyVal] = calibrateConfidence(rawProbs, varargin)
% CALIBRATECONFIDENCE Calibrates neural network probabilities via Temperature Scaling.
%
% Clinical Background:
%   Modern deep neural networks tend to be overconfident in their raw softmax
%   predictions. Temperature scaling (Guo et al., 2017) softens extreme logits
%   to produce well-calibrated confidence estimates aligned with true clinical risk.
%
% Usage:
%   [calProbs, conf, entropy] = calibrateConfidence(rawProbs)
%   [calProbs, conf, entropy] = calibrateConfidence(rawProbs, 'Temperature', 1.25)
%
% Inputs:
%   rawProbs - 1x5 double vector of model softmax probabilities [P0, P1, P2, P3, P4].
%
% Name-Value Parameters:
%   'Temperature' - Scalar T > 0 (default: 1.25). T > 1 softens overconfidence;
%                   T = 1.0 preserves original probabilities.
%
% Outputs:
%   calibratedProbs - 1x5 calibrated probability distribution summing to 1.0.
%   confidence      - Maximum calibrated probability max(P_i).
%   entropyVal      - Shannon entropy in bits (higher = higher model uncertainty).
%
% Reference:
%   Phase 8: Confidence, Referable DR, and Decision Logic

    p = inputParser;
    addRequired(p, 'rawProbs', @(x) isnumeric(x) && numel(x) == 5);
    addParameter(p, 'Temperature', 1.25, @(x) isnumeric(x) && x > 0);
    parse(p, rawProbs, varargin{:});

    T = p.Results.Temperature;
    probs = double(reshape(rawProbs, [1, 5]));

    % 1. Recover pseudo-logits via log: z_i = log(P_i + eps)
    epsVal = 1e-7;
    safeProbs = max(epsVal, probs);
    safeProbs = safeProbs / sum(safeProbs);
    logits = log(safeProbs);

    % 2. Temperature Scaling: z_scaled = z / T
    scaledLogits = logits / T;

    % 3. Softmax
    expL = exp(scaledLogits - max(scaledLogits));
    calibratedProbs = expL / sum(expL);
    calibratedProbs = round(calibratedProbs, 4);
    % Ensure exact sum to 1.0
    calibratedProbs = calibratedProbs / sum(calibratedProbs);

    % 4. Confidence (Maximum class probability)
    confidence = round(max(calibratedProbs), 4);

    % 5. Normalized Shannon Entropy: H = -sum(P * log2(P)) / log2(5)
    % Scaled to [0, 1] where 0 = complete certainty, 1 = maximum ambiguity
    pTerms = calibratedProbs .* log2(max(epsVal, calibratedProbs));
    rawEntropy = -sum(pTerms);
    maxPossibleEntropy = log2(5); % For 5 classes = ~2.32 bits
    entropyVal = round(rawEntropy / maxPossibleEntropy, 4);
end
