function pezProcessor3000_v8auto(totalComps,thisComp,runMode)
if isempty(mfilename) || nargin == 0
    totalComps = 1;
    thisComp = 1;
    runMode = 1;
end
%%%%% ENTER FUNCTION NAMES:
locator_name = 'flyLocator3000_v10';
tracker_name = 'flyTracker3000_v17';
analyzer_name = 'flyAnalyzer3000_v13';
visualizer_name = 'trackingVisualizer3000_v13';

%%%%% RUN MODE:
% '1' - functions run only when they have been scheduled according to the
% raw data assessment file, regardless of whether previous results exist
% '2' - functions run on all 'passing' raw data regardless of whether
% previous results exist
% '3' - functions run for 'passing' raw data which does not have existing
% tracking, locator, or analyzed data - NEEDS TO QUERY GRAPH TABLE; NOT IN
% USE AT THE MOMENT
% '4' - functions run only for 'passing' and tracked raw data which 
% is missing at least one of the tracking, locating, or analyzing files


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
set(0,'showhiddenhandles','on')
delete(get(0,'children'))
housekeepingDir = fullfile(dm11Dir,'Pez3000_Gui_folder','defaults_and_housekeeping_variables');
analysisDir = fullfile(archDir,'Data_pez3000_analyzed');
[~,localUserName] = dos('echo %USERNAME%');
localUserName = localUserName(1:end-1);
repositoryName = 'pezAnalysisRepository';
repositoryDir = fullfile('C:','Users',localUserName,'Documents',repositoryName);
subfun_dir = fullfile(repositoryDir,'pezProc_subfunctions');
saved_var_dir = fullfile(repositoryDir,'pezProc_saved_variables');
assessment_dir = fullfile(repositoryDir,'file_assessment_and_manipulation');
addpath(repositoryDir,subfun_dir,saved_var_dir,assessment_dir)
addpath(fullfile(repositoryDir,'Pez3000_Gui_folder','Matlab_functions','Support_Programs'))

failure_path = fullfile(analysisDir,'errorLogs','pezProcessor300_v8auto_errorLog.txt');

[~,localUserName] = dos('echo %USERNAME%');
localUserName = localUserName(1:end-1);
repositoryName = 'pezAnalysisRepository';
repositoryDir = fullfile('C:','Users',localUserName,'Documents',repositoryName);
subfun_dir = fullfile(repositoryDir,'pezProc_subfunctions');
saved_var_dir = fullfile(repositoryDir,'pezProc_saved_variables');
addpath(subfun_dir,saved_var_dir)
addpath(fullfile(repositoryDir,'Pez3000_Gui_folder','Matlab_functions','Support_Programs'))

listSavePath = 'Z:\pez3000_variables\analysisVariables\videoList.mat';
delete(listSavePath)%%%%%% comment out to keep saved list
%%
if exist(listSavePath,'file')
    load(listSavePath)
else
    %
    %%% Normal way to load exptIDs
    exptIDlist = dir(analysisDir);
    exptIDexist = cell2mat({exptIDlist(:).isdir});
    exptIDlengthTest = cellfun(@(x) numel(x) == 16,{exptIDlist(:).name});
    exptIDlist = {exptIDlist(min(exptIDexist,exptIDlengthTest)).name};
    
%    exptIDlist = exptIDlist(cellfun(@(x) str2double(x(1:4)) >= 85,exptIDlist));
    
%    exptIDlist = {'0083000022700609'};
    
    exptCt = numel(exptIDlist);
    videoList = cell(exptCt,1);
    for iterE = 1:exptCt
        exptID = exptIDlist{iterE};
        assessmentPath = fullfile(analysisDir,exptID,[exptID '_rawDataAssessment.mat']);
        if exist(assessmentPath,'file') == 2
            try
                assessTable_import = load(assessmentPath);
                dataname = fieldnames(assessTable_import);
                assessTable = assessTable_import.(dataname{1});
            catch       %file where assestable is corrupt
                assessTable = [];
            end
            if ~isempty(assessTable)
                if runMode == 1 || runMode == 4
                    vids2removeA = strcmp(assessTable.Analysis_Status,'Tracking requested');
                    vids2removeB = strcmp(assessTable.Analysis_Status,'Tracking scheduled');
                    vids2removeC = strcmp(assessTable.Analysis_Status,'Analysis complete');
                    if runMode == 4
                        vids2removeFull = vids2removeA | vids2removeB | vids2removeC;
                    else
                        vids2removeFull = vids2removeA | vids2removeB;
                    end
                    assessTable(~vids2removeFull,:) = [];
                end
                assessTable(~strcmp(assessTable.Raw_Data_Decision,'Pass'),:) = [];
                vidList = assessTable.Properties.RowNames;
                if ~isempty(vidList)
                    videoList{iterE} = vidList;
                end
            end
        end
    end
    videoList = cat(1,videoList{:});
    ignorePath = fullfile(analysisDir,'ignoreLists','videos2ignoreList.txt');
    ignoreCell = readtable(ignorePath,'Delimiter','\t','ReadVariableNames',false);
    ignoreCell = table2cell(ignoreCell);
    ignoreCell = ignoreCell(:,1);
    videoList = videoList(cellfun(@(x) ~max(strcmp(x,ignoreCell)),videoList));
    save(listSavePath,'videoList')

    %%%%% makes video list from error record
%     errorList = importdata(failure_path);
%     videoList = cellfun(@(x) x(1:52),errorList,'uniformoutput',false);
%     videoList = unique(videoList);
end

%%
videoCt = numel(videoList);
vidRefBreaks = round(linspace(1,videoCt,totalComps+1));
[~,host] = system('hostname');
host = strtrim(regexprep(host,'-','_'));
parCtrlPath = fullfile(housekeepingDir,'parforControl.txt');
if exist(parCtrlPath,'file')
    parTable = readtable(parCtrlPath,'delimiter',',');
else
    parTable = [];
end
iterList = vidRefBreaks(thisComp):vidRefBreaks(thisComp+1);
iterCt = numel(iterList);
localParTable = table({host},{'run'},iterCt,...
    0,'VariableNames',{'computer','action','total_iterations','prev_iterations'});
if isempty(parTable)
    parTable = localParTable;
elseif ~max(strcmp(parTable.computer,host))
    parTable = cat(1,parTable,localParTable);
else
    localParTable.prev_iterations = parTable.total_iterations(strcmp(parTable.computer,host));
    parTable(strcmp(parTable.computer,host),:) = localParTable;
end

writetable(parTable,parCtrlPath)
parfor iterG = iterList
    try
        parTable = readtable(parCtrlPath,'delimiter',',');
        if strcmp(parTable.action{strcmp(parTable.computer,host)},'stop')
            continue
        end
    catch
    end
    locator_fun = str2func(locator_name);
    tracker_fun = str2func(tracker_name);
    analyzer_fun = str2func(analyzer_name);
    videoID = videoList{iterG};
    try
        tic
        locator_fun(videoID,runMode);
        tracker_fun(videoID,locator_name,runMode)
        analyzer_fun(videoID,locator_name,tracker_name,runMode)
        toc
    catch
%    catch ME
%         getReport(ME)
         fidErr = fopen(failure_path,'a');
         fprintf(fidErr,'%s \r\n',videoID);
         fclose(fidErr);
%        toc
        continue
    end
end
if ~isempty(videoList)
    exptIDlist = cellfun(@(x) x(29:44),videoList(iterList),'uniformoutput',false);
    exptIDlist = unique(exptIDlist);
    exptCt = numel(exptIDlist);
    errTally = cell(exptCt,3);
    for iterG = 1:exptCt
        exptID = exptIDlist{iterG};
        visualizer_fun = str2func(visualizer_name);
        try
            visualizer_fun(exptID);
        catch ME
            if numel(ME.stack) > 1
                errTally(iterG,:) = {ME.stack(end-1).name ME.stack(end-1).line exptID};
            end
        end
        
    end
    pez3000_statusAssessment(exptIDlist)
    errorList = errTally(cellfun(@(x) ~isempty(x),errTally(:,1)),3); %#ok<NASGU>
    save(fullfile(archDir,'Data_pez3000_analyzed','errorLogs','graphingVariableGenerationErrors.mat'),'errorList')
end
parTable = readtable(parCtrlPath,'delimiter',',');
parTable.action{strcmp(parTable.computer,host)} = 'stop';
writetable(parTable,parCtrlPath)