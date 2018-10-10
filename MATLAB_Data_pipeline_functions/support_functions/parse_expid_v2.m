function expt_id_info = parse_expid_v2(experiment_id)

persistent Collection Genotypes Protocols
%%
expt_id_info = 'error';
if nargin == 0 || isempty(mfilename)
    Collection = [];
    Genotypes = [];
    Protocols = [];
    experiment_id = '0058000021990437';
%     experiment_id = '0052000004300377';
end
if numel(experiment_id) ~= 16
    return
end

op_sys = system_dependent('getos');
if ~isempty(strfind(op_sys,'Microsoft Windows 7'))
    file_dir = '\\DM11\cardlab\Pez3000_Gui_folder\Gui_saved_variables';
else
    file_dir = '/Volumes/cardlab/Pez3000_Gui_folder/Gui_saved_variables';
end

if isempty(Collection)
    Collection = load([file_dir filesep 'Saved_Collection.mat']);
end
if isempty(Genotypes)
    Genotypes = load([file_dir filesep 'Saved_Genotypes.mat']);
end
if isempty(Protocols)
    Protocols = load([file_dir filesep 'Saved_Protocols_new_version.mat']);
end

collectionNames = get(Collection.Saved_Collection,'ObsName');
collectionRef = strcmp(collectionNames,experiment_id(1:4));
genotypeNames = get(Genotypes.Saved_Genotypes ,'ObsName');
genotypeRef = strcmp(genotypeNames,experiment_id(5:12));
protocolNames = get(Protocols.Saved_Protocols_new_version ,'ObsName');
protocolRef = strcmp(protocolNames,experiment_id(13:16));
testA = max(collectionRef) == 0;
testB = max(genotypeRef) == 0;
testC = max(protocolRef) == 0;
if testA || testB || testC
    return
end

parsed_collection = Collection.Saved_Collection(collectionRef,:);
parsed_genotype   = Genotypes.Saved_Genotypes(genotypeRef,:);
parsed_protocol   = Protocols.Saved_Protocols_new_version(protocolRef,:);

parsed_collection = set(parsed_collection,'ObsName',experiment_id);
parsed_genotype = set(parsed_genotype,'ObsName',experiment_id);
parsed_protocol = set(parsed_protocol,'ObsName',experiment_id);

expt_id_info = [parsed_collection parsed_genotype parsed_protocol];
expt_id_info.Videos_In_Collection = [];
expt_id_info.Archived_Videos = [];
expt_id_info.Record_Rate = expt_id_info.Record_Rate{1};
if ~iscell(expt_id_info.Record_Rate)
    expt_id_info.Record_Rate = {expt_id_info.Record_Rate};
end
    
%if ~ischar(expt_id_info.Collection_Description{1})
%    expt_id_info.Collection_Description = expt_id_info.Collection_Description{1};
%end
end
