function results = testPhase9()
% TESTPHASE9 Comprehensive test harness for Phase 9: Automated Screening Report.
%
% Tests:
%   1. Clinical report text generation (formatReportText): headers, sections, disclaimer.
%   2. Visual dashboard generation (generateScreeningReport): 6-panel composite figure.
%   3. File export verification: PNG and TXT report generation on disk.
%   4. Master single-command runner (screenFundusImage): full 9-phase end-to-end execution.

    fprintf('====================================================\n');
    fprintf('           RUNNING PHASE 9 UNIT TESTS               \n');
    fprintf('====================================================\n\n');

    testsPassed = 0;
    totalTests  = 0;

    tempDir = fullfile('reports', 'test_outputs');
    if ~exist(tempDir, 'dir')
        mkdir(tempDir);
    end

    H = 512; W = 512;
    img = generateSyntheticFundus(H, W, 'Quality', 'good', 'Lesions', 'moderate');
    model = loadDRModel("mock");

    % Test 1: Clinical Report Text Formatting
    totalTests = totalTests + 1;
    fprintf('[Test %d] Testing consultation text formatting (formatReportText)... ', totalTests);
    sample = loadFundusImage(img, 'PatientID', "pt_report_test");
    sample = assessImageQuality(sample);
    sample = enhanceFundusImage(sample);
    sample = analyzeRetinalStructures(sample);
    sample = detectLesionEvidence(sample);
    sample = runDRModel(model, sample);
    sample = generateGradCAM(model, sample);
    sample = makeClinicalDecision(sample);

    reportText = formatReportText(sample);

    hasHeader     = contains(reportText, 'DIABETIC RETINOPATHY SCREENING REPORT');
    hasPrediction = contains(reportText, 'Predicted DR Stage');
    hasReferral   = contains(reportText, 'Referable DR');
    hasDisclaimer = contains(reportText, 'clinical decision support');

    textValid = hasHeader && hasPrediction && hasReferral && hasDisclaimer;

    if textValid
        fprintf('PASSED (All required clinical consultation sections present)\n');
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED\n');
    end

    % Test 2: Visual Dashboard Generation & File Export
    totalTests = totalTests + 1;
    fprintf('[Test %d] Testing 6-panel dashboard & disk export (generateScreeningReport)... ', totalTests);
    sample = generateScreeningReport(sample, 'SaveDir', tempDir, 'ExportPNG', true, 'ExportText', true, 'Visible', 'off');

    filesValid = isfield(sample.report, 'savedFiles') && ...
                 isfield(sample.report.savedFiles, 'png') && ...
                 exist(char(sample.report.savedFiles.png), 'file') == 2 && ...
                 exist(char(sample.report.savedFiles.txt), 'file') == 2;

    if filesValid
        fprintf('PASSED (Exported: %s and %s)\n', ...
            sample.report.savedFiles.png, sample.report.savedFiles.txt);
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED (Files missing on disk)\n');
    end

    % Test 3: Master Single-Command Runner
    totalTests = totalTests + 1;
    fprintf('[Test %d] Testing single-command runner (screenFundusImage)... ', totalTests);
    masterSample = screenFundusImage(img, model, 'PatientID', "pt_master_001", ...
        'SaveDir', tempDir, 'Visible', 'off');

    allPhasesComplete = ~isempty(masterSample.quality.status) && ...
                        ~isempty(masterSample.anatomy.vessels.mask) && ...
                        isnumeric(masterSample.lesionEvidence.totalLesions) && ...
                        ~isnan(masterSample.prediction.predictedClass) && ...
                        ~isempty(masterSample.gradCAM.overlay) && ...
                        islogical(masterSample.decision.isReferable) && ...
                        ~isempty(masterSample.report.summaryText);

    if allPhasesComplete
        fprintf('PASSED (All 9 pipeline phases executed in one command)\n');
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED (Incomplete phase execution)\n');
    end

    % Clean up temporary figure if open
    if isfield(sample.report, 'reportFigure') && isgraphics(sample.report.reportFigure)
        close(sample.report.reportFigure);
    end
    if isfield(masterSample.report, 'reportFigure') && isgraphics(masterSample.report.reportFigure)
        close(masterSample.report.reportFigure);
    end

    % Summary
    fprintf('\n====================================================\n');
    fprintf('Phase 9 Test Summary: %d / %d tests passed (%.1f%%)\n', ...
        testsPassed, totalTests, (testsPassed / totalTests) * 100);
    fprintf('====================================================\n');

    results = struct('passed', testsPassed, 'total', totalTests);
end
