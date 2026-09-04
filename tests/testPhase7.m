function results = testPhase7()
% TESTPHASE7 Comprehensive test harness for Phase 7: Explainability and Grad-CAM.
%
% Tests:
%   1. Heatmap computation: dimensions [H, W], normalized [0.0, 1.0], retina-masked.
%   2. Alpha blending: 3-channel uint8 composite overlay generation.
%   3. Target class selection: default predicted class vs. explicit class parameter.
%   4. Master pipeline integration: sample.gradCAM schema verification.

    fprintf('====================================================\n');
    fprintf('           RUNNING PHASE 7 UNIT TESTS               \n');
    fprintf('====================================================\n\n');

    testsPassed = 0;
    totalTests  = 0;

    H = 512; W = 512;
    img = generateSyntheticFundus(H, W, 'Quality', 'good', 'Lesions', 'moderate');
    [~, ~, retinaMask] = assessFOV(img);
    model = loadDRModel("mock");

    % Test 1: Heatmap Generation & Normalization
    totalTests = totalTests + 1;
    fprintf('[Test %d] Testing Grad-CAM 2D Heatmap (computeGradCAMMap)... ', totalTests);
    heatmap = computeGradCAMMap(model, img, 2);

    mapValid = isequal(size(heatmap), [H, W]) && ...
               max(heatmap(:)) <= 1.0 && min(heatmap(:)) >= 0.0 && ...
               all(~heatmap(~retinaMask)); % Strictly 0 outside retina

    if mapValid
        fprintf('PASSED (Size: [%dx%d], Range: [%.2f, %.2f])\n', ...
            size(heatmap, 1), size(heatmap, 2), min(heatmap(:)), max(heatmap(:)));
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED\n');
    end

    % Test 2: Heatmap Blending Overlay
    totalTests = totalTests + 1;
    fprintf('[Test %d] Testing Alpha Blending Overlay (overlayHeatmap)... ', totalTests);
    overlay = overlayHeatmap(img, heatmap, 'Alpha', 0.45, 'RetinaMask', retinaMask);

    overlayValid = isequal(size(overlay), [H, W, 3]) && ...
                   isa(overlay, 'uint8') && ...
                   ~isequal(overlay, img);

    if overlayValid
        fprintf('PASSED (Generated [%dx%dx%d] RGB overlay)\n', ...
            size(overlay, 1), size(overlay, 2), size(overlay, 3));
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED\n');
    end

    % Test 3: Master Pipeline Integration with sample struct
    totalTests = totalTests + 1;
    fprintf('[Test %d] Testing master explainability engine (generateGradCAM)... ', totalTests);
    sample = loadFundusImage(img, 'PatientID', "pt_gradcam_test");
    sample = assessImageQuality(sample);
    sample = enhanceFundusImage(sample);
    sample = analyzeRetinalStructures(sample);
    sample = detectLesionEvidence(sample);
    sample = runDRModel(model, sample);
    sample = generateGradCAM(model, sample);

    hasFields = isfield(sample.gradCAM, ...
        {'heatmap', 'overlay', 'targetClass', 'classLabel', 'targetLayer', 'explanation'});
    schemaValid = all(hasFields) && ...
                  ~isempty(sample.gradCAM.overlay) && ...
                  sample.gradCAM.targetClass == sample.prediction.predictedClass;

    if schemaValid
        fprintf('PASSED (sample.gradCAM populated for Predicted Class %d "%s")\n', ...
            sample.gradCAM.targetClass, sample.gradCAM.classLabel);
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED (Missing fields or targetClass mismatch)\n');
    end

    % Test 4: Explicit Class Target Override
    totalTests = totalTests + 1;
    fprintf('[Test %d] Testing explicit TargetClass override (Class 4 PDR)... ', totalTests);
    samplePDR = generateGradCAM(model, sample, 'TargetClass', 4);

    if samplePDR.gradCAM.targetClass == 4 && samplePDR.gradCAM.classLabel == "Proliferative DR"
        fprintf('PASSED (TargetClass correctly set to 4 - "Proliferative DR")\n');
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED\n');
    end

    % Summary
    fprintf('\n====================================================\n');
    fprintf('Phase 7 Test Summary: %d / %d tests passed (%.1f%%)\n', ...
        testsPassed, totalTests, (testsPassed / totalTests) * 100);
    fprintf('====================================================\n');

    results = struct('passed', testsPassed, 'total', totalTests);
end
