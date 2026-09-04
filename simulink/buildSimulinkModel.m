function modelName = buildSimulinkModel(varargin)
% BUILDSIMULINKMODEL Programmatically builds the Simulink Screening Workflow Model.
%
% Generates 'DR_Screening_System.slx' modeling the tele-ophthalmology workflow:
%   [Patient Arrival] --> [Acquisition & Recapture] --> [Network Transmission]
%                     --> [AI Processing Cluster]   --> [Doctor Review Queue]
%
% Usage:
%   buildSimulinkModel()
%
% Reference:
%   Phase 10: Simulink Workflow + System Validation

    modelName = 'DR_Screening_System';
    thisDir = fileparts(mfilename('fullpath'));
    modelPath = fullfile(thisDir, [modelName, '.slx']);

    % Check if Simulink is available in this MATLAB session
    hasSimulink = (exist('new_system', 'file') == 2);

    if ~hasSimulink
        fprintf('Notice: Simulink not installed in this environment. Discrete-event\n');
        fprintf('        workflow simulation is available via simulateScreeningWorkflow.m\n');
        return;
    end

    try
        % Close if already open
        if bdIsLoaded(modelName)
            close_system(modelName, 0);
        end

        % Create new blank system
        new_system(modelName);
        open_system(modelName);

        % Set model properties
        set_param(modelName, 'StopTime', '28800'); % 8 hours = 28,800 seconds
        set_param(modelName, 'Solver', 'VariableStepDiscrete');

        % Add Stage Subsystems
        add_block('built-in/Subsystem', [modelName, '/Patient_Arrival_Gen'], ...
            'Position', [40, 100, 140, 160]);
        add_block('built-in/Subsystem', [modelName, '/Acquisition_And_IQA'], ...
            'Position', [200, 100, 320, 160]);
        add_block('built-in/Subsystem', [modelName, '/Network_Upload_Uplink'], ...
            'Position', [380, 100, 500, 160]);
        add_block('built-in/Subsystem', [modelName, '/AI_GPU_Processing_Cluster'], ...
            'Position', [560, 100, 700, 160]);
        add_block('built-in/Subsystem', [modelName, '/Ophthalmologist_Review_Pool'], ...
            'Position', [760, 100, 900, 160]);
        add_block('built-in/Subsystem', [modelName, '/Final_Triage_Sink'], ...
            'Position', [960, 100, 1060, 160]);

        % Connect subsystems with signal lines
        add_line(modelName, 'Patient_Arrival_Gen/1', 'Acquisition_And_IQA/1');
        add_line(modelName, 'Acquisition_And_IQA/1', 'Network_Upload_Uplink/1');
        add_line(modelName, 'Network_Upload_Uplink/1', 'AI_GPU_Processing_Cluster/1');
        add_line(modelName, 'AI_GPU_Processing_Cluster/1', 'Ophthalmologist_Review_Pool/1');
        add_line(modelName, 'Ophthalmologist_Review_Pool/1', 'Final_Triage_Sink/1');

        % Save system
        save_system(modelName, modelPath);
        close_system(modelName);
        fprintf('Successfully generated Simulink model: %s\n', modelPath);

    catch ME
        warning('buildSimulinkModel:BuildFailed', ...
            'Simulink model generation encountered: %s. Programmatic simulation remains active.', ME.message);
    end
end
