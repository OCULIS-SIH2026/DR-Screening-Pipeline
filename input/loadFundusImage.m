function sample = loadFundusImage(source, varargin)
% LOADFUNDUSIMAGE Ingests and standardizes fundus images for the DR screening pipeline.
%
% Usage:
%   sample = loadFundusImage("fundus.jpg")
%   sample = loadFundusImage("fundus.jpg", 'TargetSize', [224, 224])
%   sample = loadFundusImage("fundus.jpg", 'TargetSize', [512, 512], 'MaintainAspectRatio', true)
%   sample = loadFundusImage(rawImageMatrix, 'PatientID', "patient_042")
%
% Name-Value Parameters:
%   'TargetSize'          - [H, W] desired output dimension. Default: [] (keep original).
%   'MaintainAspectRatio' - Logical. If true and TargetSize provided, pads with black
%                           borders (letterboxing) to maintain aspect ratio. Default: false.
%   'PatientID'           - String/char identifier. Default: extracted from filename.
%
% Output:
%   sample - Standardized pipeline struct (conforms to Phase 1 specification).
%
% Reference:
%   Phase 1: Input and Data Interface

    % 1. Parse optional arguments
    p = inputParser;
    p.CaseSensitive = false;
    addRequired(p, 'source');
    addParameter(p, 'TargetSize', [], @(x) isempty(x) || (isnumeric(x) && (numel(x) == 2 || numel(x) == 3)));
    addParameter(p, 'MaintainAspectRatio', false, @(x) islogical(x) || isnumeric(x));
    addParameter(p, 'PatientID', "", @(x) isstring(x) || ischar(x));
    parse(p, source, varargin{:});

    targetSize          = p.Results.TargetSize;
    maintainAspectRatio = logical(p.Results.MaintainAspectRatio);
    patientID           = string(p.Results.PatientID);

    % Initialize standard struct
    sample = createSampleStruct();

    rawImg = [];
    filePath = "";
    meta = struct();

    % 2. Ingest source (file path or in-memory matrix)
    if isstring(source) || ischar(source)
        filePath = char(source);
        [isValid, errMsg, fileInfo] = validateFundusInput(filePath);
        if ~isValid
            error('loadFundusImage:InvalidInput', '%s', errMsg);
        end

        try
            % Read image and handle potential colormap/indexed formats
            [imgRead, map] = imread(filePath);
            if ~isempty(map)
                rawImg = ind2rgb(imgRead, map);
            else
                rawImg = imgRead;
            end
        catch ME
            error('loadFundusImage:ReadError', 'Failed to read image "%s": %s', filePath, ME.message);
        end

        % Extract metadata
        meta.fileSize = fileInfo.bytes;
        meta.fileDate = fileInfo.date;
        [~, baseName, ext] = fileparts(filePath);
        meta.fileName = [baseName, ext];
        meta.format   = ext;

        if patientID == ""
            patientID = string(baseName);
        end
    elseif isnumeric(source) || islogical(source)
        rawImg = source;
        if patientID == ""
            patientID = "in_memory_sample";
        end
        meta.fileName = "in_memory";
        meta.fileSize = numel(rawImg);
        meta.format   = "matrix";
    else
        error('loadFundusImage:InvalidSource', 'Source must be a file path string or an image matrix.');
    end

    % 3. Standardize to 3-channel RGB uint8
    standardizedRGB = convertToRGBUint8(rawImg);

    originalSize = size(standardizedRGB);
    sample.originalImage = standardizedRGB;
    sample.originalSize  = originalSize;
    sample.imageID       = patientID;
    sample.filePath      = string(filePath);

    % 4. Apply resizing if requested
    if ~isempty(targetSize)
        targetH = targetSize(1);
        targetW = targetSize(2);
        
        if maintainAspectRatio
            resizedImg = resizeWithLetterbox(standardizedRGB, targetH, targetW);
        else
            resizedImg = imresize(standardizedRGB, [targetH, targetW]);
        end
        sample.image = resizedImg;
    else
        sample.image = standardizedRGB;
    end

    sample.currentSize = size(sample.image);
    
    meta.originalDimensions = originalSize;
    meta.processedDimensions = sample.currentSize;
    meta.maintainedAspectRatio = maintainAspectRatio;
    sample.metadata = meta;
end

%% Helper: Ensure 3-channel RGB uint8 representation
function rgbImg = convertToRGBUint8(img)
    % Handle data types (convert float/double [0, 1] to uint8 [0, 255])
    if isfloat(img)
        if max(img(:)) <= 1.0
            img = uint8(round(img * 255));
        else
            img = uint8(img);
        end
    elseif islogical(img)
        img = uint8(img * 255);
    elseif ~isa(img, 'uint8')
        img = uint8(img);
    end

    dims = ndims(img);
    if dims == 2
        % Grayscale image -> replicate across 3 channels
        rgbImg = cat(3, img, img, img);
    elseif dims == 3
        numChannels = size(img, 3);
        if numChannels == 1
            rgbImg = cat(3, img, img, img);
        elseif numChannels == 3
            rgbImg = img;
        elseif numChannels >= 4
            % Strip alpha channel or excess channels
            rgbImg = img(:, :, 1:3);
        else
            error('convertToRGBUint8:UnexpectedChannels', 'Unexpected number of channels: %d', numChannels);
        end
    else
        error('convertToRGBUint8:InvalidDimensions', 'Image must be 2D or 3D matrix.');
    end
end

%% Helper: Letterbox / Pad maintaining aspect ratio
function paddedImg = resizeWithLetterbox(img, targetH, targetW)
    [origH, origW, numC] = size(img);
    scale = min(targetH / origH, targetW / origW);
    
    newH = round(origH * scale);
    newW = round(origW * scale);
    
    scaledImg = imresize(img, [newH, newW]);
    
    % Create black canvas
    paddedImg = zeros(targetH, targetW, numC, 'uint8');
    
    startH = floor((targetH - newH) / 2) + 1;
    startW = floor((targetW - newW) / 2) + 1;
    
    paddedImg(startH:startH+newH-1, startW:startW+newW-1, :) = scaledImg;
end
