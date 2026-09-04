function results = simulateScreeningWorkflow(params, varargin)
% SIMULATESCREENINGWORKFLOW Discrete-event workflow simulation for tele-screening pipeline.
%
% Simulates end-to-end patient flow:
%   Arrival -> Acquisition -> Quality Gate -> Network Upload -> AI Cluster -> Human Review
%
% Usage:
%   params = DR_Screening_System_params();
%   results = simulateScreeningWorkflow(params)
%   results = simulateScreeningWorkflow(params, 'SimulationHours', 8, 'Plot', true)
%
% Inputs:
%   params - System parameters struct from DR_Screening_System_params.
%
% Name-Value Parameters:
%   'SimulationHours' - Duration of simulation run in hours (default: 8 hours = 1 clinic day).
%   'Plot'            - Logical. If true, displays queue and throughput figures (default: false).
%
% Outputs:
%   results - Struct containing queue lengths, wait times, throughput, and bottleneck diagnosis.
%
% Reference:
%   Phase 10: Simulink Workflow + System Validation

    p = inputParser;
    addRequired(p, 'params', @isstruct);
    addParameter(p, 'SimulationHours', 8, @(x) isnumeric(x) && x > 0);
    addParameter(p, 'Plot', false, @(x) islogical(x) || isnumeric(x));
    parse(p, params, varargin{:});

    simHours    = p.Results.SimulationHours;
    shouldPlot  = logical(p.Results.Plot);
    simDurationSec = simHours * 3600;

    % 1. Patient Arrival Generation (Poisson process with diurnal peak)
    % Average arrival rate lambda (patients per second)
    meanLambda = (params.annualVolume / (params.workDaysPerYear * params.clinicHoursPerDay)) / 3600;

    % Generate patient arrival timestamps
    rng(42); % Deterministic seed for reproducible validation
    curTime = 0;
    arrivalTimes = [];
    while curTime < simDurationSec
        % Diurnal modulation: peak patient load around mid-day
        hourOfDay = (curTime / 3600) + 9.0; % 9:00 AM to 5:00 PM
        peakFactor = 1.0 + 0.35 * sin(pi * (hourOfDay - 9.0) / 8.0);
        interArrival = exprnd(1 / (meanLambda * peakFactor));
        curTime = curTime + interArrival;
        if curTime < simDurationSec
            arrivalTimes(end+1) = curTime;
        end
    end
    numPatients = numel(arrivalTimes);

    % 2. Image Generation & Acquisition
    imagesPerPatient = params.imagesPerPatient;
    totalImages = numPatients * imagesPerPatient;

    % Track per-patient milestones
    turnaroundTimes = zeros(numPatients, 1);
    aiWaitTimes     = zeros(totalImages, 1);
    doctorWaitTimes = zeros(numPatients, 1);
    recapturesCount = 0;

    % 3. Simulation Clocks & Server Pools
    aiNodeAvailableTime = zeros(1, params.numAINodes);
    doctorAvailableTime = zeros(1, params.numOphthalmologists);
    networkAvailableTime = 0;

    % Time-series logging (minute-by-minute)
    timeGrid = 0:60:simDurationSec;
    numSteps = numel(timeGrid);
    aiQueueHist     = zeros(numSteps, 1);
    doctorQueueHist = zeros(numSteps, 1);

    patientIdx = 1;
    imgGlobalIdx = 1;

    for i = 1:numPatients
        tArr = arrivalTimes(i);

        % Acquisition delay per patient
        acqDelay = normrnd(params.acquisitionTimeMin * 60, 20.0);
        acqDelay = max(90.0, acqDelay);

        % Quality gate: check for recapture
        if rand() < params.recaptureRate
            recapturesCount = recapturesCount + 1;
            % Additional recapture time: ~1.5 minutes
            acqDelay = acqDelay + 90.0;
        end
        tAcqDone = tArr + acqDelay;

        % Both eyes transmitted
        tUploadDone = zeros(imagesPerPatient, 1);
        for e = 1:imagesPerPatient
            tNetStart = max(tAcqDone, networkAvailableTime);
            uploadDuration = params.uploadLatencySec;
            tUploadDone(e) = tNetStart + uploadDuration;
            networkAvailableTime = tUploadDone(e);
        end

        % AI Processing Cluster (Parallel processing across N nodes)
        tAIDone = zeros(imagesPerPatient, 1);
        for e = 1:imagesPerPatient
            % Find earliest available AI node
            [earliestNodeTime, bestNodeIdx] = min(aiNodeAvailableTime);
            tAIStart = max(tUploadDone(e), earliestNodeTime);
            aiWaitTimes(imgGlobalIdx) = tAIStart - tUploadDone(e);

            aiDuration = normrnd(params.totalAITimePerImageSec, 0.15);
            aiDuration = max(0.4, aiDuration);

            tAIDone(e) = tAIStart + aiDuration;
            aiNodeAvailableTime(bestNodeIdx) = tAIDone(e);
            imgGlobalIdx = imgGlobalIdx + 1;
        end
        tAllAIDone = max(tAIDone);

        % Clinical Decision & Triage Routing
        % Referable cases (Level 2+) and Borderline quality go to Doctor Queue
        requiresDoctorReview = (rand() < params.referralRate);

        if requiresDoctorReview
            % Route to Ophthalmologist Review Pool
            [earliestDocTime, bestDocIdx] = min(doctorAvailableTime);
            tDocStart = max(tAllAIDone, earliestDocTime);
            doctorWaitTimes(patientIdx) = tDocStart - tAllAIDone;

            docDuration = normrnd(params.doctorReviewTimeSec, 5.0);
            docDuration = max(8.0, docDuration);

            tFinal = tDocStart + docDuration;
            doctorAvailableTime(bestDocIdx) = tFinal;
        else
            % Automated Screening Result Finalized immediately
            tFinal = tAllAIDone;
            doctorWaitTimes(patientIdx) = 0;
        end

        turnaroundTimes(patientIdx) = tFinal - tArr;
        patientIdx = patientIdx + 1;
    end

    % 4. Compute Summary Statistics & Capacities
    meanTurnaroundMin = mean(turnaroundTimes) / 60;
    p95TurnaroundMin  = prctile(turnaroundTimes, 95) / 60;
    meanAIWaitSec     = mean(aiWaitTimes);
    meanDocWaitMin    = mean(doctorWaitTimes(doctorWaitTimes > 0)) / 60;

    aiUtilization  = (totalImages * params.totalAITimePerImageSec) / (params.numAINodes * simDurationSec);
    docWorkload    = (numPatients * params.referralRate * params.doctorReviewTimeSec) / (params.numOphthalmologists * simDurationSec);
    netUtilization = (totalImages * params.uploadLatencySec) / simDurationSec;

    % 5. Identify System Bottleneck
    utilizations = [netUtilization, aiUtilization, docWorkload];
    utilNames    = ["Network Upload Bandwidth", "AI Processing Nodes", "Ophthalmologist Review Pool"];
    [maxUtil, bottleneckIdx] = max(utilizations);
    bottleneckStage = utilNames(bottleneckIdx);

    % Assemble Results
    results = struct();
    results.simulatedHours      = simHours;
    results.totalPatients       = numPatients;
    results.totalImages         = totalImages;
    results.recapturesCount     = recapturesCount;
    results.recapturePercentage = (recapturesCount / numPatients) * 100;
    
    results.turnaroundTimeMin   = round(meanTurnaroundMin, 1);
    results.p95TurnaroundMin    = round(p95TurnaroundMin, 1);
    results.meanAIWaitSec       = round(meanAIWaitSec, 2);
    results.meanDocWaitMin      = round(meanDocWaitMin, 1);

    results.networkUtilization  = round(min(1.0, netUtilization) * 100, 1);
    results.aiNodeUtilization   = round(min(1.0, aiUtilization) * 100, 1);
    results.doctorUtilization   = round(min(1.0, docWorkload) * 100, 1);
    results.bottleneckStage     = bottleneckStage;
    results.maxUtilizationPct   = round(maxUtil * 100, 1);

    % Plotting if requested
    if shouldPlot
        figure('Name', 'DR Screening Pipeline - Simulink Capacity Simulation', ...
            'NumberTitle', 'off', 'Units', 'pixels', 'Position', [100, 100, 900, 500]);
        
        subplot(1, 2, 1);
        bar([results.networkUtilization, results.aiNodeUtilization, results.doctorUtilization]);
        set(gca, 'XTickLabel', {'Network', 'AI Nodes', 'Doctors'});
        ylabel('Resource Utilization (%)');
        title('Stage Utilization & Sizing');
        ylim([0, 100]);
        grid on;

        subplot(1, 2, 2);
        histogram(turnaroundTimes / 60, 20, 'FaceColor', [0.2, 0.6, 0.8]);
        xlabel('Total Turnaround Time (minutes)');
        ylabel('Patient Count');
        title(sprintf('Patient Wait Time (Mean: %.1f min)', meanTurnaroundMin));
        grid on;
    end
end
