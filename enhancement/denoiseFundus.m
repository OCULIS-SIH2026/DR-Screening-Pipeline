function denoisedImg = denoiseFundus(img, retinaMask, varargin)
% DENOISEFUNDUS Edge-preserving retinal denoising.
%
% Suppresses camera sensor and ISO noise while strictly preserving delicate
% microvascular edges and small lesion boundaries (e.g. microaneurysms).
%
% Usage:
%   denoisedImg = denoiseFundus(img)
%   denoisedImg = denoiseFundus(img, retinaMask)
%   denoisedImg = denoiseFundus(img, retinaMask, 'Method', 'bilateral')
%
% Inputs:
%   img        - RGB fundus image (uint8).
%   retinaMask - (Optional) Logical mask of the retinal area.
%
% Name-Value Parameters:
%   'Method' - 'bilateral' (default) or 'median3x3'.
%
% Outputs:
%   denoisedImg - Noise-reduced RGB fundus image (uint8).
%
% Reference:
%   Phase 3: Image Enhancement and Normalization

    p = inputParser;
    addRequired(p, 'img');
    addOptional(p, 'retinaMask', [], @(x) isempty(x) || islogical(x) || isnumeric(x));
    addParameter(p, 'Method', 'bilateral', @(x) ischar(x) || isstring(x));
    parse(p, img, retinaMask, varargin{:});

    mask = p.Results.retinaMask;
    if isempty(mask)
        [~, ~, mask] = assessFOV(img);
    else
        mask = logical(mask);
    end

    method = lower(char(p.Results.Method));
    [H, W, numC] = size(img);
    denoisedImg = img;

    hasBilateral = exist('imbilatfilt', 'file') == 2;

    for c = 1:numC
        ch = img(:, :, c);
        
        switch method
            case 'bilateral'
                if hasBilateral
                    % Gentle degree of smoothing to preserve microaneurysms
                    % DegreeOfSmoothing roughly scales the radiometric variance
                    chFilt = imbilatfilt(ch, 0.05 * 255, 2.0);
                else
                    % Fallback to 3x3 adaptive/median filter
                    chFilt = medfilt2(ch, [3, 3], 'symmetric');
                end
            case 'median3x3'
                chFilt = medfilt2(ch, [3, 3], 'symmetric');
            otherwise
                chFilt = medfilt2(ch, [3, 3], 'symmetric');
        end

        % Maintain zero-valued background outside retinal mask
        chFilt(~mask) = 0;
        denoisedImg(:, :, c) = chFilt;
    end
end
