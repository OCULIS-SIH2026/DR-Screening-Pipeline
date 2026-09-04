function [isValid, errMsg, fileInfo] = validateFundusInput(filePath)
% VALIDATEFUNDUSINPUT Validates image file existence, format, and readable dimensions.
%
% Usage:
%   [isValid, errMsg, fileInfo] = validateFundusInput(filePath)
%
% Inputs:
%   filePath - String or char vector indicating path to fundus image file.
%
% Outputs:
%   isValid  - Logical true if file exists and has supported format.
%   errMsg   - Error message string if invalid, empty string otherwise.
%   fileInfo - Structure containing file system information (dir output).

    isValid = true;
    errMsg = "";
    fileInfo = struct();

    if nargin < 1 || isempty(filePath) || (~isstring(filePath) && ~ischar(filePath))
        isValid = false;
        errMsg = "Image path must be a non-empty string or character vector.";
        return;
    end

    filePath = char(filePath);

    if ~exist(filePath, 'file')
        isValid = false;
        errMsg = sprintf("File not found at specified path: '%s'", filePath);
        return;
    end

    [~, ~, ext] = fileparts(filePath);
    supportedExts = {'.jpg', '.jpeg', '.png', '.tif', '.tiff', '.bmp'};
    if ~ismember(lower(ext), supportedExts)
        isValid = false;
        errMsg = sprintf("Unsupported file extension '%s'. Supported formats: %s", ...
            ext, strjoin(supportedExts, ', '));
        return;
    end

    d = dir(filePath);
    if isempty(d) || d.bytes == 0
        isValid = false;
        errMsg = sprintf("File is empty (0 bytes): '%s'", filePath);
        return;
    end

    fileInfo.bytes = d.bytes;
    fileInfo.date  = d.date;
    fileInfo.name  = d.name;
    fileInfo.ext   = ext;
end
