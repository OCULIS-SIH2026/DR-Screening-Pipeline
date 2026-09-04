function referralStruct = determineReferral(predictedClass, calibratedProbs, varargin)
% DETERMINEREFERRAL Maps 5-level prediction into clinical referral categories.
%
% Clinical Triage Protocol:
%   - Level 0 (No DR):        Non-referable -> Routine annual screening (12 months)
%   - Level 1 (Mild NPDR):    Non-referable -> Follow-up screening (6-12 months)
%   - Level 2 (Moderate NPDR): Referable    -> Ophthalmologist review (2-3 months)
%   - Level 3 (Severe NPDR):   Referable    -> Ophthalmologist review (4 weeks)
%   - Level 4 (Proliferative): Referable    -> URGENT Ophthalmic evaluation (1-2 weeks)
%
% Usage:
%   referral = determineReferral(predictedClass, calibratedProbs)
%
% Outputs:
%   referralStruct - Struct containing:
%                      .isReferable          (true / false)
%                      .referableProbability (sum of P(2)+P(3)+P(4))
%                      .isUrgent             (true if Level 4 PDR)
%                      .referralCategory     ("REFERABLE" / "NON_REFERABLE")
%                      .urgencyLevel         ("ROUTINE", "SEMI_URGENT", "URGENT")
%                      .recommendedTimeframe ("12 months", "4 weeks", etc.)
%
% Reference:
%   Phase 8: Confidence, Referable DR, and Decision Logic

    p = inputParser;
    addRequired(p, 'predictedClass', @isnumeric);
    addRequired(p, 'calibratedProbs', @(x) isnumeric(x) && numel(x) == 5);
    parse(p, predictedClass, calibratedProbs, varargin{:});

    probs = double(reshape(calibratedProbs, [1, 5]));
    c = round(predictedClass);

    % 1. Binary Referable DR Decision Rule: Class >= 2
    isReferable = (c >= 2);

    % Total probability mass assigned to referable stages (Levels 2, 3, 4)
    refProb = sum(probs(3:5)); % Index 3 = Level 2, 4 = Level 3, 5 = Level 4

    % If cumulative referable probability >= 0.50, flag referable for clinical safety
    if refProb >= 0.50
        isReferable = true;
    end

    % 2. Urgency and Recommended Clinical Timeframe
    switch c
        case 4
            urgencyLevel = "URGENT";
            isUrgent = true;
            timeframe = "1 to 2 weeks (Immediate specialist evaluation for panretinal photocoagulation / anti-VEGF)";
            actionText = "URGENT_OPHTHALMOLOGY_REFERRAL";
        case 3
            urgencyLevel = "SEMI_URGENT";
            isUrgent = false;
            timeframe = "Within 4 weeks (High risk of progression to proliferative stage)";
            actionText = "PRIORITY_OPHTHALMOLOGY_REFERRAL";
        case 2
            urgencyLevel = "ROUTINE_REFERRAL";
            isUrgent = false;
            timeframe = "Within 8 to 12 weeks for detailed dilated ophthalmoscopy";
            actionText = "STANDARD_OPHTHALMOLOGY_REFERRAL";
        case 1
            urgencyLevel = "MONITORING";
            isUrgent = false;
            timeframe = "Re-screen in 6 to 12 months; optimize glycemic and blood pressure control";
            actionText = "ROUTINE_PRIMARY_CARE_MONITORING";
        otherwise % 0: No DR
            urgencyLevel = "ROUTINE";
            isUrgent = false;
            timeframe = "Annual routine DR screening in 12 months";
            actionText = "ANNUAL_SCREENING_FOLLOW_UP";
    end

    referralCategory = "NON_REFERABLE";
    if isReferable
        referralCategory = "REFERABLE";
    end

    referralStruct = struct();
    referralStruct.isReferable          = isReferable;
    referralStruct.referableProbability = round(refProb, 4);
    referralStruct.isUrgent             = isUrgent;
    referralStruct.referralCategory     = referralCategory;
    referralStruct.urgencyLevel         = urgencyLevel;
    referralStruct.recommendedTimeframe = timeframe;
    referralStruct.actionText           = actionText;
end
