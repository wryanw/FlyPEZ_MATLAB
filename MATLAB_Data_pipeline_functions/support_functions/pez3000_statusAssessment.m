function pez3000_statusAssessment(exptIDlist)
%pez3000_statusAssessment Updates raw data assessment after tracking
%   This function queries the locator, tracking, and analyzed data folders
%   and updates the status column of the raw data assessment table.  It
%   also updates the experimentSummary variable, making it anew if unfound.
%   If no input list of cellstrings containing experiment IDs is given, all
%   experiment IDs found in the analysis directory are assessed.

%% %%% computer and directory variables and information
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
if ~exist('exptIDlist','var')
    exptIDlist = dir(analysisDir);
    exptIDexist = cell2mat({exptIDlist(:).isdir});
    exptIDlengthTest = cellfun(@(x) numel(x) == 16,{exptIDlist(:).name});
    exptIDlist = {exptIDlist(min(exptIDexist,exptIDlengthTest)).name};
    exptIDlist = flipud(exptIDlist(:));
end
exptCt = numel(exptIDlist);
%%

experimentSummaryCell = cell(exptCt,1);
exptSumName = 'experimentSummary.mat';
exptSumPath = fullfile(analysisDir,exptSumName);
parfor iterE = 1:exptCt
    exptID = exptIDlist{iterE};
    try
        experimentSummaryLoc = getExptInfo(exptID,analysisDir);
        experimentSummaryCell{iterE} = experimentSummaryLoc;
    catch ME
        disp(exptID)
        getReport(ME)
    end
end

if exist(exptSumPath,'file')
    for iterLoad = 1:5
        try
            experimentSummary_import = load(exptSumPath);
            experimentSummary_import = experimentSummary_import.experimentSummary;
            break
        catch
            if iterLoad == 5
                error('loading failure')
            end
            pause(1)
        end
    end
end

experimentSummary = cat(1,experimentSummaryCell{:});
justRunNames = experimentSummary.Properties.RowNames;
importNames = experimentSummary_import.Properties.RowNames;
newAddTest = cellfun(@(x) ~max(strcmp(importNames,x)),justRunNames);
if sum(~newAddTest) > 0
    prevSavedNames = justRunNames(~newAddTest);
    experimentSummary.Status(prevSavedNames) = experimentSummary_import.Status(prevSavedNames);
end
if sum(newAddTest) > 0
    newAddNames = exptIDlist(newAddTest);
    experimentSummary.Status(newAddNames) = repmat({'Active'},numel(newAddNames),1);
end
existTest = cellfun(@(x) max(strcmp(exptIDlist,x)),importNames);
experimentSummary_import = experimentSummary_import(~existTest,:);
experimentSummary = [experimentSummary_import;experimentSummary]; %#ok<NASGU>
save(exptSumPath,'experimentSummary')

end

function experimentSummaryLoc = getExptInfo(exptID,analysisDir)
expt_results_dir = fullfile(analysisDir,exptID);
exptSumVarNames = {'Total_Videos','Total_Curated','Total_Passing',...
    'Failed2locate','Failed2track','Failed2analyze',...
    'Analysis_Complete','Total_Jumping','Total_Manual_Annotations','Run_Count',...
    'stimDuration','First_Date_Run','Median_Date_Run','Last_Date_Run',...
    'Experiment_Type','UserID','Status','Synonyms'};

experimentSummaryLoc = table(0,0,0,0,0,0,0,0,0,0,0,{''},{''},{''},{''},{''},{''},{'None'},'RowNames',{exptID},...
    'VariableNames',exptSumVarNames);
assessmentName = [exptID '_rawDataAssessment.mat'];
assessmentPath = fullfile(expt_results_dir,assessmentName);

assessTable_import = load(assessmentPath);
dataname = fieldnames(assessTable_import);
assessTable = assessTable_import.(dataname{1});
assessNames = assessTable.Properties.RowNames;

graphTablePath = fullfile(expt_results_dir,[exptID '_dataForVisualization.mat']);
if exist(graphTablePath,'file') ~= 2
    experimentSummaryLoc.Total_Videos(exptID) = numel(assessNames);
    return
end
graphTableLoading = load(graphTablePath);
graphTable = graphTableLoading.graphTable;
graphNames = graphTable.Properties.RowNames;

masterList = intersect(assessNames,graphNames);
experimentSummaryLoc.Total_Jumping(exptID) = sum(graphTable.autoJumpTest(masterList));
experimentSummaryLoc.stimDuration(exptID) = nanmedian(graphTable.stimDuration(masterList));
if max(strcmp(graphTable.Properties.VariableNames,'manual_wingup_wingdwn_legpush'))
    manTest = graphTable.manual_wingup_wingdwn_legpush(masterList);
    manTest = cellfun(@(x) ~isempty(x) && max(~isnan(x)),manTest);
    experimentSummaryLoc.Total_Manual_Annotations(exptID) = sum(manTest);
else
    return
end
vidCt = numel(masterList);
outcomeOps = {'Raw data fail'
    'no locator file'
    'locator could not find fly'
    'no tracking file'
    'tracking too short'
    'no movement detected'
    'No analyzer file'
    'analyzed'};
choiceOps = [1 2 3 3 4 4 2 6];
statusStrings = {[],'Tracking scheduled','Failed to locate',...
    'Failed to track','Failed to analyze','Analysis complete'};
for iterO = 1:numel(outcomeOps)
    testS = strcmp(graphTable.finalStatus(masterList),outcomeOps{iterO});
    statusList = repmat(statusStrings(choiceOps(iterO)),sum(testS),1);
    assessTable.Analysis_Status(masterList(testS)) = statusList;
end
save(assessmentPath,'assessTable')

%%%%% Update experiment summary variable
experimentSummaryLoc.Total_Videos(exptID) = vidCt;
totNdcs = strcmp(assessTable.Curation_Status,'Saved');
experimentSummaryLoc.Total_Curated(exptID) = sum(totNdcs);
totNdcs = strcmp(assessTable.Raw_Data_Decision,'Pass');
experimentSummaryLoc.Total_Passing(exptID) = sum(totNdcs);
totNdcs = strcmp(assessTable.Analysis_Status,'Analysis complete');
experimentSummaryLoc.Analysis_Complete(exptID) = sum(totNdcs);

totNdcs = strcmp(assessTable.Analysis_Status,'Failed to locate');
experimentSummaryLoc.Failed2locate(exptID) = sum(totNdcs);
totNdcs = strcmp(assessTable.Analysis_Status,'Failed to track');
experimentSummaryLoc.Failed2track(exptID) = sum(totNdcs);
totNdcs = strcmp(assessTable.Analysis_Status,'Failed to analyze');
experimentSummaryLoc.Failed2analyze(exptID) = sum(totNdcs);

exptInfoMergedName = [exptID '_experimentInfoMerged.mat'];
exptInfoMergedPath = fullfile(expt_results_dir,exptInfoMergedName);
experimentInfoLoading = load(exptInfoMergedPath,'experimentInfoMerged');
experimentInfoMerged = experimentInfoLoading.experimentInfoMerged;
experimentSummaryLoc.Run_Count(exptID) = size(experimentInfoMerged,1);
runList = get(experimentInfoMerged,'ObsNames');
dateList = unique(cellfun(@(x) x(end-7:end),runList,'uniformoutput',false));
dateNumList = cell2mat(cellfun(@(x) datenum((x),'yyyymmdd'),dateList,'uniformoutput',false));
minDate = datestr(min(dateNumList),'yyyymmdd');
maxDate = datestr(max(dateNumList),'yyyymmdd');
medianDate = datestr(round(median(dateNumList)),'yyyymmdd');
experimentSummaryLoc.First_Date_Run{exptID} = minDate;
experimentSummaryLoc.Last_Date_Run{exptID} = maxDate;
experimentSummaryLoc.Median_Date_Run{exptID} = medianDate;

exptInfo = experimentInfoMerged(1,:);
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
experimentSummaryLoc.Experiment_Type{exptID} = exptType;
experimentSummaryLoc.UserID(exptID) = exptInfo.User_ID;

end
