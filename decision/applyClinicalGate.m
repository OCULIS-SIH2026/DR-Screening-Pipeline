function gateResult = applyClinicalGate(sample, varargin)
% APPLYCLINICALGATE Applies uncertainty gating and human-review safety rules.
%
% Safety Protocol:
%   1. High confidence + GOOD quality + no lesion contradiction:
%      --> Automated screening result accepted.
%   2. Low confidence (< 0.70) OR BORDERLINE quality OR lesion contradiction:
%      --> Mandatory Human Ophthalmologist Review flagged.
%   3. RECAPTURE quality:
%      --> Image rejected; physical recapture required.
%
% Usage:
%   gateResult = applyClinicalGate(sample)
%
% Outputs:
%   gateResult - Struct containing:
%                  .needsHumanReview (true / false)
%                  .finalAction      ("AUTOMATED_ACCEPTED", "HUMAN_REVIEW_REQUIRED", "RECAPTURE")
%                  .reviewReasons    (cell array of warning/flag strings)
%                  .isContradiction  (true if model contradicts physical lesion evidence)
%
% Reference:
%   Phase 8: Confidence, Referable DR, and Decision Logic

    cfg = getConfig();
    minConfidence = cfg.CONFIDENCE_MIN_ACCEPTABLE; % default 0.70 - 0.80

    reviewReasons = {};
    needsHumanReview = false;
    isContradiction = false;

    % 1. Check Image Quality Gate
    qualityStatus = "GOOD";
    if isfield(sample, 'quality') && isfield(sample.quality, 'status')
        qualityStatus = sample.quality.status;
    end

    if qualityStatus == "RECAPTURE"
        finalAction = "RECAPTURE_REQUIRED";
        needsHumanReview = true;
        reviewReasons{end+1} = "Image quality is RECAPTURE; uninterpretable for automated screening.";
        gateResult = packageGate(true, finalAction, reviewReasons, false);
        return;
    elseif qualityStatus == "BORDERLINE"
        needsHumanReview = true;
        reviewReasons{end+1} = "Borderline image quality; ophthalmologist confirmation recommended.";
    end

    % 2. Check Model Confidence & Predictive Entropy
    conf = 1.0;
    entropyVal = 0.0;
    if isfield(sample, 'decision') && isfield(sample.decision, 'confidence') && ~isnan(sample.decision.confidence)
        conf = sample.decision.confidence;
        if isfield(sample.decision, 'entropy')
            entropyVal = sample.decision.entropy;
        end
    elseif isfield(sample, 'prediction') && isfield(sample.prediction, 'probabilities')
        [~, conf, entropyVal] = calibrateConfidence(sample.prediction.probabilities);
    end

    if conf < minConfidence
        needsHumanReview = true;
        reviewReasons{end+1} = sprintf("Low model confidence (%.1f%% < threshold %.1f%%); predictive entropy: %.2f.", ...
            conf * 100, minConfidence * 100, entropyVal);
    end

    if entropyVal > 0.65
        needsHumanReview = true;
        reviewReasons{end+1} = sprintf("High predictive entropy (%.2f); significant ambiguity across classes.", entropyVal);
    end

    % 3. Model-vs-Evidence Contradiction Audit
    if isfield(sample, 'prediction') && isfield(sample, 'lesionEvidence')
        predClass = sample.prediction.predictedClass;
        numHA = 0; numEX = 0; numMA = 0; isNV = false;
        
        if isfield(sample.lesionEvidence, 'hemorrhages')
            numHA = sample.lesionEvidence.hemorrhages.count;
        end
        if isfield(sample.lesionEvidence, 'exudates')
            numEX = sample.lesionEvidence.exudates.count;
        end
        if isfield(sample.lesionEvidence, 'microaneurysms')
            numMA = sample.lesionEvidence.microaneurysms.count;
        end
        if isfield(sample.lesionEvidence, 'neovascularization')
            isNV = sample.lesionEvidence.neovascularization.detected;
        end

        % Case A: Model predicts Class 0 (No DR), but lesions are physically detected
        if predClass == 0 && (numHA > 0 || numEX > 0 || numMA >= 3)
            needsHumanReview = true;
            isContradiction  = true;
            reviewReasons{end+1} = sprintf( ...
                "CONTRADICTION: CNN predicted No DR (Class 0), but independent feature extraction detected lesions (HA: %d, EX: %d, MA: %d).", ...
                numHA, numEX, numMA);
        end

        % Case B: Model predicts Class 4 (PDR), but no neovascularization or hemorrhages found
        if predClass == 4 && ~isNV && numHA == 0
            needsHumanReview = true;
            isContradiction  = true;
            reviewReasons{end+1} = ...
                "CONTRADICTION: CNN predicted Proliferative DR (Class 4), but no neovascularization or hemorrhages were extracted.";
        end
    end

    % 4. Final Action Determination
    if needsHumanReview
        finalAction = "HUMAN_OPHTHALMOLOGIST_REVIEW";
    else
        finalAction = "AUTOMATED_RESULT_ACCEPTED";
    end

    gateResult = packageGate(needsHumanReview, finalAction, reviewReasons, isContradiction);
end

function g = packageGate(needsReview, action, reasons, isContra)
    g = struct();
    g.needsHumanReview = needsReview;
    g.finalAction      = action;
    g.reviewReasons    = reasons;
    g.isContradiction  = isContra;
end
