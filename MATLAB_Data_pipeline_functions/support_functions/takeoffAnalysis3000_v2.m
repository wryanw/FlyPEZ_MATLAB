function takeoffAnalysis3000_v2(runMode,exptIDlist)
%%
%%%%% runModes
% 0 - run all passing
% 1 - run passing with tracking requested status
% 2 - run passing with empty assessment fields (gap fixing/error checking)
if ~exist('runMode','var')
    runMode = 1;
end
v = ver;
for k = 1:length(v)
    if strcmp(v(k).Name,'MATLAB')
        if str2double(v(k).Version) < 9.1
            matver = 'old';
        else
            matver = 'new';
        end
    end
end

%%%%% computer and directory variables and information
op_sys = system_dependent('getos');
if strfind(op_sys,'Microsoft Windows 7')
%    archDir = [filesep filesep 'tier2' filesep 'card'];
    archDir = [filesep filesep 'dm11' filesep 'cardlab'];
    dm11Dir = [filesep filesep 'dm11' filesep 'cardlab'];
else
%    archDir = [filesep 'Volumes' filesep 'card'];
    archDir = [filesep 'Volumes' filesep 'cardlab'];
    if ~exist(archDir,'file')
        archDir = [filesep 'Volumes' filesep 'card-1'];
    end
    dm11Dir = [filesep 'Volumes' filesep 'cardlab'];
end
if ~exist(archDir,'file')
    error('Archive access failure')
end
if ~exist(dm11Dir,'file')
    error('dm11 access failure')
end
analysisDir = fullfile(archDir,'Data_pez3000_analyzed');
SVMModel = load(fullfile(dm11Dir,'pez3000_variables\analysisVariables\jumpTestSVM_v2.mat'));
SVMModel = SVMModel.SVMModel;
if ~exist('exptIDlist','var')
    exptIDlist = dir(analysisDir);
    exptIDexist = cell2mat({exptIDlist(:).isdir});
    exptIDlengthTest = cellfun(@(x) numel(x) == 16,{exptIDlist(:).name});
    exptIDlist = {exptIDlist(min(exptIDexist,exptIDlengthTest)).name};
    exptIDlist = flipud(exptIDlist(:));
end
%exptIDlist = exptIDlist(cellfun(@(x) str2double(x(1:4)) >= 85,exptIDlist));

exptCt = numel(exptIDlist);
%%
assessmentTag = '_rawDataAssessment.mat';
if ~isempty(mfilename)
    set(0,'ShowHiddenHandles','on')
    delete(get(0,'Children'))
    h_wait = waitbar(0,'1','Name','Processing video data...',...
        'CreateCancelBtn',...
        'setappdata(gcbf,''canceling'',1)');
    setappdata(h_wait,'canceling',0)
end
for iterE = 1:exptCt
    if exist('h_wait','var')
        % Check for Cancel button press
        if getappdata(h_wait,'canceling')
            break
        end
        % Report current estimate in the waitbar's message field
        progress = iterE/exptCt;
        waitbar(progress,h_wait,exptIDlist{iterE})
    end
    exptID = exptIDlist{iterE};
    assessmentName = [exptID assessmentTag];
    assessmentPath = fullfile(analysisDir,exptID,assessmentName);
    if exist(assessmentPath,'file') == 2
        assessTable_import = load(assessmentPath);
        assessTable_holding = assessTable_import.assessTable;
    else
        disp(['no assessment file for ' exptID])
        continue
    end
    autoAnnoName = [exptID '_automatedAnnotations.mat'];
    autoAnnoPath = fullfile(analysisDir,exptID,autoAnnoName);
    if exist(autoAnnoPath,'file') == 2
        autoAnnoTable_import = load(autoAnnoPath);
        automatedAnnotations = autoAnnoTable_import.automatedAnnotations;
    else
        continue
    end
    if ~isempty(assessTable_holding)
        if runMode == 1
            videoList = intersect(assessTable_holding.Properties.RowNames,automatedAnnotations.Properties.RowNames);
            autoTestA = strcmp(assessTable_holding.Analysis_Status(videoList),'Tracking requested');
            autoTestA_1 = strcmp(assessTable_holding.Analysis_Status(videoList),'Tracking scheduled');
            autoTestB = strcmp(assessTable_holding.Analysis_Status(videoList),'Analysis scheduled');
            autoTestC = strcmp(assessTable_holding.Analysis_Status(videoList),'Analysis complete');
            autoTestD = cellfun(@(x) isempty(x),automatedAnnotations.jumpTest(videoList));
            autoTest = autoTestA | autoTestA_1 |  autoTestB | (autoTestC & autoTestD);
%            autoTest = autoTestA |  autoTestB | (autoTestC & autoTestD);
            assessTable_holding(videoList(~autoTest),:) = [];
        end
        assessTable_holding(~strcmp(assessTable_holding.Raw_Data_Decision,'Pass'),:) = [];
%         disp(['pct passing: ' num2str(size(assessTable_holding,1)/size(assessTable_import.assessTable,1),3)])
    end
    videoList = assessTable_holding.Properties.RowNames;
    if isempty(videoList)
        continue
    end
    videoCt = numel(videoList);
    disp([exptID ' - ' num2str(videoCt)])
    autoFrameOfTakeoff = cell(videoCt,1);
    jumpTest = cell(videoCt,1);
    jumpScore = cell(videoCt,1);
    parfor iterG = 1:videoCt
        videoID = videoList{iterG};
        strPts = strsplit(videoID,'_');
        runID = [strPts{1} '_' strPts{2} '_' strPts{3}];
        dateID = strPts{3};
        vidPath = fullfile(archDir,'Data_pez3000',dateID,runID,[videoID '.mp4']);
        if isempty(vidPath)
            disp('vidPath empty')
            continue
        end
        try
            vo = VideoReader(vidPath);
        catch
            disp(['video reader error - ' videoID])
            continue
        end
        frmCt = round(vo.Duration*vo.FrameRate);
        roiSumTop = zeros(1,frmCt);
        deltaFrms = zeros(1,frmCt);
        for iterFrm = 1:frmCt
            if strcmp(matver,'new')
                frame = readFrame(vo);
            else
                frame = read(vo,iterFrm);
            end
            frame = frame(:,:,1);
            tI = log(double(frame)+10);
            frame = uint8(255*(tI/log(265)-log(10)/log(265)));
            
            imTopFrm = frame(1:vo.Width,:);
            roiSumTop(iterFrm) = sum(imTopFrm(:));
            
            if iterFrm > 1
                deltaFrms(iterFrm) = sum(imTopFrm(:)-frmB(:));
            end
            frmB = imTopFrm;
        end
        delete(vo)
        
        Xa = min(smooth(roiSumTop,5));
        Xb = min(diff(smooth(roiSumTop,3)));
        Xc = max(deltaFrms);
        X = [Xa Xb Xc];
        [nbY,score] = predict(SVMModel,X);
        label = strcmp(nbY,'jumper');
        
        fotVec = smooth(deltaFrms,5);
        fotVec = diff(fotVec);
        fotVec = (fotVec-min(fotVec))/range(fotVec);
        [~,autoFot] = max(fotVec);
        autoFot = (autoFot+1)*10;
        
        autoFrameOfTakeoff{iterG} = autoFot;
        jumpTest{iterG} = label;
        jumpScore{iterG} = score;
    end
    automatedAnnotations.autoFrameOfTakeoff(videoList) = autoFrameOfTakeoff;
    automatedAnnotations.jumpTest(videoList) = jumpTest;
    automatedAnnotations.jumpScore(videoList) = jumpScore;
    save(autoAnnoPath,'automatedAnnotations')
    assessTable_import = load(assessmentPath);
    assessTable = assessTable_import.assessTable;
    if runMode == 1
        assessTable.Analysis_Status(videoList) = repmat({'Tracking scheduled'},videoCt,1);
    end
    save(assessmentPath,'assessTable')
end
if exist('h_wait','var')
    delete(h_wait)
end
pez3000_statusAssessment(exptIDlist)
