function sample = createSampleStruct()
% CREATESAMPLESTRUCT Initializes a standard internal sample struct for the DR Pipeline.
%
% Output:
%   sample - Struct containing placeholders and schema fields for all 10 phases.
%
% Reference:
%   Phase 1: Input and Data Interface

    sample = struct();
    
    % Phase 1: Input & Metadata
    sample.imageID          = "";           % Unique patient / image identifier
    sample.filePath         = "";           % Source path of the image
    sample.originalImage    = [];           % Untouched original RGB image (uint8)
    sample.originalSize     = [0, 0, 0];    % [Height, Width, Channels]
    sample.image            = [];           % Standardized RGB image (uint8, target size)
    sample.currentSize      = [0, 0, 0];    % Current dimensions of sample.image
    sample.metadata         = struct();     % File metadata (fileSize, format, timestamp, etc.)
    
    % Phase 2: Quality Assessment
    sample.quality = struct( ...
        'status',       "", ...             % "GOOD", "BORDERLINE", "RECAPTURE"
        'overallScore', NaN, ...            % Normalized 0.0 - 1.0
        'sharpness',    NaN, ...            % Laplacian variance / edge gradient
        'brightness',   NaN, ...            % Mean intensity / exposure index
        'contrast',     NaN, ...            % Michelson / RMS contrast
        'fov',          NaN, ...            % Field of view / retinal area coverage
        'rejectionReasons', {{}} ...        % Cell array of reasons if BORDERLINE/RECAPTURE
    );
    
    % Phase 3: Enhancement
    sample.enhancedImage    = [];           % Enhanced RGB image (if BORDERLINE)
    sample.enhancementInfo  = struct( ...
        'applied',      false, ...          % Whether enhancement was applied
        'method',       "", ...             % Enhancement method (e.g. "CLAHE + Illumination Norm")
        'parameters',   struct() ...        % Parameters used
    );
    
    % Phase 4: Retinal Structure Analysis
    sample.anatomy = struct( ...
        'opticDisc',    struct('center', [NaN, NaN], 'radius', NaN, 'bbox', [NaN, NaN, NaN, NaN], 'mask', []), ...
        'fovea',        struct('center', [NaN, NaN], 'confidence', NaN), ...
        'vessels',      struct('mask', [], 'density', NaN) ...
    );

    % Phase 5: Lesion Evidence Candidates
    sample.lesionEvidence = struct( ...
        'microaneurysms',   struct('count', 0, 'candidates', []), ...
        'hemorrhages',      struct('count', 0, 'candidates', [], 'mask', []), ...
        'exudates',         struct('count', 0, 'candidates', [], 'mask', []), ...
        'neovascularization', struct('detected', false, 'candidates', []) ...
    );

    % Phase 6: CNN Inference
    sample.prediction = struct( ...
        'predictedClass',   NaN, ...        % 0: No DR, 1: Mild, 2: Moderate, 3: Severe, 4: Proliferative
        'classLabel',       "", ...         % Textual label
        'probabilities',    zeros(1, 5), ...% Softmax probabilities [P(0), P(1), P(2), P(3), P(4)]
        'modelName',        "" ...          % Name/version of CNN used
    );

    % Phase 7: Explainability
    sample.gradCAM = struct( ...
        'heatmap',          [], ...         % 2D activation heatmap normalized [0, 1]
        'overlay',          [], ...         % Heatmap blended with fundus image
        'targetClass',      NaN, ...        % Class explained by Grad-CAM
        'targetLayer',      "" ...          % Conv layer tapped
    );

    % Phase 8: Confidence & Clinical Decision Logic
    sample.decision = struct( ...
        'referable',        false, ...      % true if Level >= 2
        'confidence',       NaN, ...        % Model confidence / calibrated probability
        'uncertaintyFlag',  false, ...      % true if confidence < threshold or borderline quality
        'actionRequired',   "" ...          % "ROUTINE_SCREENING", "OPHTHALMOLOGIST_REVIEW", "RECAPTURE"
    );

    % Phase 9: Screening Report
    sample.report = struct( ...
        'generatedAt',      "", ...
        'summaryText',      "", ...
        'reportFigure',     [] ...
    );
end
