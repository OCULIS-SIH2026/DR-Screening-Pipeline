function params = DR_Screening_System_params(varargin)
% DR_SCREENING_SYSTEM_PARAMS System configuration parameters for tele-screening workflow.
%
% Models a statewide/national tele-ophthalmology screening network processing
% 100,000+ patients per year across primary healthcare centers.
%
% Usage:
%   params = DR_Screening_System_params()
%   params = DR_Screening_System_params('AnnualVolume', 150000, 'NumAINodes', 4)
%
% Reference:
%   Phase 10: Simulink Workflow + System Validation

    p = inputParser;
    addParameter(p, 'AnnualVolume', 100000, @(x) isnumeric(x) && x > 0);
    addParameter(p, 'WorkDaysPerYear', 250, @(x) isnumeric(x) && x > 0);
    addParameter(p, 'ClinicHoursPerDay', 8, @(x) isnumeric(x) && x > 0);
    addParameter(p, 'NumAINodes', 4, @(x) isnumeric(x) && x > 0);
    addParameter(p, 'NumOphthalmologists', 3, @(x) isnumeric(x) && x > 0);
    addParameter(p, 'UploadBandwidthMbps', 10.0, @(x) isnumeric(x) && x > 0);
    addParameter(p, 'RecaptureRate', 0.12, @(x) isnumeric(x) && x >= 0 && x <= 1);
    addParameter(p, 'ReferralRate', 0.18, @(x) isnumeric(x) && x >= 0 && x <= 1);
    parse(p, varargin{:});

    params = struct();

    % 1. Patient & Clinic Volume
    params.annualVolume      = p.Results.AnnualVolume;
    params.workDaysPerYear   = p.Results.WorkDaysPerYear;
    params.clinicHoursPerDay = p.Results.ClinicHoursPerDay;
    
    % Derived arrival rates
    params.patientsPerDay    = params.annualVolume / params.workDaysPerYear;
    params.patientsPerHour   = params.patientsPerDay / params.clinicHoursPerDay;
    params.imagesPerPatient  = 2; % Both eyes (OD and OS)
    params.imagesPerDay      = params.patientsPerDay * params.imagesPerPatient;
    params.imagesPerHour     = params.patientsPerHour * params.imagesPerPatient;

    % 2. Image Acquisition Stage
    params.acquisitionTimeMin   = 3.5; % Average minutes per patient (positioning, dilating, capture)
    params.recaptureRate        = p.Results.RecaptureRate; % 12% field recapture
    params.imageSizeBytes       = 1.8 * 1024 * 1024; % 1.8 MB per compressed JPEG

    % 3. Network Transmission Stage
    params.uploadBandwidthMbps  = p.Results.UploadBandwidthMbps; % 10 Mbps clinic link
    % Transmission time per image in seconds
    params.uploadLatencySec     = (params.imageSizeBytes * 8) / (params.uploadBandwidthMbps * 1e6);

    % 4. Automated AI Pipeline Processing Stage (Phases 1-9)
    % Measured per-image processing breakdown (GPU-accelerated node)
    params.numAINodes           = p.Results.NumAINodes;
    params.iqaTimeSec           = 0.18; % Phase 2
    params.enhancementTimeSec   = 0.12; % Phase 3
    params.anatomyTimeSec       = 0.35; % Phase 4 (vessel & disc segmentation)
    params.lesionTimeSec        = 0.40; % Phase 5 (MA/HA/EX detection)
    params.cnnInferenceTimeSec  = 0.08; % Phase 6 (CNN forward pass)
    params.gradCAMTimeSec       = 0.15; % Phase 7 (Grad-CAM heatmap)
    params.decisionTimeSec      = 0.02; % Phase 8 (Referral & calibration)
    params.reportTimeSec        = 0.10; % Phase 9 (Visual dashboard & note)
    
    params.totalAITimePerImageSec = params.iqaTimeSec + params.enhancementTimeSec + ...
                                   params.anatomyTimeSec + params.lesionTimeSec + ...
                                   params.cnnInferenceTimeSec + params.gradCAMTimeSec + ...
                                   params.decisionTimeSec + params.reportTimeSec;
    
    % Effective AI node throughput
    params.aiThroughputPerNodeImgPerHour = 3600 / params.totalAITimePerImageSec;
    params.totalAIThroughputImgPerHour   = params.aiThroughputPerNodeImgPerHour * params.numAINodes;

    % 5. Human Ophthalmologist Review Stage
    params.numOphthalmologists     = p.Results.NumOphthalmologists;
    params.referralRate            = p.Results.ReferralRate; % 18% referable / borderline
    params.doctorReviewTimeSec     = 25.0; % Target: < 30 seconds per case using AI dashboard
    params.doctorCapacityImgPerHour = 3600 / params.doctorReviewTimeSec;
    params.totalDoctorCapacityPerHour = params.doctorCapacityImgPerHour * params.numOphthalmologists;
end
