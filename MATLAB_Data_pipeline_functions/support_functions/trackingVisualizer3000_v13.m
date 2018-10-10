function trackingVisualizer3000_v13(exptID,videoIDlist)
persistent rescreenResults

%%
%%%%% ENTER FUNCTION NAMES:
locator_name = 'flyLocator3000_v10';
tracker_name = 'flyTracker3000_v17';
analyzer_name = 'flyAnalyzer3000_v13';
debug = 0;
visualOps = [true false];%first is show figure, second is to save figure
getPitch = false;

if isempty(mfilename) || nargin == 0
%     exptID = '0019000003250129';
%     exptID = '0032000004300171';
%     exptID = '0058000003410437';

%     exptID = '0076000004300570'; % grating new at 2000 fps (10th frame)
    exptID = '0057000004300308'; % DL Ele_45 Azi_0 (looking at turn vel)
%     exptID = '0021000004300112'; % DL Ele_45 Azi_157(looking at turn vel)

%     exptID = '0058000003370437';%LC16 - turning and backing
%     exptID = '0041000004300282';% grating with normal rec rate (6000 fps)
%     exptID = '0041000004300400';% grating with unusual rec rate (500 fps)
    debug = 1;
else
    visualOps = [false false];
end

%%%% Establish data destination directory
%analysisDir = fullfile('\\tier2','card','Data_pez3000_analyzed');
analysisDir = fullfile('\\DM11','cardlab','Data_pez3000_analyzed');
expt_results_dir = fullfile(analysisDir,exptID);
if isempty(mfilename)
    rescreenResults = [];
end
if isempty(rescreenResults)
    rescreenResults = load('Z:\WryanW\rescreen_results_full.mat');
    rescreenResults = rescreenResults.rescreen_results_full;
end

autoAnnoName = [exptID '_automatedAnnotations.mat'];
autoAnnotationsPath = fullfile(expt_results_dir,autoAnnoName);
if exist(autoAnnotationsPath,'file') == 2
    autoAnnoTable_import = load(autoAnnotationsPath);
    dataname = fieldnames(autoAnnoTable_import);
    automatedAnnotations = autoAnnoTable_import.(dataname{1});
else
    if debug
        disp('no auto annotations')
    end
    return
end

manAnnoName = [exptID '_manualAnnotations.mat'];
manAnnotationsPath = fullfile(expt_results_dir,manAnnoName);
if exist(manAnnotationsPath,'file') == 2
    manAnnoTable_import = load(manAnnotationsPath);
    dataname = fieldnames(manAnnoTable_import);
    manualAnnotations = manAnnoTable_import.(dataname{1});
else
    if debug
        disp('no manual annotations')
    end
    return
end

%%%%% Load assessment table
assessmentPath = fullfile(expt_results_dir,[exptID '_rawDataAssessment.mat']);
assessTable_import = load(assessmentPath);
dataname = fieldnames(assessTable_import);
assessTable = assessTable_import.(dataname{1});

vidInfoMergedName = [exptID '_videoStatisticsMerged.mat'];
vidInfoMergedPath = fullfile(expt_results_dir,vidInfoMergedName);
vidInfo_import = load(vidInfoMergedPath);
dataname = fieldnames(vidInfo_import);
videoStatisticsMerged = vidInfo_import.(dataname{1});

manualAnnotations = fixManAnno(manualAnnotations,videoStatisticsMerged);

exptInfoMergedName = [exptID '_experimentInfoMerged.mat'];
exptInfoMergedPath = fullfile(expt_results_dir,exptInfoMergedName);
experimentInfoMerged = load(exptInfoMergedPath,'experimentInfoMerged');
exptInfo = experimentInfoMerged.experimentInfoMerged;
runList = get(exptInfo,'ObsNames');
if isempty(mfilename)
    saveTable = false;
else
    saveTable = true;
end
if exist('videoIDlist','var') && ~isempty(mfilename)
    visualOps(1) = true;
else
    videoIDlist = assessTable.Properties.RowNames;
end
vidCt = numel(videoIDlist);
varNames = {'finalStatus'
    'autoJumpTest'
    'autoFot'
    'manualJumpTest'
    'manualFot'
    'manual_wingup_wingdwn_legpush'
    'jumpEnd'
    'trkEnd'
    'stimInfo'
    'parentsInfo'
    'stimStart'
    'stimDuration'
    'stimType'
    'zeroFly_XYZmm_Tdeg_fac1000'
    'zeroFly_Trajectory'
    'zeroFly_Jump'
    'zeroFly_Departure'
    'zeroFly_StimAtStimStart'
    'zeroFly_StimAtJump'
    'zeroFly_StimAtFrmOne'
    'rawFly_XYZpix_Trad_frmOne'
    'distFromCenter_pix'
    'relMotion_FB_LR_Tdeg_fac100'
    'relPosition_FB_LR_Tdeg_fac100'
    'dist_speed_accel_fac100'
    'flyLength_mm'
    'frame_count'};

varBlanks = {cell(vidCt,1)
    zeros(vidCt,1)
    zeros(vidCt,1)
    zeros(vidCt,1)
    zeros(vidCt,1)
    cell(vidCt,1)
    zeros(vidCt,1)
    zeros(vidCt,1)
    cell(vidCt,1)
    cell(vidCt,1)
    zeros(vidCt,1)
    zeros(vidCt,1)
    cell(vidCt,1)
    cell(vidCt,1)
    zeros(vidCt,4)
    zeros(vidCt,4)
    zeros(vidCt,4)
    zeros(vidCt,1)
    zeros(vidCt,1)
    zeros(vidCt,1)
    zeros(vidCt,4)
    zeros(vidCt,2)
    cell(vidCt,1)
    cell(vidCt,1)
    cell(vidCt,1)
    zeros(vidCt,1)
    zeros(vidCt,1)};
graphTable = table(varBlanks{:},'VariableNames',varNames,'RowNames',videoIDlist);
%%
if isempty(mfilename) || nargin == 0
    vidCt = 2;
end
for iterV = 1:vidCt
    
    videoID = videoIDlist{iterV};
%     videoID = 'run028_pez3004_20160421_expt0076000004300571_vid0004';
    strParts = strsplit(videoID,'_');
    runID = [strParts{1} '_' strParts{2} '_' strParts{3}];
    if ~max(strcmp(runList,runID))
        graphTable.finalStatus(videoID) = {'runID from video not found'};
        continue
    end
    if ~max(strcmp(get(videoStatisticsMerged,'ObsNames'),videoID))
        graphTable.finalStatus(videoID) = {'vidStats/assessTable mismatch'};
        continue
    end
    vidStats = videoStatisticsMerged(videoID,:);
    if strcmp(assessTable.Raw_Data_Decision{videoID},'Fail')
        graphTable.finalStatus(videoID) = {'Raw data fail'};
        continue
    end
    
    analyzer_summary_dir = [expt_results_dir filesep exptID '_' analyzer_name '_visualMontage'];
    analyzer_expt_ID = [videoID '_' analyzer_name '_data.mat'];%experiment ID
    analyzer_data_dir = fullfile(expt_results_dir,[exptID '_' analyzer_name]);
    analyzer_data_path = fullfile(analyzer_data_dir,analyzer_expt_ID);
    analyzed_vis_path = fullfile(analyzer_summary_dir,[videoID '_' analyzer_name '_visualization.tif']);
    
    %%%% Analyzer table
    if exist(analyzer_data_path,'file') == 2
        analysis_data_import = load(analyzer_data_path);
        dataname = fieldnames(analysis_data_import);
        analysis_record = analysis_data_import.(dataname{1});
        graphTable.finalStatus(videoID) = analysis_record.final_outcome(1);
        if ~strcmp(analysis_record.final_outcome{1},'analyzed')
            continue
        end
    else
        graphTable.finalStatus(videoID) = {'No analyzer file'};
        continue
    end
    dist_vec_mm = analysis_record.net_dist_filt{1};
    speed_vec_frm = analysis_record.speed{1};
    accel_vec_frm = analysis_record.acceleration{1};
    XYZ_3D_filt = analysis_record.XYZ_3D_filt{1};
    zero_netXYZ = XYZ_3D_filt-repmat(XYZ_3D_filt(1,:),size(XYZ_3D_filt,1),1);
    frms_per_ms = double(vidStats.record_rate)/1000;
%     smoothWin = round(frms_per_ms);
%     if smoothWin < 3, smoothWin = 3; end
%     for iterFilt = 1:3
%         zero_netXYZ(:,iterFilt) = smooth(zero_netXYZ(:,iterFilt),smoothWin);
%     end
    
    fc = 100; % cutoff frequency
    fs = frms_per_ms*1000; % sample rate
    filtHz = fc/(fs/2);
    d1 = designfilt('lowpassiir','FilterOrder',5, ...
        'HalfPowerFrequency',filtHz,'DesignMethod','butter');
%     figure
%     plot(zero_netXYZ(:,1))
    for iterFilt = 1:3
        zero_netXYZ(:,iterFilt) = filtfilt(d1,zero_netXYZ(:,iterFilt));
    end
%     hold on
%     plot(zero_netXYZ(:,1))
%     return
    roiPos = assessTable.Adjusted_ROI{videoID};
    vidWidth = double(vidStats.frame_width);
    vidHeight = double(vidStats.frame_height);
    roiPos = [roiPos(2:3,1) roiPos(1:2,2)-(vidHeight-vidWidth+1)];
    roiPos(roiPos < 1) = 1;
    roiPos(roiPos > vidWidth) = vidWidth;
    prismW = mean(roiPos(2,:)-roiPos(1,:)-30);%minus 30 to account for roi swell in pezControl_v9
    
    %accounts for the fact that some people don't check to be sure it's right
    if prismW > 245, prismW = 245; end
    if prismW < 225, prismW = 225; end
    
    pix2mm = @(x) x.*(5/prismW);%prism is 5mm
    % mm2pix = @(x) x.*(prismW/5);%prism is 5mm
    deg2rad = @(x) x.*(pi/180);
    rad2deg = @(x) x.*(180/pi);
    
    
    
    manFot = manualAnnotations.frame_of_take_off{videoID};
    if ~isempty(manFot)
        if ~isnan(manFot)
            manJumpTest = true;
        else
            manJumpTest = false;
        end
        if max(strcmp(rescreenResults.Properties.RowNames,videoID))
            manJumpTest = logical(rescreenResults.rescreen_results(videoID));
        end
    else
        manJumpTest = NaN;
    end
    
    auto_fot = automatedAnnotations.autoFrameOfTakeoff{videoID};
    autoJumpTest = automatedAnnotations.jumpTest{videoID};
    if isempty(auto_fot)
        autoJumpTest = false;
    end
    trk_end = analysis_record.final_frame_tracked{1};
    jumpEnd = NaN;
    if autoJumpTest && (auto_fot <= trk_end)
        jumpEnd = auto_fot;
    end
    
    %%%%%%%%%%%%%%%%%%%%%% Compiling data to output %%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    %%%%% Jump-related information
    graphTable.manualJumpTest(videoID) = manJumpTest;
    graphTable.manualFot(videoID) = NaN;
    graphTable.manual_wingup_wingdwn_legpush(videoID) = {[NaN NaN NaN]};
    if ~isnan(manFot)
        if ~isempty(manFot)
            if manFot > 1
                if manJumpTest
                    if manFot <= trk_end
                        jumpEnd = manFot;
                    end
                    graphTable.manualFot(videoID) = manFot;
                    fowu = manualAnnotations.frame_of_wing_movement{videoID};
                    fowd = manualAnnotations.wing_down_stroke{videoID};
                    folp = manualAnnotations.frame_of_leg_push{videoID};
                    graphTable.manual_wingup_wingdwn_legpush(videoID) = {[fowu fowd folp]};
                end
            end
        end
    end
    
    graphTable.jumpEnd(videoID) = jumpEnd;
    graphTable.trkEnd(videoID) = trk_end;
    graphTable.autoFot(videoID) = NaN;
    graphTable.autoJumpTest(videoID) = autoJumpTest;
    if autoJumpTest
        graphTable.autoFot(videoID) = auto_fot;
    end
    
    %%%%% Referencing and indexing information
    %%%%% Stimulus information
    stimStr = '';
    stimStart = NaN;
    stim_dur = NaN;
    
    visStimType = exptInfo.Stimuli_Type{1};
    visStimTest = false;
    if ~strcmp('None',visStimType)
        if ~strcmp('Template_making',visStimType)
            visStimTest = true;
        end
    end
    activationStrCell = exptInfo.Photo_Activation{1};
    if ischar(activationStrCell)
        activationStrCell = {activationStrCell};
    end
    if ~strcmp('None',activationStrCell{1})
        photoStimTest = true;
    else
        photoStimTest = false;
    end
    if photoStimTest && visStimTest
        exptType = 'Combo';
    elseif photoStimTest
        exptType = 'Photoactivation';
    elseif visStimTest
        exptType = 'Visual_stimulation';
    elseif strcmp('Template_making',visStimType)
        exptType = 'Template_making';
    elseif strcmp('None',visStimType) && strcmp('None',activationStrCell{1})
        exptType = 'None';
    else
        exptType = 'Unknown';
    end
    graphTable.stimType(videoID) = {exptType};
    if strcmp(exptType,'Visual_stimulation')
        stimStr = [exptInfo.Stimuli_Type{runID} '_ele' exptInfo.Stimuli_Vars(runID).Elevation,...
            '_azi' exptInfo.Stimuli_Vars(runID).Azimuth];
        stimStart = automatedAnnotations.visStimFrameStart{videoID};
        stim_dur = automatedAnnotations.visStimFrameCount{videoID};
    elseif strcmp(exptType,'Photoactivation')
        stimStr = automatedAnnotations.photoStimProtocol{videoID};
        stimStart = automatedAnnotations.photoStimFrameStart{videoID};
        stim_dur = automatedAnnotations.photoStimFrameCount{videoID};
    elseif strcmp(exptType,'Combo')
        stimStr = 'combo';
        stimStart = automatedAnnotations.visStimFrameStart{videoID};
        stim_dur = automatedAnnotations.visStimFrameCount{videoID};
    elseif max(strcmp({'None','Template_making'},exptType))
        stimStr = 'no visual stimulus';
        stimStart = 1;
        stim_dur = vidStats.frame_count;
    else
        if debug && iterV == 1
            disp('wrong or unknown expt type')
        end
    end
    if isempty(stimStart)
        stimStart = 1;
    end
    if isempty(stim_dur)
        stimStr = 'unknown';
        stim_dur = Inf;
    end
    if isempty(stimStr)
        if debug && iterV == 1
            disp('empty stimulus string')
        end
    end
    
    graphTable.stimInfo(videoID) = {stimStr};
    parentInfo = sort([exptInfo.ParentA_name(runID) exptInfo.ParentB_name(runID)]);
    parentInfo = cat(2,parentInfo{1},'_cross2_',parentInfo{2});
    graphTable.parentsInfo(videoID) = {parentInfo};
    if stimStart < 1, stimStart = 1; end
    
    %%%%%%%%%%%%%%%%%%%%%% CORRECTION FOR NIDAQ/CAMERA ERROR %%%%%%%%%%%%%%
    dateIDnum = datenum(datevec(strParts{3},'yyyymmdd'));
    dateBugWasFixed = datenum(datevec('20161206','yyyymmdd'));
    if dateIDnum < dateBugWasFixed
        if strcmp(deblank(vidStats.device_name{1}),'FASTCAM SA-X2 type 480K-M2')
            stimStart = stimStart+round(10*frms_per_ms);
        elseif strcmp(deblank(vidStats.device_name{1}),'FASTCAM SA4 model 500K-M1')
            stimStart = stimStart+round(3*frms_per_ms);
        else
            error('unknown camera')
        end
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    graphTable.stimStart(videoID) = stimStart;
    graphTable.stimDuration(videoID) = stim_dur;
    graphTable.frame_count(videoID) = double(vidStats.frame_count(1));
    
    %%% determine departure trajectory
    % dept_shape = analysis_record.departure_shape{1};
    % shape_confidence = analysis_record.shape_confidence{1};
    if strcmp(assessTable.Fly_Detect_Accuracy{videoID},'Good')
        if strcmp(exptType,'Visual_stimulation')
            stim_azi = analysis_record.stimulus_azimuth{1};
        else
            stim_azi = deg2rad(vidStats.fly_detect_azimuth);
        end
    else
        stim_azi = NaN;
    end
    az_traj = analysis_record.departure_az_ele_rad{1}(1);
    ele_traj = analysis_record.departure_az_ele_rad{1}(2);
    r_traj = analysis_record.departure_az_ele_rad{1}(3);
    
    
    botTheta_filt = analysis_record.bot_points_and_thetas{1}(:,3);
    graphTable.rawFly_XYZpix_Trad_frmOne(videoID,:) = [analysis_record.bot_points_and_thetas{1}(1,1:2),...
        analysis_record.top_points_and_thetas{1}(1,2) botTheta_filt(1)];
%     botTheta_filt = smooth(unwrap(botTheta_filt),smoothWin);
    botTheta_filt = filtfilt(d1,unwrap(botTheta_filt));
    jumpFrmCt = round(frms_per_ms*5);
    if stimStart <= trk_end
        fly_theta_at_stim_start = botTheta_filt(stimStart);%sets init theta to fly heading at stim start
    else
        fly_theta_at_stim_start = NaN;
    end
    flyLength = analysis_record.fly_length{1};
    graphTable.flyLength_mm(videoID) = pix2mm(flyLength);
    jumpStart = jumpEnd-jumpFrmCt;
    jumpStart(jumpStart < 1) = 1;
    
    %%%% declare jump related variable that might not work out
    zeroFlyJump = [NaN NaN];
    zeroFlyStimJump = NaN;
    ele_deprt = NaN;
    rho_deprt = NaN;
    ele_jump = NaN;
    rho_jump = NaN;
    zeroFlyDept = [NaN NaN];
    % xyzDiffPost = NaN(1,3);
    % xyzDiffPre = NaN(1,3);
    roiCenter = mean(roiPos);
    xyFlyPos = XYZ_3D_filt(1,1:2);
    centerDist = [sqrt(sum((xyFlyPos-roiCenter).^2)) NaN];
    if ~isnan(jumpEnd)
        postJump = jumpEnd+round(str2double(exptInfo.Record_Rate{runID})/1000*1.5);
        jump_theta = botTheta_filt(jumpStart);%sets init theta to fly heading before jump
        xyzDiffPre = zero_netXYZ(jumpEnd,:)-zero_netXYZ(jumpStart,:);
        [az_jump,ele_jump,rho_jump] = cart2sph(xyzDiffPre(1),-xyzDiffPre(2),-xyzDiffPre(3));
        uv_zeroFlyJump = [cos(az_jump-jump_theta) -sin(az_jump-jump_theta)].*rho_jump;
        [theta,rho] = cart2pol(uv_zeroFlyJump(1),-uv_zeroFlyJump(2));
        zeroFlyJump = [theta,pix2mm(rho)];
        if postJump <= trk_end
            xyzDiffPost = zero_netXYZ(postJump,:)-zero_netXYZ(jumpEnd,:);
            [az_deprt,ele_deprt,rho_deprt] = cart2sph(xyzDiffPost(1),-xyzDiffPost(2),-xyzDiffPost(3));%z must be negative because tracking was done in image space
            uv_zeroFlyDept = [cos(az_deprt-jump_theta) -sin(az_deprt-jump_theta)].*rho_deprt;
            theta = cart2pol(uv_zeroFlyDept(1),-uv_zeroFlyDept(2));
            zeroFlyDept = [theta,pix2mm(sqrt(sum(xyzDiffPost(1:2).^2)))];
        end
        uv_zeroFlyStimJump = [cos(stim_azi-jump_theta) -sin(stim_azi-jump_theta)];
        zeroFlyStimJump = cart2pol(uv_zeroFlyStimJump(1),-uv_zeroFlyStimJump(2));
        xyFlyPos = XYZ_3D_filt(jumpStart,1:2);
        centerDist(2) = sqrt(sum((xyFlyPos-roiCenter).^2));
    end
    graphTable.distFromCenter_pix(videoID,:) = centerDist;
    
    
    uv_zeroFlyDepart = [cos(az_traj-fly_theta_at_stim_start) -sin(az_traj-fly_theta_at_stim_start)].*r_traj;
    [theta,rho] = cart2pol(uv_zeroFlyDepart(1),-uv_zeroFlyDepart(2));
    zeroFlyTraj = [theta,pix2mm(rho)];
    
    uv_zeroFlyStimInit = [cos(stim_azi-fly_theta_at_stim_start) -sin(stim_azi-fly_theta_at_stim_start)];
    zeroFlyStimInit = cart2pol(uv_zeroFlyStimInit(1),-uv_zeroFlyStimInit(2));
    
    uv_zeroFlyStimFrmOne = [cos(stim_azi-botTheta_filt(1)) -sin(stim_azi-botTheta_filt(1))];
    zeroFlyStimFrmOne = cart2pol(uv_zeroFlyStimFrmOne(1),-uv_zeroFlyStimFrmOne(2));
    
    zero_netXYZmm = pix2mm(zero_netXYZ);
    [zeroFlyXY_theta,zeroFlyXY_rho] = cart2pol(zero_netXYZmm(1:trk_end,1),-zero_netXYZmm(1:trk_end,2));
    zeroFlyXY_theta = zeroFlyXY_theta-fly_theta_at_stim_start;
    zeroFlyBotTheta = (botTheta_filt(1:trk_end)-fly_theta_at_stim_start);
    
    stimInfo = exptInfo.Stimuli_Type{1};
    splitCell = strsplit(stimInfo,'_');
    %%% no 'flipping' if grating is used
    if zeroFlyStimInit < 0 && isempty(strfind(splitCell{1},'grating'))
        zeroFlyXY_theta = zeroFlyXY_theta*(-1);
        zeroFlyStimInit = zeroFlyStimInit*(-1);
        zeroFlyStimFrmOne = zeroFlyStimFrmOne*(-1);
        zeroFlyTraj = zeroFlyTraj.*[-1 1];
        zeroFlyStimJump = zeroFlyStimJump*(-1);
        zeroFlyJump = zeroFlyJump.*[-1 1];
        zeroFlyDept = zeroFlyDept.*[-1 1];
        zeroFlyBotTheta = zeroFlyBotTheta*(-1);
    end
    
    [zeroFlyX,zeroFlyY] = pol2cart(zeroFlyXY_theta,zeroFlyXY_rho);
    zeroFly_XY = [zeroFlyX(:),zeroFlyY(:)];
%     [plotx,ploty] = pol2cart(zeroFlyTraj(1),zeroFlyTraj(2));
%     plot(plotx,ploty,'.','markersize',12)

%     hplot = plot((zeroFlyX),(zeroFlyY));
%     set(gca,'xlim',[-4 4], 'ylim',[-4 4])
%     hold on
%     distTally = 0;
%     plotc = get(hplot,'color');
%     for iterTheta = 2:numel(zeroFlyX)
%         distTally = distTally+sqrt(sum((zeroFly_XY(iterTheta,:)-zeroFly_XY(iterTheta-1,:)).^2,2));
%         if distTally > 0.5
%             arrowL = 0.25;
%             u = cos(zeroFlyXY_theta(iterTheta))*arrowL; v = -sin(zeroFlyXY_theta(iterTheta))*arrowL;
%             quiver(zeroFly_XY(iterTheta,1),zeroFly_XY(iterTheta,2),u,v,'color',plotc)
%             distTally = 0;
%         end
%     end
    zeroFly_XYZmm = [zeroFly_XY zero_netXYZmm(1:trk_end,3)];
    posTestVec = findEdgeGaps_tracking(videoID);
    posTestVec = posTestVec(1:trk_end);
    posFail = false;
    if posTestVec(end)
        lastRef = find(~posTestVec,1,'last');
        if isempty(lastRef)
            lastRef = 1;
            posFail = true;
        end
        zeroFlyBotTheta(lastRef:end) = NaN;
    end
    
    zeroFly_XYZmm_Tdeg_fac1000 = cat(2,zeroFly_XYZmm.*1000,rad2deg(zeroFlyBotTheta));
    graphTable.zeroFly_XYZmm_Tdeg_fac1000(videoID) = {int16(zeroFly_XYZmm_Tdeg_fac1000)};
    
    %%%% Azimuth, x/y rho, elevation, 3-D rho
    graphTable.zeroFly_Trajectory(videoID,:) = cat(2,rad2deg(zeroFlyTraj(1)),...
        zeroFlyTraj(2),rad2deg(ele_traj),pix2mm(r_traj));
    graphTable.zeroFly_Jump(videoID,:) = cat(2,rad2deg(zeroFlyJump(1)),...
        zeroFlyJump(2),rad2deg(ele_jump),pix2mm(rho_jump));
    graphTable.zeroFly_Departure(videoID,:) = cat(2,rad2deg(zeroFlyDept(1)),...
        zeroFlyDept(2),rad2deg(ele_deprt),pix2mm(rho_deprt));
    
    graphTable.zeroFly_StimAtStimStart(videoID) = rad2deg(zeroFlyStimInit);
    graphTable.zeroFly_StimAtJump(videoID) = rad2deg(zeroFlyStimJump);
    graphTable.zeroFly_StimAtFrmOne(videoID) = rad2deg(zeroFlyStimFrmOne);
    
    
    
    posXYZ = zeroFly_XYZmm;
    posXYZ = abs(cat(1,[0 0 0],diff(posXYZ)));
    posXYZ = cumsum(sqrt(sum(posXYZ.^2,2)));
    if ~isempty(strfind(splitCell{1},'grating'))
        winFull = 501;
        winFullAbs = winFull;
    else
        winLegAbs = round(frms_per_ms);
        winFullAbs = (winLegAbs*2)+1;
        winLeg = round(frms_per_ms)*10;
        winFull = (winLeg*2)+1;
    end
    if winFullAbs < 9
        %%% These must be slower yet not gratings....not sure what to do,
        %%% so I'm guessing on the window sizes here
        winFullAbs = 9;
        winFull = winFullAbs*2+1;
        if iterV == 1, disp('filter window adjusted'), end
    end
    motionTest = trk_end > winFull && ~isnan(fly_theta_at_stim_start) && ~posFail;
    if motionTest
        %%
        posXYZ = posXYZ(1:trk_end);
        [distVec,speedVec,accelVec] = golayDifferentiate(posXYZ,winFullAbs);
        speedVec = speedVec/1000*double(vidStats.record_rate);%m/s
        accelVec = accelVec/1000*double(vidStats.record_rate).^2;%m/s2
        distVec(isnan(distVec)) = [];
        speedVec(isnan(speedVec)) = [];
        accelVec(isnan(accelVec)) = [];
        
        %%% Lateral motion, longitudinal motion, and turning
        [dataXpos,dataXvel] = golayDifferentiate(zeroFly_XYZmm(:,1),winFull);
        [dataYpos,dataYvel] = golayDifferentiate(zeroFly_XYZmm(:,2),winFull);
        dataXYvel = cat(2,dataXvel,dataYvel);
        dataXYpos = cat(2,dataXpos,dataYpos);
        [dataTpos,dataTvel] = golayDifferentiate(unwrap(zeroFlyBotTheta),winFull);
        if posTestVec(end)
            dataTpos(lastRef:end) = NaN;
            dataTvel(lastRef:end) = NaN;
        end
        [velT,velR] = cart2pol(dataXYvel(:,1),-dataXYvel(:,2));
        [posT,posR] = cart2pol(dataXYpos(:,1),-dataXYpos(:,2));
        [relXvel,relYvel] = pol2cart(velT-dataTpos,velR);
        [relXpos,relYpos] = pol2cart(posT-dataTpos,posR);
        
%         if iterV < 30
%             if ~exist('yoff','var')
%                 yoff = -2;
%             else
%                 yoff = yoff+2;
%             end
%             plot(relYpos+yoff,relXpos,'color','b');
%             hold on
%             plot(relYpos(1)+yoff,relXpos(1),'.','color','k','markersize',14);
%             dirRefs = (1:150:numel(relYpos));
%             for iterD = 1:numel(dirRefs)-1
%                 u = cos(dataTpos(dirRefs(iterD))-pi/2)*(0.15);
%                 v = -sin(dataTpos(dirRefs(iterD))-pi/2)*(0.15);
%                 quiver(relYpos(dirRefs(iterD))+yoff,relXpos(dirRefs(iterD)),u,v,'color','b','linewidth',2)
%             end
%             relXpos = cumsum(relXvel);
%             relYpos = cumsum(relYvel);
%             plot(relYpos+yoff,relXpos,'color','r');
%             plot(relYpos(1)+yoff,relXpos(1),'.','color','k','markersize',14);
%             dirRefs = (1:150:numel(relYpos));
%             dataTpos = cumsum(dataTvel);
%             for iterD = 1:numel(dirRefs)-1
%                 u = cos(dataTpos(dirRefs(iterD))-pi/2)*(0.15);
%                 v = -sin(dataTpos(dirRefs(iterD))-pi/2)*(0.15);
%                 quiver(relYpos(dirRefs(iterD))+yoff,relXpos(dirRefs(iterD)),u,v,'color','r','linewidth',2)
%             end
%             continue
%         else
%             return
%         end
%         %%
        relXvel = relXvel/1000*double(vidStats.record_rate);%m/s
        relYvel = relYvel/1000*double(vidStats.record_rate);%m/s
        dataTvel = rad2deg(dataTvel)*double(vidStats.record_rate);%deg/s
        relXvel(isnan(relXvel)) = [];
        relYvel(isnan(relYvel)) = [];
        dataTvel(isnan(dataTvel)) = [];
        
        dataTpos = rad2deg(dataTpos);
        relXpos(isnan(relXpos)) = [];
        relYpos(isnan(relYpos)) = [];
        dataTpos(isnan(dataTpos)) = [];
        fastTest = abs(dataTvel) > 360;
        fastFail = false;
        if ~isempty(fastTest) && fastTest(end)
            fastRef = find(~fastTest,1,'last');
            if isempty(fastRef)
                fastRef = 1;
                fastFail = true;
            end
            relXpos(fastRef:end) = [];
            relYpos(fastRef:end) = [];
            dataTpos(fastRef:end) = [];
            
            relXvel(fastRef:end) = [];
            relYvel(fastRef:end) = [];
            dataTvel(fastRef:end) = [];
        end
        

    end
    if ~motionTest || fastFail
        accelVec = NaN;
        speedVec = NaN;
        distVec = NaN;
        relXvel = NaN;
        relYvel = NaN;
        dataTvel = NaN;
        relXpos = NaN;
        relYpos = NaN;
        dataTpos = NaN;
    end
%     plot(dataTvel)
%     hold all
    graphTable.relMotion_FB_LR_Tdeg_fac100(videoID) = {([relXvel relYvel dataTvel]*100)};
    graphTable.relPosition_FB_LR_Tdeg_fac100(videoID) = {([relXpos relYpos dataTpos]*100)};
    graphTable.dist_speed_accel_fac100(videoID) = {([distVec(:) speedVec(:) accelVec(:)]*100)};
    
    if visualOps(2)
        visualOps(1) = true;
    end
    
    %%%%% Reasons to load locator and tracking data
    if max([visualOps(1),getPitch])
        tracker_expt_ID = [videoID '_' tracker_name '_data.mat'];
        tracker_data_dir = fullfile(expt_results_dir,[exptID '_' tracker_name]);
        if ~isdir(tracker_data_dir), mkdir(tracker_data_dir),end
        tracker_data_path = fullfile(tracker_data_dir,tracker_expt_ID);
        if exist(tracker_data_path,'file') == 2
            tracker_data_import = load(tracker_data_path);
            dataname = fieldnames(tracker_data_import);
            tracker_record = tracker_data_import.(dataname{1});
        end
        %     if getTrackingVectors(1)
        %         graphTable.wings = {int16(tracker_record.wings_trk{1}*100)};
        %     end
        
        %%%%% Load locator data
        locDir = fullfile(expt_results_dir,[exptID '_' locator_name]);
        locator_data_path = fullfile(locDir,[videoID '_' locator_name '_data.mat']);
        if exist(locator_data_path,'file')
            locator_record = load(locator_data_path);
            dataname = fieldnames(locator_record);
            locator_record = locator_record.(dataname{1});
        end
        mvnt_frms = tracker_record.mvmnt_ref{1};
        nFrames = numel(mvnt_frms);
        top_centroid_filt = analysis_record.top_points_and_thetas{1}(:,1:2);
        if getPitch == 1
            topMinRho = tracker_record.top_min_rho{1};
            topTest = topMinRho;
            topTest(topTest == 0) = NaN;
            topTheta_filt = analysis_record.top_points_and_thetas{1}(:,3);
            topMajRho_filt = analysis_record.top_points_and_thetas{1}(:,4);
            topMinRho_filt = analysis_record.top_points_and_thetas{1}(:,5);
            median_rho = nanmedian(topTest);
            %%%%%%%%%%%%% KEEPING IN CASE I WANT TO TEST ALTERNATIVES OR TO CALCULATE PITCH
            %%%% Re-establish bottom-view centroid
            loc_flyLength = locator_record.fly_length{:};
            max_ratio = abs((loc_flyLength/2)-median_rho);
            actual_ratio = abs(topMajRho_filt-topMinRho_filt).*abs(sin(topTheta_filt));
            length_factor = actual_ratio./(max_ratio);
            pitch_factor = 1-(sin((-pi/2).*(1-length_factor))+1);
            pitchVector = (topTheta_filt.*(1-pitch_factor))/(pi/180);
            graphTable.pitch(videoID) = {uint8(pitchVector)};
%             maxPitch = max(pitchVector);
%             graphTable.pitch75frm = [maxPitch*0.75 find(pitchVector > maxPitch*0.75,1,'first')];
        end
    end
    if visualOps(1)
        %% %% Formulate position changes in 3D, zeroed at frame_0001
        bot_centroid_filt = analysis_record.bot_points_and_thetas{1}(:,1:2);
        
        %%%%% determine frames used in visualization and deptarture trajectory
        vis_refs = analysis_record.ten_sample_points{1};
        vis_count = numel(vis_refs);

        %%%%% Generate the visual sample frame
        finc = hsv(round(vis_count*1.5));
        finc = finc(1:vis_count,:);
        finc = flipud(finc);
        visIm = imread(analyzed_vis_path);
        frm_demo = visIm;
        padSize = 2;
        vidWidth = size(visIm,2);
        vidHeight = size(visIm,1);
        frm_demo = imcrop(frm_demo,[0 0 vidWidth-padSize*2 vidHeight-padSize*2]);
        visual_frame = padarray(frm_demo,[padSize padSize],255);
        % imshowpair(visual_frame,BW1,'montage')
        
        %%%% Initialize image handle and tracking variables
        close all
        scrn_size = get(0,'ScreenSize');
        fig_posB = round([scrn_size(3)*0.01 scrn_size(4)*0.05,...
            scrn_size(3)*0.9 scrn_size(4)*0.85]);
        figure('Position',fig_posB,'Color',[0 0 0])
        colormap('gray')
        font_size = 12;
        txt_colr = [1 1 1];
        back_colr = [0 0 0];
        plotc = finc(1:vis_count,:);
        graphc = [0.95 0.95 0.95];
        % raw_plotC = [0.75 0 0];
        
        %%%%% Generate new image and label it
        subplot(3,3,[1 4 7]), imshow(visual_frame)
        botXadjust = vidHeight-vidWidth+1;
        hold on
        text(1,vidWidth*2+150,['Frames:  ' num2str(vis_refs)],...
            'HorizontalAlignment','left','FontWeight','bold',...
            'Color',[1 1 1],'FontSize',font_size)
        text(1,-50,['Video ID:  ' videoID],...
            'HorizontalAlignment','left','FontWeight','bold',...
            'Color',[1 1 1],'FontSize',font_size,'Interpreter','none')
        
        %%%%% Place points on the fly
        top_centroid = top_centroid_filt(vis_refs,:);
        %     top_centroid = [analysis_record.XYZ_separate_position{1}(vis_refs,1)+top_centroid(1,1),...
        %         analysis_record.XYZ_separate_position{1}(vis_refs,3)+top_centroid(1,2)];
        
        bot_centroid = bot_centroid_filt(vis_refs,:);
        %     bot_centroid = [analysis_record.XYZ_separate_position{1}(vis_refs,1)+bot_centroid(1,1),...
        %         analysis_record.XYZ_separate_position{1}(vis_refs,2)+bot_centroid(1,2)];
        
        
        bot_thetaPlot = botTheta_filt(vis_refs,:);
        %     bot_thetaPlot = analysis_record.XYZ_separate_position{1}(vis_refs,4);
        for iterE = 1:vis_count
            vixPlotX = [bot_centroid(iterE,1);top_centroid(iterE,1)];
            vixPlotY = [bot_centroid(iterE,2)+botXadjust;top_centroid(iterE,2)];
            plot(vixPlotX,vixPlotY,'.','MarkerSize',40,'Color',[0 0 0])
        end
        if ~isnan(stim_azi)
            u_stim = cos(stim_azi)*(flyLength/2); v_stim = -sin(stim_azi)*(flyLength/2);
            quiver(bot_centroid(1,1),bot_centroid(1,2)+botXadjust,u_stim,v_stim,...
                'MaxHeadSize',0,'LineWidth',3,'AutoScaleFactor',1,'Color',[1 1 1])
            quiver(100,botXadjust,uv_zeroFlyStimInit(1),uv_zeroFlyStimInit(1),'MaxHeadSize',0,...
                'LineWidth',3,'AutoScaleFactor',1,'Color',[1 1 1])
        end
        arrowL = sqrt(sum((bot_centroid(end,:)-bot_centroid(1,:)).^2));
        u_deprt = cos(az_traj)*arrowL; v_deprt = -sin(az_traj)*arrowL;
        quiver(bot_centroid(1,1),bot_centroid(1,2)+botXadjust,u_deprt,v_deprt,...
            'ShowArrowHead','off','LineWidth',6,'AutoScaleFactor',1,'Color',[0 0 0])
        quiver(bot_centroid(1,1),bot_centroid(1,2)+botXadjust,u_deprt,v_deprt,...
            'ShowArrowHead','off','LineWidth',2,'AutoScaleFactor',1,'Color',[1 1 1])
        
        u_zeroFlyFly = cos(0)*(flyLength/2);
        v_zeroFlyFly = -sin(0)*(flyLength/2);
        quiver(100,botXadjust,u_zeroFlyFly,v_zeroFlyFly,'MaxHeadSize',0.5,...
            'LineWidth',2,'AutoScaleFactor',1,'Color',[1 0 0])
        quiver(100,botXadjust,uv_zeroFlyDepart(1),uv_zeroFlyDepart(1),'MaxHeadSize',0.5,...
            'LineWidth',2,'AutoScaleFactor',1,'Color',[0 0 1])
        
        for iterE = 1:vis_count
            plot(top_centroid(iterE,1),top_centroid(iterE,2),'.','MarkerSize',12,'Color',plotc(iterE,:))
            u_bot = cos(bot_thetaPlot(iterE))*(flyLength/8); v_bot = -sin(bot_thetaPlot(iterE))*(flyLength/8);
            quiver(bot_centroid(iterE,1),bot_centroid(iterE,2)+botXadjust,u_bot,v_bot,...
                'ShowArrowHead','off','LineWidth',2,'AutoScaleFactor',1,'Color',plotc(iterE,:))
        end
        
        %%%% Generate line graphical readouts
%         zeroFly_XYZmm_Tdeg_fac1000
        
        plot_cell = {dist_vec_mm,speed_vec_frm,accel_vec_frm};
        %     plot_cell = {[(dist_vec_mm-min(dist_vec_mm))/range(dist_vec_mm),...
        %         (speed_vec_frm-min(speed_vec_frm))/range(speed_vec_frm),...
        %         (accel_vec_frm-min(accel_vec_frm))/range(accel_vec_frm)],...
        %         [wings_trk;belly_trk],[(range_trk-min(range_trk))/range(range_trk),change_trk]};
        titles_cell = {'Distance (mm)'
            'Speed (mm/sec)'
            'Acceleration (mm/sec/sec)'};
        %     titles_cell = {'Distance (mm), Speed (mm/sec), Acceleration (mm/sec/sec)',...
        %         'wings and belly','range and change'};
        y_label_cell = {'mm','mm/sec','mm/sec^2'};
        plot_refs = {(2:3),(5:6),(8:9)};
        %     y_lim_cell = {[0 500];[-5 20]};
        lineX = [vis_refs;vis_refs];
        for iterD = 1:3
            subplot(3,3,plot_refs{iterD});
            plot_var = plot_cell{iterD};
            plot_var(isnan(plot_var)) = [];
            sub_ylim = [min(plot_var(:)) max(plot_var(:))].*1.2;
            if max(sub_ylim) == 0
                sub_ylim = get(gca,'ylim');
            end
            %         if iterD == 1,sub_ylim = [-50 50]; end
            set(gca,'Color',back_colr,'XLim',[1 nFrames],...
                'XTick',[],'XColor',txt_colr,'YColor',txt_colr,...
                'TickDir','out','NextPlot','add','YGrid','on','YLim',sub_ylim)
            lineY = repmat([sub_ylim(1);sub_ylim(2)],1,vis_count);
            for iterF = 1:vis_count
                plot(lineX(:,iterF),lineY(:,iterF),'Color',...
                    plotc(iterF,:).*0.75,'LineWidth',1)
            end
            plot(plot_var,'LineWidth',6,'Color',[0 0 0])
            plot(plot_var,'LineWidth',2,'Color',graphc)
            plot([auto_fot;auto_fot],sub_ylim','LineStyle',':','LineWidth',1,'Color',txt_colr);
            title(titles_cell{iterD},'FontWeight','bold','Color',txt_colr,...
                'FontSize',font_size)
            ylabel(y_label_cell{iterD},'Color',txt_colr,'FontSize',font_size)
        end
        if ~isempty(manFot)
            plot([manFot manFot],sub_ylim,'LineStyle',':','LineWidth',2,'Color','g');
        end
        set(gca,'XTick',(0:400:2400))
        xlabel('frame','Color',txt_colr,'FontSize',font_size)
        hold off
        if visualOps(2)
            writeDir = 'C:\Users\williamsonw\Documents\Card Lab\labmeetingPrep_20140907';
            pdfName = ['trackingVisualizations_' videoID '.pdf'];
            writePath = fullfile(writeDir,pdfName);
            export_fig(writePath)
        end
        %     frame = getframe(gcf);
        uiwait(gcf)
    end
end
%%
% goodNdcs = cellfun(@(x) ~isempty(x),graphTable.relMotionFac1000_FB_LR_T);
% plotYa = cellfun(@(x) nanmax(double(x(:,3))),graphTable.relMotionFac1000_FB_LR_T(goodNdcs));
% plotYb = cellfun(@(x) nanmin(double(x(:,3))),graphTable.relMotionFac1000_FB_LR_T(goodNdcs));
% plot(rand(numel(plotYa)*2,1),[plotYa(:);plotYb(:)],'.')
% hold all
% plotYa = cellfun(@(x) nanmax(nanmax(double(x(:,1:2)))),graphTable.relMotionFac1000_FB_LR_T(goodNdcs));
% plotYb = cellfun(@(x) nanmin(nanmin(double(x(:,1:2)))),graphTable.relMotionFac1000_FB_LR_T(goodNdcs));
% plot(rand(numel(plotYa)*2,1),[plotYa(:);plotYb(:)],'.')

if saveTable
    graphTablePath = fullfile(expt_results_dir,[exptID '_dataForVisualization.mat']);
    save(graphTablePath,'graphTable')
end
