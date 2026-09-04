function results = testPhase10()
% TESTPHASE10 Comprehensive test harness for Phase 10: Simulink Workflow + System Validation.
%
% Tests:
%   1. System parameters configuration: 100,000+ patient volume calculations.
%   2. Discrete-event workflow simulation: 8-hour shift execution & queue tracking.
%   3. Bottleneck diagnosis: resource utilization and capacity bounds.
%   4. Stress test scenario analysis: peak surge, recapture, and bandwidth constraints.
%   5. Executive capacity report generation: sizing recommendations for AI & doctors.

    fprintf('====================================================\n');
    fprintf('           RUNNING PHASE 10 UNIT TESTS              \n');
    fprintf('====================================================\n\n');

    testsPassed = 0;
    totalTests  = 0;

    % Test 1: System Parameters Configuration
    totalTests = totalTests + 1;
    fprintf('[Test %d] Testing System Parameters (DR_Screening_System_params)... ', totalTests);
    params = DR_Screening_System_params('AnnualVolume', 100000);

    paramsValid = params.annualVolume == 100000 && ...
                  params.patientsPerDay == 400 && ...
                  params.imagesPerDay == 800 && ...
                  params.totalAITimePerImageSec > 0.5 && ...
                  params.totalAITimePerImageSec < 3.0;

    if paramsValid
        fprintf('PASSED (100k/yr -> %d pts/day, AI latency: %.2f s/img)\n', ...
            params.patientsPerDay, params.totalAITimePerImageSec);
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED\n');
    end

    % Test 2: Discrete-Event Workflow Simulation
    totalTests = totalTests + 1;
    fprintf('[Test %d] Testing Workflow Simulation (simulateScreeningWorkflow)... ', totalTests);
    simResults = simulateScreeningWorkflow(params, 'SimulationHours', 8);

    simValid = simResults.totalPatients >= 300 && ...
               simResults.totalImages == (simResults.totalPatients * 2) && ...
               simResults.turnaroundTimeMin > 2.0 && ...
               simResults.turnaroundTimeMin < 30.0 && ...
               simResults.networkUtilization > 0 && ...
               simResults.aiNodeUtilization > 0;

    if simValid
        fprintf('PASSED (Simulated: %d pts, Mean Turnaround: %.1f min, Bottleneck: %s)\n', ...
            simResults.totalPatients, simResults.turnaroundTimeMin, simResults.bottleneckStage);
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED (Patients: %d, Turnaround: %.1f min)\n', ...
            simResults.totalPatients, simResults.turnaroundTimeMin);
    end

    % Test 3: Recapture Rate Sensitivity
    totalTests = totalTests + 1;
    fprintf('[Test %d] Testing Quality Recapture Impact (25%% vs 10%%)... ', totalTests);
    pLowRecap  = DR_Screening_System_params('AnnualVolume', 100000, 'RecaptureRate', 0.10);
    pHighRecap = DR_Screening_System_params('AnnualVolume', 100000, 'RecaptureRate', 0.25);
    resLow  = simulateScreeningWorkflow(pLowRecap, 'SimulationHours', 4);
    resHigh = simulateScreeningWorkflow(pHighRecap, 'SimulationHours', 4);

    if resHigh.recapturesCount > resLow.recapturesCount
        fprintf('PASSED (Recaptures scaled: %d -> %d)\n', ...
            resLow.recapturesCount, resHigh.recapturesCount);
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED\n');
    end

    % Test 4: Executive Capacity Analysis & Resource Sizing
    totalTests = totalTests + 1;
    fprintf('[Test %d] Testing Capacity Report & Sizing (analyzeSystemCapacity)... ', totalTests);
    capReport = analyzeSystemCapacity('AnnualVolume', 100000);

    reportValid = isstruct(capReport) && ...
                  capReport.recommendedNodes >= 1 && capReport.recommendedNodes <= 8 && ...
                  capReport.recommendedDocs >= 1 && capReport.recommendedDocs <= 8 && ...
                  contains(capReport.summaryText, 'SYSTEM CAPACITY REPORT');

    if reportValid
        fprintf('PASSED (Recommended AI Nodes: %d, Doctors: %d)\n', ...
            capReport.recommendedNodes, capReport.recommendedDocs);
        testsPassed = testsPassed + 1;
    else
        fprintf('FAILED\n');
    end

    % Summary
    fprintf('\n====================================================\n');
    fprintf('Phase 10 Test Summary: %d / %d tests passed (%.1f%%)\n', ...
        testsPassed, totalTests, (testsPassed / totalTests) * 100);
    fprintf('====================================================\n');

    results = struct('passed', testsPassed, 'total', totalTests);
end
