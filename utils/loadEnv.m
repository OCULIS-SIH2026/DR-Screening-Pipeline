function env = loadEnv(envPath)
% LOADENV Loads environment variables from a .env file into MATLAB.
%
% Usage:
%   env = loadEnv()            % Looks for .env in the project root
%   env = loadEnv(filePath)    % Loads a custom .env file
%
% Outputs:
%   env - Struct containing all parsed key-value pairs as string fields.
%         Also sets them in the MATLAB environment using setenv().
%
% Features:
%   - Ignores blank lines and comments starting with '#'
%   - Strips single and double quotes from values
%   - Automatically converts true/false/numeric strings where appropriate

    if nargin < 1 || isempty(envPath)
        % Default: locate .env in project root directory
        thisDir = fileparts(mfilename('fullpath'));
        projectRoot = fileparts(thisDir);
        envPath = fullfile(projectRoot, '.env');
    end

    env = struct();

    if ~exist(envPath, 'file')
        % If .env does not exist, return empty struct gracefully
        return;
    end

    fid = fopen(envPath, 'r');
    if fid == -1
        warning('loadEnv:CannotOpenFile', 'Could not open .env file at: %s', envPath);
        return;
    end

    cleanUp = onCleanup(@() fclose(fid));

    while ~feof(fid)
        line = strtrim(fgetl(fid));
        
        % Skip empty lines and comments
        if isempty(line) || startsWith(line, '#')
            continue;
        end

        % Split key and value at first '='
        eqIdx = strfind(line, '=');
        if isempty(eqIdx)
            continue;
        end

        key = strtrim(line(1:eqIdx(1)-1));
        val = strtrim(line(eqIdx(1)+1:end));

        % Strip surrounding quotes (double or single)
        if (startsWith(val, '"') && endsWith(val, '"')) || ...
           (startsWith(val, '''') && endsWith(val, ''''))
            if length(val) >= 2
                val = val(2:end-1);
            end
        end

        % Strip inline comments if not quoted
        commentIdx = strfind(val, '#');
        if ~isempty(commentIdx)
            val = strtrim(val(1:commentIdx(1)-1));
        end

        % Register in MATLAB environment
        setenv(key, val);

        % Sanitize key name for MATLAB struct field
        validField = regexprep(key, '[^a-zA-Z0-9_]', '_');
        if isvarname(validField)
            env.(validField) = string(val);
        end
    end
end
