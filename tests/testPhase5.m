function results = testPhase5()
% TESTPHASE5 Comprehensive test harness for Phase 5: Lesion Detection & Clinical Evidence.
%
% Tests:
%   1. Exudate detection: bright lipid plaques detected; Optic Disc strictly masked out.
%   2. Microaneurysm detection: focal dark capillary lesions detected; vessels excluded.
%   3. Hemorrhage detection: larger dark red blot lesions detected.
%   4. Neovascularization screening: baseline normal vs. abnormal branching.
%   5. Visual lesion overlay: multi-color annotated clinical map.
%   6. Master pipeline integration: population of sample.lesionEvidence schema.

    fprintf('====================================================\n');
    fprintf('           RUNNING PHASE 5 UNIT TESTS               \n');
    fprintf('====================================================\n\n');

    testsPassed = 0;
    totalTests  = 0;

    % Generate synthetic fundus with moderate DR lesions (512x512)
    H = 512; W = 512;
    imgLesions = generateSyntheticFundus(H, W, 'Quality', 'good', 'Lesions', 'moderate');
    [~, ~, retinaMask] = assessFOV(imgLesions);
    [odStruct, odMask] = locateOpticDisc(imgLesions, retinaMask);
    [vesselMask, ~]    = segmentVessels(imgLesions, retinaMask);

    % Test 1: Exudate Detection & Optic Disc Exclusion
    totalTests = totalTests + 1;
    fprintf('[Test %d] Testing Exudates & Optic Disc exclusion (detectExudates)... ', totalTests);
    [exMask, exCandidates, exMetrics] = detectExudates(imgLesions, retinaMask, odMask);

    % Exudates must be detected, AND zero pixels inside the optic disc can be marked as exudates!
    noODFalsePositive = ~any(exMask(odMask));
    exValid = exMetrics.count >= 1 && noODFalsePositive;

    if exValid
        fprintf('PASSED (Found: %d candidates, OD false-positives: 0)\n', exMetrics.count);
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED (Found: %d, OD false-positive overlap: %d)\n', ...
            exMetrics.count, sum(exMask(odMask)));
    end

    % Test 2: Microaneurysm Detection
    totalTests = totalTests + 1;
    fprintf('[Test %d] Testing Microaneurysm candidate detection (detectMicroaneurysms)... ', totalTests);
    [maMask, maCandidates, maMetrics] = detectMicroaneurysms(imgLesions, retinaMask, vesselMask, odMask);

    % MAs must not overlap with center of blood vessels
    vesselOverlap = sum(maMask(vesselMask));
    maValid = maMetrics.count >= 1 && vesselOverlap == 0;

    if maValid
        fprintf('PASSED (Found: %d candidates, Vessel overlap: 0)\n', maMetrics.count);
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED (Found: %d, Vessel overlap: %d)\n', maMetrics.count, vesselOverlap);
    end

    % Test 3: Hemorrhage Detection
    totalTests = totalTests + 1;
    fprintf('[Test %d] Testing Hemorrhage candidate detection (detectHemorrhages)... ', totalTests);
    [haMask, haCandidates, haMetrics] = detectHemorrhages(imgLesions, retinaMask, vesselMask, odMask);

    haValid = haMetrics.count >= 1 && sum(haMask(:)) > 30;

    if haValid
        fprintf('PASSED (Found: %d candidates, Total Area: %d px)\n', ...
            haMetrics.count, haMetrics.totalArea);
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED (Found: %d)\n', haMetrics.count);
    end

    % Test 4: Neovascularization Baseline Check
    totalTests = totalTests + 1;
    fprintf('[Test %d] Testing Neovascularization screening baseline... ', totalTests);
    [isNV, nvMask, nvMetrics] = detectNeovascularization(vesselMask, odStruct, retinaMask);

    % Normal synthetic vessel tree should not trigger chaotic PDR neovascularization
    if ~isNV && nvMetrics.type == "NONE"
        fprintf('PASSED (Normal baseline correctly identified as non-proliferative)\n');
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED (False alarm on baseline)\n');
    end

    % Test 5: Visual Lesion Overlay
    totalTests = totalTests + 1;
    fprintf('[Test %d] Testing color-coded lesion candidate overlay (visualizeLesions)... ', totalTests);
    evidenceDummy = struct( ...
        'microaneurysms',   struct('candidates', maCandidates), ...
        'hemorrhages',      struct('mask', haMask), ...
        'exudates',         struct('mask', exMask), ...
        'neovascularization', struct('mask', nvMask) ...
    );
    overlay = visualizeLesions(imgLesions, evidenceDummy);

    overlayValid = isequal(size(overlay), [H, W, 3]) && ...
                   isa(overlay, 'uint8') && ...
                   ~isequal(overlay, imgLesions);

    if overlayValid
        fprintf('PASSED (Generated [%dx%dx%d] RGB overlay)\n', size(overlay, 1), size(overlay, 2), size(overlay, 3));
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED\n');
    end

    % Test 6: Master Pipeline Integration with sample struct
    totalTests = totalTests + 1;
    fprintf('[Test %d] Testing master lesion coordinator (detectLesionEvidence)... ', totalTests);
    sample = loadFundusImage(imgLesions, 'PatientID', "pt_lesion_test");
    sample = assessImageQuality(sample);
    sample = enhanceFundusImage(sample);
    sample = analyzeRetinalStructures(sample);
    sample = detectLesionEvidence(sample);

    hasEvidenceFields = isfield(sample.lesionEvidence, ...
        {'microaneurysms', 'hemorrhages', 'exudates', 'neovascularization', 'totalLesions', 'overlay'});
    schemaValid = all(hasEvidenceFields) && ...
                  isnumeric(sample.lesionEvidence.totalLesions) && ...
                  ~isempty(sample.lesionEvidence.overlay);

    if schemaValid
        fprintf('PASSED (sample.lesionEvidence properly populated, Total Candidates: %d)\n', ...
            sample.lesionEvidence.totalLesions);
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED (Missing fields in sample.lesionEvidence)\n');
    end

    % Summary
    fprintf('\n====================================================\n');
    fprintf('Phase 5 Test Summary: %d / %d tests passed (%.1f%%)\n', ...
        testsPassed, totalTests, (testsPassed / totalTests) * 100);
    fprintf('====================================================\n');

    results = struct('passed', testsPassed, 'total', totalTests);
end
