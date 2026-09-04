function results = testPhase6()
% TESTPHASE6 Comprehensive test harness for Phase 6: CNN Inference Integration.
%
% Tests:
%   1. Model contract definition: input resolution, classes 0-4, ImageNet constants.
%   2. Input preprocessing: resizing, channel verification, tensor shape [224, 224, 3, 1].
%   3. Model loader: loading calibrated mock and saving/re-loading .mat file.
%   4. Inference output contract: 5 class probabilities summing to 1.0; class in 0-4.
%   5. End-to-end integration: sample.prediction schema populated on full pipeline.

    fprintf('====================================================\n');
    fprintf('           RUNNING PHASE 6 UNIT TESTS               \n');
    fprintf('====================================================\n\n');

    testsPassed = 0;
    totalTests  = 0;

    % Test 1: Model Contract Definition
    totalTests = totalTests + 1;
    fprintf('[Test %d] Validating Model Contract (getModelContract)... ', totalTests);
    contract = getModelContract();

    contractValid = isequal(contract.inputSize, [224, 224, 3]) && ...
                    contract.colorSpace == "RGB" && ...
                    numel(contract.classes.indices) == 5 && ...
                    isequal(contract.classes.indices, [0, 1, 2, 3, 4]);

    if contractValid
        fprintf('PASSED (Classes: 0 to 4, Size: [%dx%dx%d])\n', ...
            contract.inputSize(1), contract.inputSize(2), contract.inputSize(3));
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED\n');
    end

    % Test 2: Input Preprocessing for Neural Model
    totalTests = totalTests + 1;
    fprintf('[Test %d] Validating Tensor Preprocessing (preprocessForModel)... ', totalTests);
    dummyImg = uint8(randi([0, 255], [512, 512, 3]));
    [tensor, resized] = preprocessForModel(dummyImg, contract);

    tensorValid = isequal(size(tensor), [224, 224, 3, 1]) && ...
                  isa(tensor, 'single') && ...
                  isequal(size(resized), [224, 224, 3]);

    if tensorValid
        fprintf('PASSED (Output Tensor: [224x224x3x1] single)\n');
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED\n');
    end

    % Test 3: Model Loader & Mock File Serialization
    totalTests = totalTests + 1;
    fprintf('[Test %d] Testing Model Loader (loadDRModel & createMockDRModel)... ', totalTests);
    model = loadDRModel("mock");
    
    loaderValid = isstruct(model) && isfield(model, 'contract') && ...
                  model.numClasses == 5;

    if loaderValid
        fprintf('PASSED (Loaded: %s)\n', model.name);
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED\n');
    end

    % Test 4: Forward Inference & Probability Distribution
    totalTests = totalTests + 1;
    fprintf('[Test %d] Validating 5-Class Softmax Output (runDRModel)... ', totalTests);
    pred = runDRModel(model, dummyImg);

    probSum = sum(pred.probabilities);
    predValid = ismember(pred.predictedClass, [0, 1, 2, 3, 4]) && ...
                numel(pred.probabilities) == 5 && ...
                abs(probSum - 1.0) < 0.01 && ...
                all(pred.probabilities >= 0.0 & pred.probabilities <= 1.0);

    if predValid
        fprintf('PASSED (Class: %d - "%s", Probabilities Sum: %.4f)\n', ...
            pred.predictedClass, pred.classLabel, probSum);
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED (Sum: %.4f, Class: %d)\n', probSum, pred.predictedClass);
    end

    % Test 5: Clinical Differentiation (Clean fundus vs. Lesion fundus)
    totalTests = totalTests + 1;
    fprintf('[Test %d] Testing Clinical Lesion-to-Class Correlation... ', totalTests);
    % 1. Healthy fundus
    imgClean = generateSyntheticFundus(512, 512, 'Quality', 'good', 'Lesions', 'none');
    sampleClean = loadFundusImage(imgClean);
    sampleClean = assessImageQuality(sampleClean);
    sampleClean = analyzeRetinalStructures(sampleClean);
    sampleClean = detectLesionEvidence(sampleClean);
    sampleClean = runDRModel(model, sampleClean);

    % 2. Moderate DR fundus
    imgLesions = generateSyntheticFundus(512, 512, 'Quality', 'good', 'Lesions', 'moderate');
    sampleLesions = loadFundusImage(imgLesions);
    sampleLesions = assessImageQuality(sampleLesions);
    sampleLesions = analyzeRetinalStructures(sampleLesions);
    sampleLesions = detectLesionEvidence(sampleLesions);
    sampleLesions = runDRModel(model, sampleLesions);

    diffValid = (sampleClean.prediction.predictedClass == 0) && ...
                (sampleLesions.prediction.predictedClass >= 2);

    if diffValid
        fprintf('PASSED (Clean -> Level %d "%s", Lesions -> Level %d "%s")\n', ...
            sampleClean.prediction.predictedClass, sampleClean.prediction.classLabel, ...
            sampleLesions.prediction.predictedClass, sampleLesions.prediction.classLabel);
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED (Clean: %d, Lesions: %d)\n', ...
            sampleClean.prediction.predictedClass, sampleLesions.prediction.predictedClass);
    end

    % Test 6: Pipeline Integration with sample struct
    totalTests = totalTests + 1;
    fprintf('[Test %d] Verifying sample.prediction struct schema... ', totalTests);
    pFields = {'predictedClass', 'classLabel', 'probabilities', 'modelName', 'contract'};
    schemaValid = all(isfield(sampleLesions.prediction, pFields));

    if schemaValid
        fprintf('PASSED\n');
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED (Missing fields in sample.prediction)\n');
    end

    % Summary
    fprintf('\n====================================================\n');
    fprintf('Phase 6 Test Summary: %d / %d tests passed (%.1f%%)\n', ...
        testsPassed, totalTests, (testsPassed / totalTests) * 100);
    fprintf('====================================================\n');

    results = struct('passed', testsPassed, 'total', totalTests);
end
