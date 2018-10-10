function makeExcelTable(runMode)
%makeExcelTable generates excel table that contains all exptID info
%   To make complete table in default location, set runMode to 1.  To
%   generate your own table, use makeGraphOptionsStruct to set the file and
%   sheet names and set runMode to 2.  
%%
if ~exist('runMode','var')
    runMode = 1;
end
%analysisDir = fullfile('\\tier2','card','Data_pez3000_analyzed');
analysisDir = fullfile('\\DM11','cardlab','Data_pez3000_analyzed');
exptSumName = 'experimentSummary.mat';
exptSumPath = fullfile(analysisDir,exptSumName);
experimentSummary = load(exptSumPath);
experimentSummary = experimentSummary.experimentSummary;
if runMode == 1
    exptIDlist = experimentSummary.Properties.RowNames;
    sheetName = 'allIDs';
    excelPath = fullfile(analysisDir,'experimentIDinfo.xlsx');
else
%    optionsPath = 'Y:\Data_pez3000_analyzed\WRW_graphing_variables\graphOptions.mat';
    optionsPath = 'Z:\Data_pez3000_analyzed\WRW_graphing_variables\graphOptions.mat';
    graphOptions = load(optionsPath);
    graphOptions = graphOptions.graphOptions;
    excelPath = graphOptions.excelPath;
    sheetName = graphOptions.exptSheet;
    try
        excelTable = readtable(excelPath,'ReadRowNames',true,'Sheet',sheetName);
    catch
        excelTable = readtable(excelPath,'ReadRowNames',false,'Sheet',sheetName);
        excelTable.Properties.RowNames = excelTable.Row;
    end
    exptIDlist = excelTable.Properties.RowNames;
    excelTable(cellfun(@(x) numel(x),exptIDlist) ~= 19,:) = [];
    exptIDlist = excelTable.Properties.RowNames;
    exptIDlist = cellfun(@(x) x(4:end),exptIDlist,'uniformoutput',false);
    exptIDlist = unique(exptIDlist);
end

exptIDlist = intersect(experimentSummary.Properties.RowNames,exptIDlist);
exptIDtable = experimentSummary(exptIDlist,:);

exptInfoCopyVars = {'Observations'
    'Collection_Name'
    'Collection_Description'
    'User_ID'
    'ParentA_name'
    'ParentA_ID'
    'ParentA_genotype'
    'ParentB_name'
    'ParentB_ID'
    'ParentB_genotype'
    'Males'
    'Females'
    'No_Balancers'
    'Chromosome1'
    'Chromosome2'
    'Chromosome3'
    'Food_Type'
    'Foiled'
    'Compression_Opts'
    'Download_Opts'
    'Record_Rate'
    'Trigger_Type'
    'Time_Before'
    'Time_After'
    'Notes'
    'Room_Temp'
    'Manager'};
exptCt = numel(exptIDlist);

frame_count = repmat({'0'},exptCt,1);
visStimType = repmat({'None'},exptCt,1);
elevation = repmat({'0'},exptCt,1);
azimuth = repmat({'0'},exptCt,1);
startSize = repmat({'0'},exptCt,1);
stopSize = repmat({'0'},exptCt,1);
lv = repmat({'0'},exptCt,1);
contrast = repmat({'None'},exptCt,1);
width = repmat({'0'},exptCt,1);
frequency = repmat({'0'},exptCt,1);
activation1 = repmat({'None'},exptCt,1);
activation2 = repmat({'None'},exptCt,1);
activation3 = repmat({'None'},exptCt,1);
stimTable = table(frame_count,visStimType,elevation,azimuth,startSize,stopSize,lv,contrast,...
    width,frequency,activation1,activation2,activation3,'RowNames',exptIDlist);
incubatorVars = {'Name','Location','LightsOn','LightsOff','Temperature','Humidity'};

addlVars = cat(1,exptInfoCopyVars(:),incubatorVars(:));
table2append = cell2table(cell(exptCt,numel(addlVars)),'RowNames',exptIDlist,...
    'VariableNames',addlVars);
exptIDtable = cat(2,exptIDtable,stimTable,table2append);
for iterA = 1:exptCt
    exptID = exptIDlist{iterA};
    stimTypeString = experimentSummary.Experiment_Type{exptID};
    expt_results_dir = fullfile(analysisDir,exptID);
    exptInfoMergedName = [exptID '_experimentInfoMerged.mat'];
    exptInfoMergedPath = fullfile(expt_results_dir,exptInfoMergedName);
    if ~exist(exptInfoMergedPath,'file')
        disp([exptID ' - missing expt info'])
        continue
    end
    experimentInfoMerged = load(exptInfoMergedPath);
    exptInfo = experimentInfoMerged.experimentInfoMerged(1,:);
    
    vidStatsName = [exptID '_videoStatisticsMerged.mat'];
    vidStatsPath = fullfile(expt_results_dir,vidStatsName);
    if ~exist(vidStatsPath,'file')
        disp([exptID ' - missing vid stats'])
        continue
    end
    vidStatsLoading = load(vidStatsPath);
    if isempty(fields(vidStatsLoading))
        disp([exptID ' - empty vid stats'])
        continue
    end
    vidStats = vidStatsLoading.videoStatisticsMerged;
    exptIDtable.frame_count(exptID) = {double(vidStats.frame_count(1))};
    
    if strcmp('Visual_stimulation',stimTypeString) || strcmp('Combo',stimTypeString)
        stimInfo = exptInfo.Stimuli_Type{1};
        splitCell = strsplit(stimInfo,'_');
        if strcmp(splitCell{1},'loom')
            exptIDtable.visStimType(exptID) = splitCell(1);
            exptIDtable.elevation(exptID) = {exptInfo.Stimuli_Vars.Elevation};
            exptIDtable.azimuth(exptID) = {exptInfo.Stimuli_Vars.Azimuth};
            exptIDtable.lv(exptID) = {splitCell{3}(strfind(splitCell{3},'lv')+2:end)};
            exptIDtable.startSize(exptID) = {splitCell{2}(1:strfind(splitCell{2},'to')-1)};
            exptIDtable.stopSize(exptID) = {splitCell{2}(strfind(splitCell{2},'to')+2:end)};
            exptIDtable.contrast(exptID) = splitCell(end);
        elseif strcmp(splitCell{1},'constSize')
            exptIDtable.visStimType(exptID) = splitCell(1);
            exptIDtable.elevation(exptID) = {exptInfo.Stimuli_Vars.Elevation};
            exptIDtable.azimuth(exptID) = {exptInfo.Stimuli_Vars.Azimuth};
            exptIDtable.startSize(exptID) = splitCell(2);
            exptIDtable.contrast(exptID) = splitCell(end);
        elseif ~isempty(strfind(splitCell{1},'grating'))
            exptIDtable.visStimType(exptID) = {'grating'};
            exptIDtable.elevation(exptID) = {exptInfo.Stimuli_Vars.Elevation};
            exptIDtable.azimuth(exptID) = {exptInfo.Stimuli_Vars.Azimuth};
            exptIDtable.width(exptID) = {splitCell{2}(1:strfind(splitCell{2},'deg')-1)};
            exptIDtable.frequency(exptID) = {regexprep(splitCell{3}(1:strfind(splitCell{3},'Hz')-1),'p','.')};
            exptIDtable.contrast(exptID) = splitCell(end);
        end
    end
    if strcmp('Photoactivation',stimTypeString) || strcmp('Combo',stimTypeString)
        if ~iscell(exptInfo.Photo_Activation{1})
            exptInfo.Photo_Activation = {exptInfo.Photo_Activation};
        end
        for iterS = 1:numel(exptInfo.Photo_Activation{1})
            exptIDtable.(['activation' num2str(iterS)])(exptID) = exptInfo.Photo_Activation{1}(iterS);
        end
    end
    Incubator_Info = exptInfo.Incubator_Info;
    for iterInc = 1:numel(incubatorVars)
        if ~max(strcmp(fieldnames(Incubator_Info),incubatorVars{iterInc}))
            addlInfo = 'no info';
        else
            addlInfo = Incubator_Info.(incubatorVars{iterInc});
            if ischar(addlInfo) && isempty(deblank(addlInfo))
                addlInfo = 'None';
            end
        end
        exptIDtable.(incubatorVars{iterInc})(exptID) = {['''' addlInfo]};
    end
    for iterAddl = 1:numel(exptInfoCopyVars)
        if ~max(strcmp(get(exptInfo,'VarNames'),exptInfoCopyVars{iterAddl}))
            addlInfo = 'no info';
        else
            addlInfo = exptInfo.(exptInfoCopyVars{iterAddl});
            while iscell(addlInfo)
                addlInfo = addlInfo{1};
            end
            if ischar(addlInfo) && isempty(deblank(addlInfo))
                addlInfo = 'None';
            end
        end
        exptIDtable.(exptInfoCopyVars{iterAddl})(exptID) = {addlInfo};
    end
end

rowNames = exptIDtable.Properties.RowNames;
rowNames = cellfun(@(x) ['ID#' x(end-15:end)],rowNames,'uniformoutput',false);
exptIDtable.Properties.RowNames = rowNames;
rangeRef = ['A1:BK' num2str(size(exptIDtable,1)+1)];
try
    writetable(exptIDtable,excelPath,'Sheet',[sheetName '_updated'],'WriteRowNames',true,...
        'Range',rangeRef)
catch ME
    getReport(ME)
    disp('please close destination table and try again')
end

