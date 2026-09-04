function overallResults = runAllPipelineTests()
% RUNALLPIPELINETESTS Master test runner executing all 10 pipeline phase test suites.
%
% Executes:
%   Phase 1:  Input and Data Interface
%   Phase 2:  Image Quality Assessment (IQA)
%   Phase 3:  Image Enhancement & Normalization
%   Phase 4:  Retinal Structure Analysis (Anatomy)
%   Phase 5:  Lesion Evidence Extraction
%   Phase 6:  CNN Inference Integration
%   Phase 7:  Explainability & Grad-CAM
%   Phase 8:  Confidence Calibration & Referral Triage
%   Phase 9:  Automated Screening Report & Dashboard
%   Phase 10: Simulink Workflow & System Validation
%
% Usage:
%   runAllPipelineTests;

    fprintf('========================================================================\n');
    fprintf('        AI DIABETIC RETINOPATHY SCREENING ENGINE - FULL TEST SUITE      \n');
    fprintf('                     Phases 1 through 10 Validation                     \n');
    fprintf('========================================================================\n\n');

    setup_environment;

    testFunctions = { ...
        @testPhase1, ...
        @testPhase2, ...
        @testPhase3, ...
        @testPhase4, ...
        @testPhase5, ...
        @testPhase6, ...
        @testPhase7, ...
        @testPhase8, ...
        @testPhase9, ...
        @testPhase10 ...
    };

    totalPassed = 0;
    totalCount  = 0;
    phaseResults = cell(numel(testFunctions), 3);

    for p = 1:numel(testFunctions)
        testFn = testFunctions{p};
        fnName = func2str(testFn);
        fprintf('\n>>> Executing %s...\n', fnName);
        
        try
            res = testFn();
            passed = res.passed;
            total  = res.total;
        catch ME
            fprintf('*** Error in %s: %s\n', fnName, ME.message);
            passed = 0;
            total  = 1;
        end

        totalPassed = totalPassed + passed;
        totalCount  = totalCount + total;

        phaseResults{p, 1} = sprintf('Phase %d', p);
        phaseResults{p, 2} = sprintf('%d / %d', passed, total);
        if passed == total
            phaseResults{p, 3} = 'PASSED (100%)';
        else
            phaseResults{p, 3} = sprintf('PARTIAL (%.1f%%)', (passed / total) * 100);
        end
    end

    % Final Summary Table
    fprintf('\n========================================================================\n');
    fprintf('                     OVERALL PIPELINE TEST RESULTS                      \n');
    fprintf('========================================================================\n');
    fprintf('%-12s | %-12s | %-18s\n', 'Phase', 'Score', 'Status');
    fprintf('------------------------------------------------------------------------\n');
    for p = 1:size(phaseResults, 1)
        fprintf('%-12s | %-12s | %-18s\n', ...
            phaseResults{p, 1}, phaseResults{p, 2}, phaseResults{p, 3});
    end
    fprintf('========================================================================\n');
    fprintf(' TOTAL SCORE: %d / %d Tests Passed (%.1f%%)\n', ...
        totalPassed, totalCount, (totalPassed / totalCount) * 100);
    fprintf('========================================================================\n\n');

    overallResults = struct('totalPassed', totalPassed, 'totalCount', totalCount);
end
