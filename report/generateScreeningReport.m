function [outSample, reportText, figHandle] = generateScreeningReport(sample, varargin)
% GENERATESCREENINGREPORT Builds a multi-panel visual dashboard and clinical report.
%
% Visual Dashboard Layout (2x3 Grid):
%   [1] Original Fundus Image       | [2] Enhanced Fundus Image
%   [3] Anatomical Landmarks Map    | [4] Lesion Candidates Overlay
%   [5] Grad-CAM Explainability Map | [6] Diagnostic & Triage Summary Card
%
% Usage:
%   sample = generateScreeningReport(sample)
%   [sample, reportText, figHandle] = generateScreeningReport(sample, 'SaveDir', 'reports')
%
% Name-Value Parameters:
%   'SaveDir'    - Output directory for report exports (default: from .env / 'reports').
%   'ExportPNG'  - Logical. If true, saves dashboard as PNG image (default: true).
%   'ExportText' - Logical. If true, saves report as TXT file (default: true).
%   'Visible'    - 'on' or 'off' (default: 'off' for headless batch processing).
%
% Outputs:
%   outSample  - Updated sample struct with sample.report populated.
%   reportText - Multi-line string report text.
%   figHandle  - Handle to the generated MATLAB figure.
%
% Reference:
%   Phase 9: Automated Clinical-Style Report

    cfg = getConfig();

    p = inputParser;
    addRequired(p, 'sample', @isstruct);
    addParameter(p, 'SaveDir', cfg.OUTPUT_DIR, @(x) ischar(x) || isstring(x));
    addParameter(p, 'ExportPNG', true, @(x) islogical(x) || isnumeric(x));
    addParameter(p, 'ExportText', true, @(x) islogical(x) || isnumeric(x));
    addParameter(p, 'Visible', 'off', @(x) ischar(x) || isstring(x));
    parse(p, sample, varargin{:});

    saveDir    = char(p.Results.SaveDir);
    exportPNG  = logical(p.Results.ExportPNG);
    exportText = logical(p.Results.ExportText);
    figVis     = char(p.Results.Visible);

    if ~exist(saveDir, 'dir')
        mkdir(saveDir);
    end

    % 1. Generate Formatted Clinical Consultation Text
    reportText = formatReportText(sample);

    % 2. Extract Panel Images
    origImg = sample.image;

    if isfield(sample, 'enhancedImage') && ~isempty(sample.enhancedImage)
        enhImg = sample.enhancedImage;
    else
        enhImg = origImg;
    end

    if isfield(sample, 'anatomy') && isfield(sample.anatomy, 'overlay') && ~isempty(sample.anatomy.overlay)
        anatImg = sample.anatomy.overlay;
    else
        anatImg = origImg;
    end

    if isfield(sample, 'lesionEvidence') && isfield(sample.lesionEvidence, 'overlay') && ~isempty(sample.lesionEvidence.overlay)
        lesionImg = sample.lesionEvidence.overlay;
    else
        lesionImg = origImg;
    end

    if isfield(sample, 'gradCAM') && isfield(sample.gradCAM, 'overlay') && ~isempty(sample.gradCAM.overlay)
        gradImg = sample.gradCAM.overlay;
    else
        gradImg = origImg;
    end

    % 3. Create Multi-Panel Figure
    figHandle = figure('Name', sprintf('DR Screening Report - %s', sample.imageID), ...
        'NumberTitle', 'off', 'Color', [0.96, 0.96, 0.97], ...
        'Units', 'pixels', 'Position', [100, 100, 1200, 800], ...
        'Visible', figVis);

    % Main Header Banner
    annotation(figHandle, 'textbox', [0.03, 0.93, 0.94, 0.05], ...
        'String', sprintf('DIABETIC RETINOPATHY SCREENING DASHBOARD | Patient ID: %s | Generated: %s', ...
            sample.imageID, datestr(now, 'yyyy-mm-dd HH:MM')), ...
        'FontSize', 13, 'FontWeight', 'bold', 'EdgeColor', 'none', ...
        'HorizontalAlignment', 'center', 'BackgroundColor', [0.15, 0.25, 0.40], ...
        'Color', 'white');

    % Panel 1: Original Fundus
    ax1 = subplot(2, 3, 1);
    imshow(origImg, 'Parent', ax1);
    title(ax1, '1. Ingested Fundus Image', 'FontSize', 10, 'FontWeight', 'bold');

    % Panel 2: Enhanced Fundus
    ax2 = subplot(2, 3, 2);
    imshow(enhImg, 'Parent', ax2);
    enhTitle = '2. Enhanced Image (Preserved Original)';
    if isfield(sample, 'enhancementInfo') && sample.enhancementInfo.applied
        enhTitle = '2. Enhanced Image (CLAHE + Illum Norm)';
    end
    title(ax2, enhTitle, 'FontSize', 10, 'FontWeight', 'bold');

    % Panel 3: Anatomical Landmarks Map
    ax3 = subplot(2, 3, 3);
    imshow(anatImg, 'Parent', ax3);
    anatTitle = '3. Retinal Structures (OD, Fovea, Vessels)';
    title(ax3, anatTitle, 'FontSize', 10, 'FontWeight', 'bold');

    % Panel 4: Lesion Candidates Overlay
    ax4 = subplot(2, 3, 4);
    imshow(lesionImg, 'Parent', ax4);
    totalL = 0;
    if isfield(sample, 'lesionEvidence') && isfield(sample.lesionEvidence, 'totalLesions')
        totalL = sample.lesionEvidence.totalLesions;
    end
    title(ax4, sprintf('4. Lesion Candidates (%d detected)', totalL), 'FontSize', 10, 'FontWeight', 'bold');

    % Panel 5: Grad-CAM Explainability Heatmap
    ax5 = subplot(2, 3, 5);
    imshow(gradImg, 'Parent', ax5);
    gradTitle = '5. Grad-CAM Explainability Overlay';
    if isfield(sample, 'gradCAM') && isfield(sample.gradCAM, 'classLabel')
        gradTitle = sprintf('5. Grad-CAM (Target: %s)', sample.gradCAM.classLabel);
    end
    title(ax5, gradTitle, 'FontSize', 10, 'FontWeight', 'bold');

    % Panel 6: Diagnostic & Triage Summary Card
    ax6 = subplot(2, 3, 6);
    axis(ax6, 'off');

    % Build Card Text Block
    drStageStr = "N/A";
    refStr = "N/A";
    confStr = "N/A";
    actionStr = "N/A";
    timeStr = "N/A";
    cardColor = [0.90, 0.95, 0.90]; % Default green (non-referable)

    if isfield(sample, 'prediction')
        drStageStr = sprintf('Level %d - %s', sample.prediction.predictedClass, sample.prediction.classLabel);
    end

    if isfield(sample, 'decision')
        confStr = sprintf('%.1f%%', sample.decision.confidence * 100);
        if sample.decision.isReferable
            refStr = 'YES (Referral Required)';
            if sample.decision.isUrgent
                cardColor = [1.0, 0.88, 0.88]; % Light Red (Urgent)
            else
                cardColor = [1.0, 0.94, 0.85]; % Light Orange (Referable)
            end
        else
            refStr = 'NO (Routine Follow-up)';
            cardColor = [0.88, 0.96, 0.88]; % Light Green (Non-referable)
        end
        actionStr = char(sample.decision.actionRequired);
        timeStr   = char(sample.decision.recommendedTimeframe);
    end

    cardLines = { ...
        sprintf('\\bfDiagnostic Summary\\rm'), ...
        sprintf('---------------------------------------------'), ...
        sprintf('\\bfPredicted Stage:\\rm  %s', drStageStr), ...
        sprintf('\\bfModel Confidence:\\rm %s', confStr), ...
        sprintf('\\bfReferable DR:\\rm    %s', refStr), ...
        sprintf('---------------------------------------------'), ...
        sprintf('\\bfTriage Action:\\rm   %s', actionStr), ...
        sprintf('\\bfTimeframe:\\rm       %s', timeStr), ...
        sprintf('---------------------------------------------'), ...
        sprintf('\\itDecision support only. Requires doctor review.\\rm') ...
    };

    % Draw Card Rectangle
    annotation(figHandle, 'textbox', [0.70, 0.12, 0.26, 0.34], ...
        'String', cardLines, 'FontSize', 9, 'EdgeColor', [0.6, 0.6, 0.7], ...
        'BackgroundColor', cardColor, 'Interpreter', 'tex');

    % 4. Export Deliverables
    baseFile = fullfile(saveDir, sprintf('%s_screening_report', sample.imageID));
    savedFiles = struct();

    if exportPNG
        pngPath = [baseFile, '.png'];
        saveas(figHandle, pngPath);
        savedFiles.png = string(pngPath);
    end

    if exportText
        txtPath = [baseFile, '.txt'];
        fid = fopen(txtPath, 'w');
        if fid ~= -1
            fprintf(fid, '%s\n', reportText);
            fclose(fid);
            savedFiles.txt = string(txtPath);
        end
    end

    % 5. Assemble Report Struct in sample
    sample.report = struct();
    sample.report.summaryText  = reportText;
    sample.report.generatedAt  = string(datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    sample.report.reportFigure = figHandle;
    sample.report.savedFiles   = savedFiles;

    outSample = sample;
end
