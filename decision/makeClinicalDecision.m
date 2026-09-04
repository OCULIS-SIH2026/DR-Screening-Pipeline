function [outSample, decisionStruct] = makeClinicalDecision(inputArg, varargin)
% MAKECLINICALDECISION Master decision engine converting CNN predictions into clinical triage.
%
% Coordinates:
%   1. Temperature-scaled probability calibration & Shannon entropy calculation
%   2. Binary Referable vs. Non-Referable triage (Class 0, 1 vs. Class 2, 3, 4)
%   3. Urgency staging and clinical action timeframe
%   4. Uncertainty gating and Model-vs-Evidence contradiction auditing
%
% Usage:
%   sample = makeClinicalDecision(sample)
%   [sample, decision] = makeClinicalDecision(sample)
%   [sample, decision] = makeClinicalDecision(sample, 'Temperature', 1.25)
%
% Inputs:
%   inputArg - Standard sample struct with sample.prediction populated.
%
% Outputs:
%   outSample      - Updated sample struct with sample.decision populated.
%   decisionStruct - Comprehensive clinical decision and referral summary.
%
% Reference:
%   Phase 8: Confidence, Referable DR, and Decision Logic

    p = inputParser;
    addRequired(p, 'inputArg');
    addParameter(p, 'Temperature', 1.25, @(x) isnumeric(x) && x > 0);
    parse(p, inputArg, varargin{:});

    temp = p.Results.Temperature;

    isSampleStruct = isstruct(inputArg) && isfield(inputArg, 'image');

    if isSampleStruct
        sample = inputArg;
        if ~isfield(sample, 'prediction') || isempty(sample.prediction.predictedClass) || ...
           isnan(sample.prediction.predictedClass)
            error('makeClinicalDecision:MissingPrediction', ...
                'sample.prediction is empty. Run runDRModel before making clinical decision.');
        end
        predClass = sample.prediction.predictedClass;
        rawProbs  = sample.prediction.probabilities;
    else
        error('makeClinicalDecision:InvalidInput', 'Input must be a standard sample struct.');
    end

    % 1. Step 1: Probability Calibration & Predictive Entropy
    [calibratedProbs, confidence, entropyVal] = calibrateConfidence(rawProbs, 'Temperature', temp);

    % 2. Step 2: Referable DR Triage & Clinical Urgency
    referral = determineReferral(predClass, calibratedProbs);

    % 3. Step 3: Apply Clinical Safety Gate (Uncertainty & Contradiction)
    gate = applyClinicalGate(sample);

    % 4. Assemble Master Decision Struct
    decisionStruct = struct();
    decisionStruct.predictedClass       = predClass;
    decisionStruct.classLabel           = sample.prediction.classLabel;
    decisionStruct.isReferable          = referral.isReferable;
    decisionStruct.referableCategory    = referral.referralCategory;
    decisionStruct.referableProbability = referral.referableProbability;
    decisionStruct.confidence           = confidence;
    decisionStruct.calibratedProbs      = calibratedProbs;
    decisionStruct.entropy              = entropyVal;
    decisionStruct.isUrgent             = referral.isUrgent;
    decisionStruct.urgencyLevel         = referral.urgencyLevel;
    decisionStruct.recommendedTimeframe = referral.recommendedTimeframe;
    decisionStruct.needsHumanReview     = gate.needsHumanReview;
    decisionStruct.actionRequired       = gate.finalAction;
    decisionStruct.reviewReasons        = gate.reviewReasons;
    decisionStruct.isContradiction      = gate.isContradiction;

    % Update sample struct
    sample.decision = decisionStruct;
    outSample = sample;
end
