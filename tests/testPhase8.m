function results = testPhase8()
% TESTPHASE8 Comprehensive test harness for Phase 8: Confidence & Clinical Decision Logic.
%
% Tests:
%   1. Probability calibration via temperature scaling and predictive entropy.
%   2. Binary Referable DR triage: Level 0/1 (Non-referable) vs. Level 2/3/4 (Referable).
%   3. Clinical urgency classification: Level 4 PDR flagged as URGENT.
%   4. Uncertainty & contradiction safety gating (Model vs. Lesions contradiction).
%   5. Master decision coordinator integration: sample.decision schema verification.
%   6. Clinical performance evaluation: sensitivity > 90%, specificity > 85%, confusion matrices.

    fprintf('====================================================\n');
    fprintf('           RUNNING PHASE 8 UNIT TESTS               \n');
    fprintf('====================================================\n\n');

    testsPassed = 0;
    totalTests  = 0;

    % Test 1: Probability Calibration & Entropy
    totalTests = totalTests + 1;
    fprintf('[Test %d] Testing Probability Calibration & Entropy (calibrateConfidence)... ', totalTests);
    rawProbs = [0.02, 0.08, 0.72, 0.15, 0.03];
    [calProbs, conf, entropyVal] = calibrateConfidence(rawProbs, 'Temperature', 1.25);

    calValid = numel(calProbs) == 5 && ...
               abs(sum(calProbs) - 1.0) < 0.01 && ...
               conf <= max(rawProbs) && ... % Temperature softens extreme peaks
               entropyVal >= 0.0 && entropyVal <= 1.0;

    if calValid
        fprintf('PASSED (Confidence: %.1f%%, Entropy: %.2f)\n', conf * 100, entropyVal);
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED\n');
    end

    % Test 2: Binary Referable DR Decision Triage
    totalTests = totalTests + 1;
    fprintf('[Test %d] Testing Referable vs. Non-Referable Triage (determineReferral)... ', totalTests);
    ref0 = determineReferral(0, [0.85, 0.10, 0.03, 0.01, 0.01]); % No DR
    ref1 = determineReferral(1, [0.10, 0.75, 0.10, 0.03, 0.02]); % Mild NPDR
    ref2 = determineReferral(2, [0.02, 0.08, 0.72, 0.15, 0.03]); % Moderate NPDR
    ref4 = determineReferral(4, [0.01, 0.01, 0.03, 0.15, 0.80]); % Proliferative DR

    triageValid = (~ref0.isReferable) && ...
                  (~ref1.isReferable) && ...
                  (ref2.isReferable) && ...
                  (ref4.isReferable) && ...
                  (ref4.isUrgent); % Level 4 must be flagged URGENT

    if triageValid
        fprintf('PASSED (L0/L1: Non-referable, L2: Referable, L4: Urgent Referable)\n');
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED\n');
    end

    % Test 3: Contradiction Safety Gating (Model says No DR, but lesions exist)
    totalTests = totalTests + 1;
    fprintf('[Test %d] Testing Model-vs-Evidence Contradiction Audit (applyClinicalGate)... ', totalTests);
    dummySample = struct();
    dummySample.quality = struct('status', "GOOD");
    dummySample.prediction = struct('predictedClass', 0, 'probabilities', [0.80, 0.10, 0.05, 0.03, 0.02]);
    % Inject lesion evidence: physical hemorrhages found
    dummySample.lesionEvidence = struct( ...
        'hemorrhages', struct('count', 3), ...
        'exudates', struct('count', 1), ...
        'microaneurysms', struct('count', 4), ...
        'neovascularization', struct('detected', false) ...
    );
    gate = applyClinicalGate(dummySample);

    if gate.needsHumanReview && gate.isContradiction
        fprintf('PASSED (Contradiction caught: %s)\n', gate.reviewReasons{1});
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED (Missed contradiction)\n');
    end

    % Test 4: Master Decision Engine Integration
    totalTests = totalTests + 1;
    fprintf('[Test %d] Testing master decision coordinator (makeClinicalDecision)... ', totalTests);
    img = generateSyntheticFundus(512, 512, 'Quality', 'good', 'Lesions', 'moderate');
    model = loadDRModel("mock");
    sample = loadFundusImage(img, 'PatientID', "pt_decision_test");
    sample = assessImageQuality(sample);
    sample = enhanceFundusImage(sample);
    sample = analyzeRetinalStructures(sample);
    sample = detectLesionEvidence(sample);
    sample = runDRModel(model, sample);
    sample = makeClinicalDecision(sample);

    dFields = {'isReferable', 'referableCategory', 'referableProbability', ...
               'confidence', 'calibratedProbs', 'entropy', 'isUrgent', ...
               'urgencyLevel', 'actionRequired', 'needsHumanReview'};
    schemaValid = all(isfield(sample.decision, dFields));

    if schemaValid && sample.decision.isReferable
        fprintf('PASSED (sample.decision populated, Referable: YES, Confidence: %.1f%%)\n', ...
            sample.decision.confidence * 100);
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED\n');
    end

    % Test 5: Clinical Screening Metrics Evaluation (Sensitivity > 90%, Specificity > 85%)
    totalTests = totalTests + 1;
    fprintf('[Test %d] Testing Clinical Diagnostic Targets (evaluateClinicalMetrics)... ', totalTests);
    % Synthetic validation cohort: 100 cases
    % 40 non-referable (0, 1) and 60 referable (2, 3, 4)
    yTrue = [zeros(25, 1); ones(15, 1); 2*ones(25, 1); 3*ones(20, 1); 4*ones(15, 1)];
    yPred = yTrue;
    % Introduce realistic minor misclassifications (3 false negatives, 3 false positives)
    yPred(1) = 2; yPred(2) = 2; yPred(3) = 2; % False positives
    yPred(41) = 1; yPred(42) = 1; yPred(43) = 1; % False negatives (out of 60 referable = 57/60 = 95.0% sens)

    metrics = evaluateClinicalMetrics(yTrue, yPred);

    metricsValid = metrics.sensitivity >= 0.90 && ...
                   metrics.specificity >= 0.85 && ...
                   metrics.meetsClinicalTarget && ...
                   isequal(size(metrics.confusionMatrix2x2), [2, 2]) && ...
                   isequal(size(metrics.confusionMatrix5x5), [5, 5]);

    if metricsValid
        fprintf('PASSED (Sens: %.1f%% > 90%%, Spec: %.1f%% > 85%%, F1: %.3f)\n', ...
            metrics.sensitivity * 100, metrics.specificity * 100, metrics.f1Score);
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED (Sens: %.1f%%, Spec: %.1f%%)\n', ...
            metrics.sensitivity * 100, metrics.specificity * 100);
    end

    % Summary
    fprintf('\n====================================================\n');
    fprintf('Phase 8 Test Summary: %d / %d tests passed (%.1f%%)\n', ...
        testsPassed, totalTests, (testsPassed / totalTests) * 100);
    fprintf('====================================================\n');

    results = struct('passed', testsPassed, 'total', totalTests);
end
