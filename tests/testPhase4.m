function results = testPhase4()
% TESTPHASE4 Comprehensive test harness for Phase 4: Retinal Structure Analysis.
%
% Tests:
%   1. Optic Disc detection: center, radius, and binary mask.
%   2. Retinal Vessel segmentation: multi-scale morphological response & density.
%   3. Fovea localization: anatomical distance, temporal direction, and laterality.
%   4. Visual anatomical map generation: composite RGB overlay.
%   5. Pipeline integration: population of sample.anatomy struct schema.

    fprintf('====================================================\n');
    fprintf('           RUNNING PHASE 4 UNIT TESTS               \n');
    fprintf('====================================================\n\n');

    testsPassed = 0;
    totalTests  = 0;

    % Generate standard synthetic fundus (512x512)
    H = 512; W = 512;
    img = generateSyntheticFundus(H, W, 'Quality', 'good');
    [~, ~, retinaMask] = assessFOV(img);

    % Test 1: Optic Disc Localization
    totalTests = totalTests + 1;
    fprintf('[Test %d] Testing Optic Disc localization (locateOpticDisc)... ', totalTests);
    [odStruct, odMask] = locateOpticDisc(img, retinaMask);

    odDetected = ~any(isnan(odStruct.center)) && odStruct.radius > 5 && ...
                 odStruct.center(1) > (W / 2) && ... % Nasal side (right of center in synthetic image)
                 sum(odMask(:)) > 50;

    if odDetected
        fprintf('PASSED (Center: [%.1f, %.1f], Radius: %.1f px)\n', ...
            odStruct.center(1), odStruct.center(2), odStruct.radius);
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED (Center: [%.1f, %.1f])\n', odStruct.center(1), odStruct.center(2));
    end

    % Test 2: Vessel Segmentation
    totalTests = totalTests + 1;
    fprintf('[Test %d] Testing Blood Vessel segmentation (segmentVessels)... ', totalTests);
    [vesselMask, vesselMetrics] = segmentVessels(img, retinaMask);

    vesselsValid = sum(vesselMask(:)) > 100 && ...
                   vesselMetrics.density > 0.01 && vesselMetrics.density < 0.40 && ...
                   all(~vesselMask(~retinaMask)); % Strictly confined inside retina

    if vesselsValid
        fprintf('PASSED (Vessel Density: %.2f%%, Pixels: %d)\n', ...
            vesselMetrics.density * 100, vesselMetrics.totalVesselPixels);
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED (Density: %.2f%%, Outside Mask: %d)\n', ...
            vesselMetrics.density * 100, any(vesselMask(~retinaMask)));
    end

    % Test 3: Fovea Localization
    totalTests = totalTests + 1;
    fprintf('[Test %d] Testing Fovea localization (locateFovea)... ', totalTests);
    foveaStruct = locateFovea(img, odStruct, vesselMask, retinaMask);

    % Fovea must be temporal (to the left of OD in right eye)
    foveaValid = ~any(isnan(foveaStruct.center)) && ...
                 foveaStruct.center(1) < odStruct.center(1) && ... % Temporal to OD
                 foveaStruct.discToFoveaDistance > odStruct.radius && ...
                 foveaStruct.laterality == "OD";

    if foveaValid
        fprintf('PASSED (Center: [%.1f, %.1f], OD-Fovea Dist: %.1f px, Laterality: %s)\n', ...
            foveaStruct.center(1), foveaStruct.center(2), ...
            foveaStruct.discToFoveaDistance, foveaStruct.laterality);
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED (Center: [%.1f, %.1f], Dist: %.1f)\n', ...
            foveaStruct.center(1), foveaStruct.center(2), foveaStruct.discToFoveaDistance);
    end

    % Test 4: Visual Anatomical Map Overlay
    totalTests = totalTests + 1;
    fprintf('[Test %d] Testing anatomical overlay visualization (visualizeAnatomy)... ', totalTests);
    anatomyDummy = struct('opticDisc', odStruct, 'fovea', foveaStruct, ...
                          'vessels', struct('mask', vesselMask));
    overlay = visualizeAnatomy(img, anatomyDummy);

    overlayValid = isequal(size(overlay), [H, W, 3]) && ...
                   isa(overlay, 'uint8') && ...
                   ~isequal(overlay, img); % Must have modifications from markers

    if overlayValid
        fprintf('PASSED (Generated [%dx%dx%d] RGB overlay)\n', size(overlay, 1), size(overlay, 2), size(overlay, 3));
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED\n');
    end

    % Test 5: Pipeline Integration with sample struct
    totalTests = totalTests + 1;
    fprintf('[Test %d] Testing master pipeline coordinator (analyzeRetinalStructures)... ', totalTests);
    sample = loadFundusImage(img, 'PatientID', "pt_anatomy_test");
    sample = assessImageQuality(sample);
    sample = enhanceFundusImage(sample);
    sample = analyzeRetinalStructures(sample);

    hasAnatomyFields = isfield(sample.anatomy, {'opticDisc', 'fovea', 'vessels', 'overlay'});
    schemaValid = all(hasAnatomyFields) && ...
                  ~isempty(sample.anatomy.vessels.mask) && ...
                  ~isempty(sample.anatomy.overlay);

    if schemaValid
        fprintf('PASSED (sample.anatomy properly populated)\n');
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED (Missing fields in sample.anatomy)\n');
    end

    % Summary
    fprintf('\n====================================================\n');
    fprintf('Phase 4 Test Summary: %d / %d tests passed (%.1f%%)\n', ...
        testsPassed, totalTests, (testsPassed / totalTests) * 100);
    fprintf('====================================================\n');

    results = struct('passed', testsPassed, 'total', totalTests);
end
