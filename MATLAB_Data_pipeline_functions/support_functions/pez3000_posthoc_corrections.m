function pez3000_posthoc_corrections

%%%%% computer and directory variables and information
op_sys = system_dependent('getos');
if strfind(op_sys,'Microsoft Windows 7')
    %    archDir = [filesep filesep 'arch' filesep 'card'];
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
ignorePath = fullfile(analysisDir,'ignoreLists','runs2ignoreList.txt');
ignoreCell = readtable(ignorePath,'Delimiter','\t','ReadVariableNames',false);
runs2ignoreCell = table2cell(ignoreCell);
excelPath = fullfile(analysisDir,'significant_event_log_pez3000.xlsx');
correctionsTable = readtable(excelPath);
correctionsTable = correctionsTable(strcmp(correctionsTable.Consequence,'Fail'),:);
%%
for iterC = 1:size(correctionsTable,1)
    if isempty(correctionsTable.DateEnd{iterC})
        dateList = correctionsTable.DateBegin(iterC);
    else
        dateList = datestr(datenum(correctionsTable.DateBegin{1},'yyyymmdd'):datenum(correctionsTable.DateEnd{1},'yyyymmdd'),'yyyymmdd');
        dateList = cellstr(dateList);
    end
    for iterD = 1:numel(dateList)
        dateRef = dateList{iterD};
        dateDir = fullfile(archDir,'Data_pez3000',dateRef);
        runList = dir(fullfile(dateDir,'run*'));
        runList = {runList(:).name}';
        if ~isempty(correctionsTable.AffectedRuns{iterC})
            runNums = str2double(regexprep(correctionsTable.AffectedRuns{iterC},'-',':'));
            runNums = num2cell(runNums(:));
            runNums = cellfun(@(x) ['run' sprintf('%03d',x)],runNums,'uniformoutput',false);
            runBool = cellfun(@(x) strfind(runList,x),runNums,'uniformoutput',false);
            runBool = cat(2,runBool{:});
            runBool = max(cellfun(@(x) ~isempty(x),runBool),[],2);
            runList = runList(runBool);
        end
        if ~strcmp(correctionsTable.AffectedPezzes{iterC},'all_pezzes')
            pezBool = cellfun(@(x) ~isempty(strfind(x,correctionsTable.AffectedPezzes{iterC})),runList);
            runList = runList(pezBool);
        end
        for iterR = 1:numel(runList)
            runID = runList{iterR};
            if ~exist(fullfile(dateDir,runID,[runID '_runStatistics.mat']),'file')
%                 disp('missing run stats')
                continue
            end
            load(fullfile(dateDir,runID,[runID '_runStatistics.mat']))
            if ~isfield(runStats,'experimentID')
                disp('bad run stats')
                continue
            end
            if ~max(strcmp(runs2ignoreCell,runID))
                fidRun = fopen(ignorePath,'a');
                fprintf(fidRun,'\r\n%s\t%s',runID,'post hoc removal');
                fclose(fidRun);
            end
            exptID = runStats.experimentID;
            vidList = dir(fullfile(dateDir,runID,['*' exptID '_vid*']));
            vidList = {vidList(:).name}';
            if isempty(vidList)
%                 disp('empty run folder')
                continue
            end
            [~,vidList] = cellfun(@(x) fileparts(x),vidList,'uniformoutput',false);
            exptResultsRefDir = fullfile(analysisDir,exptID);
            assessmentName = [exptID '_rawDataAssessment.mat'];
            assessmentPath = fullfile(exptResultsRefDir,assessmentName);
            if exist(assessmentPath,'file') == 2
                assessTable_import = load(assessmentPath);
                dataname = fieldnames(assessTable_import);
                assessTable = assessTable_import.(dataname{1});
            else
                disp(assessmentPath)
                disp('assess table not found')
                continue
            end
            assessNames = assessTable.Properties.RowNames;
            %%%%%%%% to reset videos - these will now need curation %%%%%%%
%             assessTable.Curation_Status(assessNames) = repmat({''},numel(assessNames),1);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            badData = assessNames(cellfun(@(x) max(strcmp(vidList,x)),assessNames));
            if isempty(badData)
                continue
            end
            
%             assessTable.Raw_Data_Decision(assessNames) = repmat({'Pass'},numel(assessNames),1);
%             assessTable.Curation_Status(assessNames) = repmat({'Saved'},numel(assessNames),1);
%             assessTable.Flag_B(assessNames) = repmat({''},numel(assessNames),1);
            if sum(strcmp(assessTable.Raw_Data_Decision(badData),'Fail')) == numel(badData)
                continue
            end
            assessTable.Raw_Data_Decision(badData) = repmat({'Fail'},numel(badData),1);
            assessTable.Curation_Status(badData) = repmat({'Saved'},numel(badData),1);
            assessTable.Flag_B(badData) = repmat(correctionsTable.EventTag(iterC),numel(badData),1);
%             failTestA = ~strcmp(assessTable.Data_Acquisition(assessNames),'good');
%             failTestB = ~strcmp(assessTable.Fly_Count(assessNames),'Single');
%             failTestC = ~strcmp(assessTable.Balancer(assessNames),'None');
%             failTestD = strcmp(assessTable.Physical_Condition(assessNames),'BadSweep');
%             failTestE = ~strcmp(assessTable.NIDAQ(assessNames),'Good');
%             failMaster = failTestA | failTestB | failTestC | failTestD | failTestE;
%             assessTable.Raw_Data_Decision(failMaster) = repmat({'Fail'},sum(failMaster),1);
%             assessTable.Curation_Status(failMaster) = repmat({'Saved'},sum(failMaster),1);
            
            save(assessmentPath,'assessTable')
            pez3000_statusAssessment({exptID})
        end
    end
end