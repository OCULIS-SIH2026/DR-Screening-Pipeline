% DEMOMILESTONE1 End-to-end demonstration of Milestone 1 (Phases 1, 2, and 3).
%
% This script demonstrates:
%   - Phase 1: Ingestion & standard struct creation
%   - Phase 2: Quality assessment (Good, Borderline, Recapture)
%   - Phase 3: Selective enhancement (CLAHE + Illumination Norm + Bilateral Denoising)
%
% Run this script in MATLAB:
%   demoMilestone1;

function demoMilestone1()
    fprintf('========================================================================\n');
    fprintf('   AI-BASED DR SCREENING ENGINE - MILESTONE 1 DEMONSTRATION            \n');
    fprintf('   Phases 1-3: Ingestion -> Quality Assessment -> Selective Enhancement\n');
    fprintf('========================================================================\n\n');

    % Create 3 clinical scenarios
    scenarios = {
        struct('id', "PATIENT_001_GOOD",       'quality', 'good',        'desc', 'Clear, well-focused fundus'), ...
        struct('id', "PATIENT_002_BORDERLINE", 'quality', 'underexposed', 'desc', 'Low exposure, recoverable'), ...
        struct('id', "PATIENT_003_RECAPTURE",  'quality', 'blurry',      'desc', 'Severe defocus, unusable')
    };

    resultsTable = cell(numel(scenarios), 6);

    for i = 1:numel(scenarios)
        sc = scenarios{i};
        fprintf('------------------------------------------------------------------------\n');
        fprintf('Processing Case %d: %s (%s)\n', i, sc.id, sc.desc);
        fprintf('------------------------------------------------------------------------\n');

        % 1. Synthesize image and Phase 1 Ingestion
        img = generateSyntheticFundus(512, 512, 'Quality', sc.quality);
        if sc.id == "PATIENT_002_BORDERLINE"
            % Borderline adjustment: mild underexposure
            img = uint8(double(img) * 0.55 + 20);
        end

        sample = loadFundusImage(img, 'PatientID', sc.id, 'TargetSize', [224, 224]);
        fprintf('  [Phase 1 Ingestion] Image ID: %s | Dimensions: [%dx%dx%d]\n', ...
            sample.imageID, sample.currentSize(1), sample.currentSize(2), sample.currentSize(3));

        % 2. Phase 2 Quality Assessment
        sample = assessImageQuality(sample);
        fprintf('  [Phase 2 IQA]       Status: %s | Overall Score: %.2f\n', ...
            sample.quality.status, sample.quality.overallScore);
        fprintf('                      (Sharpness: %.2f, Brightness: %.2f, Contrast: %.2f, FOV: %.2f)\n', ...
            sample.quality.sharpness, sample.quality.brightness, ...
            sample.quality.contrast, sample.quality.fov);

        if ~isempty(sample.quality.rejectionReasons)
            for r = 1:numel(sample.quality.rejectionReasons)
                fprintf('                      * Warning/Note: %s\n', sample.quality.rejectionReasons{r});
            end
        end

        % 3. Phase 3 Selective Enhancement
        sample = enhanceFundusImage(sample);
        if sample.enhancementInfo.applied
            fprintf('  [Phase 3 Enhance]   Applied: YES (%s)\n', sample.enhancementInfo.method);
        else
            fprintf('  [Phase 3 Enhance]   Applied: NO  (%s)\n', sample.enhancementInfo.reason);
        end
        fprintf('\n');

        resultsTable{i, 1} = char(sample.imageID);
        resultsTable{i, 2} = char(sample.quality.status);
        resultsTable{i, 3} = sample.quality.overallScore;
        resultsTable{i, 4} = sample.quality.sharpness;
        resultsTable{i, 5} = sample.enhancementInfo.applied;
        resultsTable{i, 6} = char(sample.enhancementInfo.method);
    end

    % Summary Table
    fprintf('========================================================================\n');
    fprintf('                         MILESTONE 1 SUMMARY TABLE                      \n');
    fprintf('========================================================================\n');
    fprintf('%-24s | %-10s | %-6s | %-9s | %-8s | %-20s\n', ...
        'Patient ID', 'Quality', 'Score', 'Sharpness', 'Enhanced', 'Method');
    fprintf('------------------------------------------------------------------------\n');
    for i = 1:size(resultsTable, 1)
        enhStr = 'NO';
        if resultsTable{i, 5}
            enhStr = 'YES';
        end
        fprintf('%-24s | %-10s | %-6.2f | %-9.2f | %-8s | %-20s\n', ...
            resultsTable{i, 1}, resultsTable{i, 2}, resultsTable{i, 3}, ...
            resultsTable{i, 4}, enhStr, resultsTable{i, 6});
    end
    fprintf('========================================================================\n\n');
end
