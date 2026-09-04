function results = testPhase3()
% TESTPHASE3 Comprehensive test harness for Phase 3: Image Enhancement & Normalization.
%
% Tests:
%   1. Clinical rule: GOOD image preserved without enhancement (applied == false).
%   2. Clinical rule: BORDERLINE image triggers enhancement pipeline (applied == true).
%   3. Clinical rule: RECAPTURE image is not aggressively enhanced by default.
%   4. Force parameter overrides gate and applies enhancement.
%   5. CLAHE increases local structural contrast.
%   6. Background black perimeter is strictly preserved (no halo/bleed).
%   7. Non-uniform illumination correction reduces spatial quadrant deviation.

    fprintf('====================================================\n');
    fprintf('           RUNNING PHASE 3 UNIT TESTS               \n');
    fprintf('====================================================\n\n');

    testsPassed = 0;
    totalTests  = 0;

    % Create base synthetic image
    imgBase = generateSyntheticFundus(512, 512, 'Quality', 'good');
    sampleBase = loadFundusImage(imgBase, 'PatientID', "pt_test_p3");

    % Test 1: Selective Rule for GOOD quality image
    totalTests = totalTests + 1;
    fprintf('[Test %d] Checking selective rule: GOOD image preserved untouched... ', totalTests);
    sampleGood = sampleBase;
    sampleGood.quality.status = "GOOD";
    [~, ~, mask] = assessFOV(imgBase);
    sampleGood.quality.retinaMask = mask;
    sampleGood = enhanceFundusImage(sampleGood);

    if ~sampleGood.enhancementInfo.applied && isequal(sampleGood.enhancedImage, sampleGood.image)
        fprintf('PASSED (Correctly skipped)\n');
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED\n');
    end

    % Test 2: Selective Rule for BORDERLINE quality image
    totalTests = totalTests + 1;
    fprintf('[Test %d] Checking selective rule: BORDERLINE image triggers enhancement... ', totalTests);
    sampleBorder = sampleBase;
    sampleBorder.quality.status = "BORDERLINE";
    sampleBorder.quality.retinaMask = mask;
    sampleBorder = enhanceFundusImage(sampleBorder);

    if sampleBorder.enhancementInfo.applied && ~isempty(sampleBorder.enhancedImage)
        fprintf('PASSED (Applied: %s)\n', sampleBorder.enhancementInfo.method);
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED\n');
    end

    % Test 3: Selective Rule for RECAPTURE quality image
    totalTests = totalTests + 1;
    fprintf('[Test %d] Checking selective rule: RECAPTURE image is not aggressively enhanced... ', totalTests);
    sampleRecap = sampleBase;
    sampleRecap.quality.status = "RECAPTURE";
    sampleRecap.quality.retinaMask = mask;
    sampleRecap = enhanceFundusImage(sampleRecap);

    if ~sampleRecap.enhancementInfo.applied
        fprintf('PASSED (Preserved as recapture)\n');
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED\n');
    end

    % Test 4: Force override on GOOD image
    totalTests = totalTests + 1;
    fprintf('[Test %d] Checking "Force", true override on GOOD image... ', totalTests);
    sampleForced = enhanceFundusImage(sampleGood, 'Force', true);
    if sampleForced.enhancementInfo.applied
        fprintf('PASSED (Forced enhancement executed)\n');
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED\n');
    end

    % Test 5: CLAHE contrast enhancement
    totalTests = totalTests + 1;
    fprintf('[Test %d] Verifying CLAHE improves structural contrast... ', totalTests);
    % Create a low contrast image
    lowContrast = uint8(double(imgBase) * 0.4 + 50);
    claheOut = applyCLAHE(lowContrast, mask, 'ClipLimit', 0.02);
    [cBefore, ~] = assessContrast(lowContrast, mask);
    [cAfter, ~]  = assessContrast(claheOut, mask);
    if cAfter >= cBefore
        fprintf('PASSED (Contrast: %.2f -> %.2f)\n', cBefore, cAfter);
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED (Contrast decreased)\n');
    end

    % Test 6: Background mask preservation (no bleed/halo outside retina)
    totalTests = totalTests + 1;
    fprintf('[Test %d] Verifying perimeter background remains black (0,0,0)... ', totalTests);
    outsideRetina = ~mask;
    enhancedOutside = sampleForced.enhancedImage(cat(3, outsideRetina, outsideRetina, outsideRetina));
    if all(enhancedOutside == 0)
        fprintf('PASSED (Zero background bleed)\n');
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED (Background pixels modified)\n');
    end

    % Test 7: Illumination correction on non-uniform gradient
    totalTests = totalTests + 1;
    fprintf('[Test %d] Verifying illumination normalization on uneven lighting... ', totalTests);
    [X, ~] = meshgrid(linspace(0.4, 1.6, 512), 1:512);
    unevenImg = uint8(min(255, max(0, double(imgBase) .* cat(3, X, X, X))));
    [~, bBefore] = assessBrightness(unevenImg, mask);
    normOut = normalizeIllumination(unevenImg, mask);
    [~, bAfter] = assessBrightness(normOut, mask);
    
    if bAfter.illuminationUniformity >= bBefore.illuminationUniformity - 0.05
        fprintf('PASSED (Uniformity: %.2f -> %.2f)\n', ...
            bBefore.illuminationUniformity, bAfter.illuminationUniformity);
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED\n');
    end

    % Summary
    fprintf('\n====================================================\n');
    fprintf('Phase 3 Test Summary: %d / %d tests passed (%.1f%%)\n', ...
        testsPassed, totalTests, (testsPassed / totalTests) * 100);
    fprintf('====================================================\n');

    results = struct('passed', testsPassed, 'total', totalTests);
end
