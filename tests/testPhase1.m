function results = testPhase1()
% TESTPHASE1 Test harness for Phase 1: Input and Data Interface.
%
% Runs comprehensive checks on:
%   - Struct initialization
%   - RGB, Grayscale, RGBA, and Floating-point inputs
%   - File validation & loading (JPG/PNG)
%   - Target resizing (standard & aspect-ratio letterboxing)
%   - Metadata preservation

    fprintf('====================================================\n');
    fprintf('           RUNNING PHASE 1 UNIT TESTS               \n');
    fprintf('====================================================\n\n');

    testsPassed = 0;
    totalTests  = 0;

    % Test 1: Struct Schema Creation
    totalTests = totalTests + 1;
    fprintf('[Test %d] Checking createSampleStruct schema... ', totalTests);
    sample = createSampleStruct();
    expectedFields = {'imageID', 'filePath', 'originalImage', 'originalSize', ...
                      'image', 'currentSize', 'metadata', 'quality', 'enhancedImage', ...
                      'anatomy', 'lesionEvidence', 'prediction', 'gradCAM', ...
                      'decision', 'report'};
    allFieldsPresent = all(isfield(sample, expectedFields));
    if allFieldsPresent
        fprintf('PASSED\n');
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED (Missing fields)\n');
    end

    % Test 2: In-memory RGB uint8 loading
    totalTests = totalTests + 1;
    fprintf('[Test %d] Ingesting in-memory RGB matrix... ', totalTests);
    dummyRGB = uint8(randi([0, 255], [400, 600, 3]));
    sampleRGB = loadFundusImage(dummyRGB, 'PatientID', "test_patient_001");
    if isequal(sampleRGB.originalSize, [400, 600, 3]) && ...
       isequal(sampleRGB.imageID, "test_patient_001") && ...
       isa(sampleRGB.image, 'uint8')
        fprintf('PASSED\n');
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED\n');
    end

    % Test 3: Grayscale to 3-Channel RGB conversion
    totalTests = totalTests + 1;
    fprintf('[Test %d] Ingesting Grayscale (2D) matrix -> RGB expansion... ', totalTests);
    dummyGray = uint8(randi([0, 255], [300, 300]));
    sampleGray = loadFundusImage(dummyGray);
    if isequal(sampleGray.originalSize, [300, 300, 3]) && ...
       size(sampleGray.image, 3) == 3 && ...
       isequal(sampleGray.image(:,:,1), sampleGray.image(:,:,2))
        fprintf('PASSED\n');
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED\n');
    end

    % Test 4: RGBA (4 channels) stripping alpha
    totalTests = totalTests + 1;
    fprintf('[Test %d] Ingesting RGBA (4 channels) -> Alpha stripping... ', totalTests);
    dummyRGBA = uint8(randi([0, 255], [200, 200, 4]));
    sampleRGBA = loadFundusImage(dummyRGBA);
    if isequal(sampleRGBA.originalSize, [200, 200, 3]) && ...
       size(sampleRGBA.image, 3) == 3
        fprintf('PASSED\n');
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED\n');
    end

    % Test 5: Double floating point [0, 1] normalization to uint8
    totalTests = totalTests + 1;
    fprintf('[Test %d] Ingesting double precision [0, 1] -> uint8 conversion... ', totalTests);
    dummyDouble = rand(150, 150, 3);
    sampleDouble = loadFundusImage(dummyDouble);
    if isa(sampleDouble.image, 'uint8') && max(sampleDouble.image(:)) <= 255
        fprintf('PASSED\n');
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED\n');
    end

    % Test 6: Target size resizing
    totalTests = totalTests + 1;
    fprintf('[Test %d] Resizing to CNN target size [224, 224]... ', totalTests);
    sampleResize = loadFundusImage(dummyRGB, 'TargetSize', [224, 224]);
    if isequal(sampleResize.currentSize, [224, 224, 3]) && ...
       isequal(sampleResize.originalSize, [400, 600, 3])
        fprintf('PASSED\n');
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED\n');
    end

    % Test 7: Resizing with Aspect Ratio preservation (Letterboxing)
    totalTests = totalTests + 1;
    fprintf('[Test %d] Resizing with aspect-ratio letterboxing... ', totalTests);
    wideImg = uint8(255 * ones(200, 400, 3));
    sampleLetterbox = loadFundusImage(wideImg, 'TargetSize', [300, 300], 'MaintainAspectRatio', true);
    % Top/bottom borders should have black padding (value 0)
    topRowZero = all(sampleLetterbox.image(1, :, 1) == 0);
    centerVal = sampleLetterbox.image(150, 150, 1) > 200;
    if isequal(sampleLetterbox.currentSize, [300, 300, 3]) && topRowZero && centerVal
        fprintf('PASSED\n');
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED\n');
    end

    % Test 8: Non-existent file error handling
    totalTests = totalTests + 1;
    fprintf('[Test %d] Error handling for non-existent file... ', totalTests);
    try
        loadFundusImage('non_existent_fundus_photo_12345.jpg');
        fprintf('FAILED (Did not raise error)\n');
    catch
        fprintf('PASSED\n');
        testsPassed = testsPassed + 1;
    end

    % Summary
    fprintf('\n====================================================\n');
    fprintf('Test Summary: %d / %d tests passed (%.1f%%)\n', ...
        testsPassed, totalTests, (testsPassed / totalTests) * 100);
    fprintf('====================================================\n');

    results = struct('passed', testsPassed, 'total', totalTests);
end
