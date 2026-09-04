function reportText = formatReportText(sample)
% FORMATREPORTTEXT Generates a standardized clinical screening summary text.
%
% Formats all pipeline findings (Quality, Anatomy, Lesions, CNN, Grad-CAM,
% and Clinical Triage) into a standardized ophthalmology consultation note.
%
% Usage:
%   reportText = formatReportText(sample)
%
% Output:
%   reportText - Multi-line string containing the formatted clinical report.
%
% Reference:
%   Phase 9: Automated Clinical-Style Report

    idStr = "UNKNOWN_PATIENT";
    if isfield(sample, 'imageID') && sample.imageID ~= ""
        idStr = sample.imageID;
    end

    timestamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

    % 1. Image Quality
    qStatus = "NOT_EVALUATED";
    qScore = NaN; sharpness = NaN;
    if isfield(sample, 'quality') && isfield(sample.quality, 'status')
        qStatus   = sample.quality.status;
        qScore    = sample.quality.overallScore;
        sharpness = sample.quality.sharpness;
    end

    % 2. Retinal Anatomy
    laterality = "UNKNOWN"; vesselDensity = NaN;
    if isfield(sample, 'anatomy')
        if isfield(sample.anatomy, 'fovea') && isfield(sample.anatomy.fovea, 'laterality')
            laterality = sample.anatomy.fovea.laterality;
        end
        if isfield(sample.anatomy, 'vessels') && isfield(sample.anatomy.vessels, 'density')
            vesselDensity = sample.anatomy.vessels.density * 100;
        end
    end

    % 3. Lesion Evidence
    maCount = 0; haCount = 0; exCount = 0; isNV = false;
    if isfield(sample, 'lesionEvidence')
        if isfield(sample.lesionEvidence, 'microaneurysms')
            maCount = sample.lesionEvidence.microaneurysms.count;
        end
        if isfield(sample.lesionEvidence, 'hemorrhages')
            haCount = sample.lesionEvidence.hemorrhages.count;
        end
        if isfield(sample.lesionEvidence, 'exudates')
            exCount = sample.lesionEvidence.exudates.count;
        end
        if isfield(sample.lesionEvidence, 'neovascularization')
            isNV = sample.lesionEvidence.neovascularization.detected;
        end
    end

    % 4. Model Prediction
    drLevel = NaN; classLabel = "NOT_EVALUATED"; probs = zeros(1, 5);
    if isfield(sample, 'prediction')
        drLevel    = sample.prediction.predictedClass;
        classLabel = sample.prediction.classLabel;
        probs      = sample.prediction.probabilities;
    end

    % 5. Decision & Referral Triage
    isRef = false; refCategory = "NON_REFERABLE"; conf = NaN; action = "UNKNOWN";
    timeframe = "Consult specialist";
    if isfield(sample, 'decision')
        isRef       = sample.decision.isReferable;
        refCategory = sample.decision.referableCategory;
        conf        = sample.decision.confidence * 100;
        action      = sample.decision.actionRequired;
        timeframe   = sample.decision.recommendedTimeframe;
    end

    refStr = "NO";
    if isRef
        refStr = "YES (OPHTHALMOLOGY REFERRAL REQUIRED)";
    end

    nvStr = "None detected";
    if isNV
        nvStr = "SUSPECTED (Proliferative feature flagged)";
    end

    % Assemble Multi-Line Report
    lines = [ ...
        "==========================================================================", ...
        "               DIABETIC RETINOPATHY SCREENING REPORT                      ", ...
        "==========================================================================", ...
        sprintf(" Patient / Image ID:   %s", idStr), ...
        sprintf(" Examination Date:     %s", timestamp), ...
        sprintf(" Eye Laterality:       %s", laterality), ...
        sprintf(" Image Quality:        %s (Score: %.2f | Sharpness: %.2f)", qStatus, qScore, sharpness), ...
        "--------------------------------------------------------------------------", ...
        " AI SCREENING RESULT & CLASSIFICATION", ...
        "--------------------------------------------------------------------------", ...
        sprintf(" Predicted DR Stage:   Level %d - %s", drLevel, classLabel), ...
        sprintf(" Model Confidence:     %.1f%%", conf), ...
        sprintf(" Class Probabilities:  [L0: %.2f, L1: %.2f, L2: %.2f, L3: %.2f, L4: %.2f]", ...
            probs(1), probs(2), probs(3), probs(4), probs(5)), ...
        sprintf(" Referable DR:         %s", refStr), ...
        "--------------------------------------------------------------------------", ...
        " SUPPORTING CLINICAL EVIDENCE (Independent Feature Extraction)", ...
        "--------------------------------------------------------------------------", ...
        sprintf(" Microaneurysm Candidates:   %d detected", maCount), ...
        sprintf(" Hemorrhage Candidates:      %d detected", haCount), ...
        sprintf(" Exudate Plaque Candidates:  %d detected (Optic Disc excluded)", exCount), ...
        sprintf(" Neovascularization:         %s", nvStr), ...
        sprintf(" Retinal Vascular Density:   %.1f%%", vesselDensity), ...
        "--------------------------------------------------------------------------", ...
        " CLINICAL RECOMMENDATION & TRIAGE ACTION", ...
        "--------------------------------------------------------------------------", ...
        sprintf(" Triage Action:        %s", action), ...
        sprintf(" Target Timeframe:     %s", timeframe) ...
    ];

    if isfield(sample, 'decision') && isfield(sample.decision, 'reviewReasons') && ...
       ~isempty(sample.decision.reviewReasons)
        lines(end+1) = " Warning/Review Flags:";
        for r = 1:numel(sample.decision.reviewReasons)
            lines(end+1) = sprintf("   * %s", sample.decision.reviewReasons{r});
        end
    end

    lines(end+1) = "--------------------------------------------------------------------------";
    lines(end+1) = " NOTICE: This automated screening report provides clinical decision support";
    lines(end+1) = "         and does not constitute a final diagnosis without physician review.";
    lines(end+1) = "==========================================================================";

    reportText = strjoin(lines, newline);
end
