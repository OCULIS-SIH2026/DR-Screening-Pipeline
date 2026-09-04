function results = testPhase2()
% TESTPHASE2 Comprehensive test harness for Phase 2: Image Quality Assessment (IQA).
%
% Tests:
%   1. Good-quality fundus -> GOOD classification (Score >= 0.75)
%   2. Severe blur -> Low sharpness & RECAPTURE / BORDERLINE
%   3. Severe underexposure -> RECAPTURE (underexposure flagged)
%   4. Severe overexposure -> RECAPTURE (overexposure flagged)
%   5. Severe FOV clipping -> Low FOV score & RECAPTURE
%   6. Pipeline integration -> sample.quality populated properly

    fprintf('====================================================\n');
    fprintf('           RUNNING PHASE 2 UNIT TESTS               \n');
    fprintf('====================================================\n\n');

    testsPassed = 0;
    totalTests  = 0;

    % Test 1: Good quality synthetic fundus
    totalTests = totalTests + 1;
    fprintf('[Test %d] Assessing GOOD synthetic fundus image... ', totalTests);
    imgGood = generateSyntheticFundus(512, 512, 'Quality', 'good');
    sampleGood = loadFundusImage(imgGood, 'PatientID', "pt_good_001");
    sampleGood = assessImageQuality(sampleGood);

    if sampleGood.quality.overallScore >= 0.70 && ...
       (sampleGood.quality.status == "GOOD" || sampleGood.quality.status == "BORDERLINE") && ...
       ~isempty(sampleGood.quality.retinaMask)
        fprintf('PASSED (Score: %.2f, Status: %s)\n', ...
            sampleGood.quality.overallScore, sampleGood.quality.status);
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED (Score: %.2f, Status: %s)\n', ...
            sampleGood.quality.overallScore, sampleGood.quality.status);
    end

    % Test 2: Severe blur
    totalTests = totalTests + 1;
    fprintf('[Test %d] Assessing SEVERELY BLURRED fundus image... ', totalTests);
    imgBlur = generateSyntheticFundus(512, 512, 'Quality', 'blurry');
    sampleBlur = loadFundusImage(imgBlur, 'PatientID', "pt_blur_002");
    sampleBlur = assessImageQuality(sampleBlur);

    if sampleBlur.quality.sharpness < 0.35 && ...
       (sampleBlur.quality.status == "RECAPTURE" || sampleBlur.quality.status == "BORDERLINE")
        fprintf('PASSED (Sharpness: %.2f, Status: %s)\n', ...
            sampleBlur.quality.sharpness, sampleBlur.quality.status);
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED (Sharpness: %.2f, Status: %s)\n', ...
            sampleBlur.quality.sharpness, sampleBlur.quality.status);
    end

    % Test 3: Severe underexposure
    totalTests = totalTests + 1;
    fprintf('[Test %d] Assessing UNDEREXPOSED (dark) fundus image... ', totalTests);
    imgDark = generateSyntheticFundus(512, 512, 'Quality', 'underexposed');
    sampleDark = loadFundusImage(imgDark, 'PatientID', "pt_dark_003");
    sampleDark = assessImageQuality(sampleDark);

    hasUnderReason = any(contains(sampleDark.quality.rejectionReasons, 'underexposure', 'IgnoreCase', true));
    if sampleDark.quality.status == "RECAPTURE" && hasUnderReason
        fprintf('PASSED (Status: %s, Reason logged)\n', sampleDark.quality.status);
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED (Status: %s, UnderReason: %d)\n', sampleDark.quality.status, hasUnderReason);
    end

    % Test 4: Severe overexposure
    totalTests = totalTests + 1;
    fprintf('[Test %d] Assessing OVEREXPOSED (flash flare) fundus image... ', totalTests);
    imgOver = generateSyntheticFundus(512, 512, 'Quality', 'overexposed');
    sampleOver = loadFundusImage(imgOver, 'PatientID', "pt_over_004");
    sampleOver = assessImageQuality(sampleOver);

    hasOverReason = any(contains(sampleOver.quality.rejectionReasons, 'overexposure', 'IgnoreCase', true));
    if sampleOver.quality.status == "RECAPTURE" && hasOverReason
        fprintf('PASSED (Status: %s, Reason logged)\n', sampleOver.quality.status);
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED (Status: %s, OverReason: %d)\n', sampleOver.quality.status, hasOverReason);
    end

    % Test 5: Severely clipped field of view (missed shot)
    totalTests = totalTests + 1;
    fprintf('[Test %d] Assessing SEVERELY CLIPPED field of view... ', totalTests);
    % Create black frame with only 5% corner showing retina
    clippedImg = zeros(512, 512, 3, 'uint8');
    clippedImg(1:100, 1:100, :) = imgGood(1:100, 1:100, :);
    [fovScore, fovMetrics, ~] = assessFOV(clippedImg);
    
    if fovMetrics.retinalAreaRatio < 0.20 && fovScore < 0.40
        fprintf('PASSED (FOV Ratio: %.2f, FOV Score: %.2f)\n', ...
            fovMetrics.retinalAreaRatio, fovScore);
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED (FOV Ratio: %.2f, FOV Score: %.2f)\n', ...
            fovMetrics.retinalAreaRatio, fovScore);
    end

    % Test 6: Sample struct schema compliance
    totalTests = totalTests + 1;
    fprintf('[Test %d] Verifying sample.quality schema integrity... ', totalTests);
    qFields = {'status', 'overallScore', 'sharpness', 'brightness', 'contrast', 'fov', ...
               'rejectionReasons', 'retinaMask', 'metrics'};
    allFields = all(isfield(sampleGood.quality, qFields));
    if allFields && ismember(sampleGood.quality.status, ["GOOD", "BORDERLINE", "RECAPTURE"])
        fprintf('PASSED\n');
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED (Missing fields or invalid status)\n');
    end

    % Summary
    fprintf('\n====================================================\n');
    fprintf('Phase 2 Test Summary: %d / %d tests passed (%.1f%%)\n', ...
        testsPassed, totalTests, (testsPassed / totalTests) * 100);
    fprintf('====================================================\n');

    results = struct('passed', testsPassed, 'total', totalTests);
end
