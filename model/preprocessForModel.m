function [prepTensor, resizedRGB] = preprocessForModel(img, contract)
% PREPROCESSFORMODEL Formats fundus images according to the CNN model contract.
%
% Operations:
%   1. Ensures 3-channel RGB representation.
%   2. Resizes to the model's required input resolution (e.g. 224x224).
%   3. Applies specified normalization (e.g. ImageNet mean/std or [0, 1] scaling).
%   4. Formats into a single-precision 4D tensor [H, W, C, 1] for neural inference.
%
% Usage:
%   [prepTensor, resizedRGB] = preprocessForModel(img)
%   [prepTensor, resizedRGB] = preprocessForModel(img, contract)
%
% Inputs:
%   img      - RGB or Grayscale fundus image (uint8 or single/double).
%   contract - (Optional) Model contract struct from getModelContract.
%
% Outputs:
%   prepTensor - Single-precision normalized tensor [H, W, C, 1].
%   resizedRGB - Resized RGB image in uint8 [H, W, 3] (for overlay visualization).
%
% Reference:
%   Phase 6: CNN Inference Integration

    if nargin < 2 || isempty(contract)
        contract = getModelContract();
    end

    targetH = contract.inputSize(1);
    targetW = contract.inputSize(2);

    % 1. Ensure 3-channel RGB uint8 format
    if ndims(img) == 2
        imgRGB = cat(3, img, img, img);
    elseif ndims(img) == 3 && size(img, 3) >= 3
        imgRGB = img(:, :, 1:3);
    else
        error('preprocessForModel:InvalidChannels', 'Image must have 1, 3, or 4 channels.');
    end

    if isfloat(imgRGB)
        if max(imgRGB(:)) <= 1.0
            imgRGB = uint8(round(imgRGB * 255));
        else
            imgRGB = uint8(imgRGB);
        end
    end

    % 2. Resize to required input dimensions
    if size(imgRGB, 1) ~= targetH || size(imgRGB, 2) ~= targetW
        resizedRGB = imresize(imgRGB, [targetH, targetW]);
    else
        resizedRGB = imgRGB;
    end

    % 3. Convert to single precision [0, 1]
    tensor = single(resizedRGB) / 255.0;

    % 4. Apply Model Normalization
    normMethod = lower(contract.normalization);
    switch normMethod
        case 'imagenet'
            % Standard ImageNet mean and std subtraction
            meanVals = single(contract.imageNetMean);
            stdVals  = single(contract.imageNetStd);
            for c = 1:3
                tensor(:, :, c) = (tensor(:, :, c) - meanVals(c)) / stdVals(c);
            end
        case 'rescale'
            % Keep in [0.0, 1.0]
            % Already divided by 255.0
        case 'zero_centered'
            % Map [0, 1] -> [-1, 1]
            tensor = (tensor * 2.0) - 1.0;
        case 'none'
            tensor = single(resizedRGB);
        otherwise
            warning('preprocessForModel:UnknownNorm', ...
                'Unknown normalization "%s". Using ImageNet.', normMethod);
            meanVals = single(contract.imageNetMean);
            stdVals  = single(contract.imageNetStd);
            for c = 1:3
                tensor(:, :, c) = (tensor(:, :, c) - meanVals(c)) / stdVals(c);
            end
    end

    % 5. Add batch dimension: [H, W, C, 1]
    prepTensor = reshape(tensor, [targetH, targetW, 3, 1]);
end
