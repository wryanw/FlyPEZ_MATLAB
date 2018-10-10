
function projectorCalibration3000_v3
%% projectorCalibrate3000 Calibrates the projector in preparation for stimulus
%   The inputs are...
set(0,'showhiddenhandles','on')
delete(get(0,'Children'))
clearvars -except portNum hostIP
clc

% Get communications variables
variablesDir = [filesep filesep 'dm11' filesep 'cardlab' filesep 'pez3000_variables'];
[~, comp_name] = system('hostname');
comp_name = comp_name(1:end-1); %Remove trailing character.
compDataPath = fullfile(variablesDir,'computer_info.xlsx');
compData = dataset('XLSFile',compDataPath);
compRef = find(strcmpi(compData.control_computer_name,comp_name));%this computer
if isempty(compRef)
    compRef = 1;
    disp('computer not valid')
%     return
end
hostIP = compData.stimulus_computer_IP{compRef};
portNum = 21566;

calibrateOp = 5;
%1 - crosshairs
%2 - 10-cm lines
%3 - transition space for setting outer transition ring position
%4 - blended single dashed ring
%5 - save variables and show balanced white background
%6 - save variables only
if calibrateOp ~= 6
    % Initialize visual stimulus computer
    %command values: 0 - transforming initialization, 5 - standard (for calibration, etc)
    commandVal = 5;
    judp('send',portNum,hostIP,int8(commandVal))
    rcvdMssg = judp('receive',portNum,50,15000);
    char(rcvdMssg')
end

pezName = ['pez' num2str(compData.pez_reference(compRef))];
varName = [pezName '_stimuliVars.mat'];
varPath = fullfile(variablesDir,varName);
imReadPath = fullfile(variablesDir,[pezName '_im2show.tif']);
paramName = [pezName '_stimuliParams.mat'];
paramPath = fullfile(variablesDir,paramName);

height = 768;
width = 1024;
hW = round(width/2);
hH = round(height/2);

%% computer-specific information
switch pezName
    case 'pez3001' %stimulus computer no. 1
        % CALIBRATE OP 1
        % Measure the distance from the top of the mirror plane to the lens
        atMirPlane2projector = 33.25;%in inches
        % CALIBRATE OP 2
        % Using tailor's measuring tape, empirically determine the 
        % circimference of the dome
        sphereCircumference = 475;%in millimeters
        % Adjust the following until the scale of the top projection aligns
        % with the 10mm marks on the measuring tape. Bigger numbers reduce
        % the spacing between the lines.
        zoomTheta = 19.95;%in degrees
        % Adjust the following until the bottom projection dashed lines
        % align with the two top projection dashed lines.  Bigger numbers
        % make the bottom lines lower.  When the dashed lines align, the
        % solid ones should all line up with the 10-mm marks.  If not,
        % slightly adjust the zoom and try again.
        % CALIBRATE OP 3
        sphDropDiff = 0.225;
        % Adjust the following until the sides align.  Bigger numbers make
        % the mirror reflection go down on the sides relative to the top
        % reflection.
        whRatioAdjust = 0.990;
        % Position the transition from top-projection to mirror-projection
        % to the edge of the mirror
        topThreshFactor = 1.035;
        %reference flicker window
        stimRefROI = [95 435];%x1 y1 from top,left of screen
        
        % CALIBRATE OP 4
        % The following are for fine-tuning, needed to skew diagonally.
        % Positive numbers for 'TB' rocks the mirror-reflected ring towards
        % the camera.  Positive numbers for LR rock the mirror reflected
        % ring to the right from the perspective of the camera.
        hypSkewTB = -0.000;
        hypSkewLR = -0.006;
        
        %positive numbers twist top or right
        hypTwistA = 0.07;%right side twist
        hypTwistB = 0.0;%left side twist
        hypTwistC = 0.0;%bottom twist
        hypTwistD = 0.0;%top twist
        
    case 'pez3002' %stimulus computer no. 2
        atMirPlane2projector = 33.25;
        sphereCircumference = 481;
        zoomTheta = 19.89;
        sphDropDiff = 0.19; %0.165;
        topThreshFactor = 1.035;
        whRatioAdjust = 0.989;
        stimRefROI = [92 430];
        hypSkewTB = -0.008;
        hypSkewLR = 0.007;
        
        %positive numbers twist top or right
        hypTwistA = 0.11;%right side twost
        hypTwistB = -0.04;%left side twist
        hypTwistC = 0.0;%bottom twost
        hypTwistD = 0.0;%top twist
        
    case 'pez3003' %stimulus computer no. 3
        atMirPlane2projector = 34.4;
        sphereCircumference = 475;
        zoomTheta = 19.20;
        sphDropDiff = 0.16;
        topThreshFactor = 1.035;
        whRatioAdjust = 0.992;
        stimRefROI = [92 433];
        hypSkewTB = -0.001;
        hypSkewLR = 0.006;
        
        %positive numbers twist top or right
        hypTwistA = 0.0;%right side twost
        hypTwistB = 0.0;%left side twist
        hypTwistC = 0.0;%bottom twost
        hypTwistD = 0.0;%top twist

    case 'pez3004' %stimulus computer no. 4
        atMirPlane2projector = 35.25;
        sphereCircumference = 475;
        zoomTheta = 18.59;
        sphDropDiff = 0.155;
        topThreshFactor = 1.03;
        whRatioAdjust = 0.986;
        stimRefROI = [85 420];
        hypSkewTB = -0.005;
        hypSkewLR = 0.007;
        
        %positive numbers twist top or right
        hypTwistA = 0.05;%right side twost
        hypTwistB = 0.0;%left side twist
        hypTwistC = 0.0;%bottom twost
        hypTwistD = 0.0;%top twist
    otherwise
        disp('error')
        return
end
stimRefROI = [stimRefROI stimRefROI+35];
save(paramPath,'atMirPlane2projector','zoomTheta','sphDropDiff',...
    'sphereCircumference','hypSkewTB','hypSkewLR','whRatioAdjust','stimRefROI')

stimRef = ones(height,width);
stimRef(1:stimRefROI(2),:) = 0;
stimRef(stimRefROI(4):end,:) = 0;
stimRef(:,1:stimRefROI(1)) = 0;
stimRef(:,stimRefROI(3):end) = 0;

initIm = zeros(height-2,width-2);
initIm = padarray(initIm,[1 1],1);
initIm(hH:hH+1,:) = 1;
initIm(:,hW:hW+1) = 1;
crosshairsIm = repmat(uint8((initIm+stimRef).*255),[1 1 3]);
% initIm(initIm ~= 1 ) = 1;%white screen!!

if calibrateOp == 1
    imwrite(crosshairsIm,imReadPath)
    judp('send',portNum,hostIP,int8(54))
    return
end

wallFbot = .15;

%%%%% Conversion functions, anonymous
in2mm = @(x) x.*25.4;%inch to mm conversion
mm2in = @(x) x./25.4;
deg2rad = @(x) x*(pi/180);
rad2deg = @(x) x./(pi/180);

%%%%% Variables from specs (these values shouldn't change)
% adds distance from lens to theoretical point source %
atMirPlane2projector = atMirPlane2projector+((0.25)/tan(deg2rad(zoomTheta/2)))*2;
% accounts for distance of dome center below mirror plane %
distOfSphereBelow = 0.710+sphDropDiff;
atMid_proj2wall = in2mm(atMirPlane2projector+distOfSphereBelow);
% Radii %
mirTheta = deg2rad(42.7);%angle of the mirror
minTheta = deg2rad(-21);%minimum elevation to be projected onto the dome
mirRtop = in2mm(11.955/2-0.09);%radius from center axis to top of mirror
% radius from center axis at sphere center to mirror %
mirRcntr = mirRtop-in2mm(tan(mirTheta)*(distOfSphereBelow-0.083));
sphR = (sphereCircumference/pi)/2;%radius of sphere in mm

%%%%% Variables derived from measurements
onWall_bot2top = tan(deg2rad(zoomTheta/2))*atMid_proj2wall*2;
onWall_floor2bot = wallFbot*onWall_bot2top;
onWall_floor2top = (onWall_bot2top+onWall_floor2bot);
onWall_floor2mid = (onWall_floor2bot+0.5*(onWall_floor2top-onWall_floor2bot))*1;%%%%%had been reducing this
onFloor_proj2wall = sqrt(atMid_proj2wall^2-onWall_floor2mid^2)*1.0;%%%%%



%%%%% Minor adjustments only!!! %%%%%
segTopFactor = 0;%skews the top half of the screen
segBotFactor = -0;%skews the bottom half of the screen
segShiftFactor = -0;
segStretchFactor = 1.0;
segSkewFactor = 1.0;
segSkewVector = (linspace(0,1,height+1).^segSkewFactor-linspace(0,1,height+1)).*(-1)+1;
thetaMidFactor = 1.0;%rocks top v bottom elevation lines and shifts

onWallSegments = (linspace(onWall_floor2top+segTopFactor,...
    onWall_floor2bot+segBotFactor,...
    height+1)+segShiftFactor).*segSkewVector.*segStretchFactor;%%
onWallThetas = atan(onWallSegments./onFloor_proj2wall);
thetaF2M = atan(onWall_floor2mid/onFloor_proj2wall)*thetaMidFactor;
axisThetas = (onWallThetas-thetaF2M).*1;
axisSegments = tan(axisThetas).*atMid_proj2wall;
pixY = axisSegments(1:end-1)+diff(axisSegments)./2;
pixYplane = repmat(pixY(:),1,width).*1;
% pixY(1)+pixY(end)

onWall_mid2side = onWall_bot2top*(width/height)/2*whRatioAdjust;%%
atMidline_proj2wall = sqrt(onFloor_proj2wall^2+onWallSegments.^2);
thetas_mid2sides = atan(onWall_mid2side./atMidline_proj2wall);
atPlane_proj2mids = sqrt(atMid_proj2wall^2+axisSegments.^2);
mid2sides_top2bot = tan(thetas_mid2sides).*atPlane_proj2mids;
mid2sides_top2bot = mid2sides_top2bot(1:end-1)+diff(mid2sides_top2bot)./2;
mid2sides_factors = repmat(linspace(0,1,hW+1),height,1);
mid2sides_hPlaneSegs = repmat(mid2sides_top2bot(:),1,hW+1).*mid2sides_factors;
pixXplaneHalf = diff(mid2sides_hPlaneSegs,[],2)./2+mid2sides_hPlaneSegs(:,1:end-1);
pixXplane = ([fliplr(pixXplaneHalf).*(-1) pixXplaneHalf]);


% The following equation calculates the hypotenuse from the center to each
% pixel of the array, given cumulative sums in x and y from center
hypPlane = sqrt(pixXplane.^2+pixYplane.^2).*1.0;
% hypSkewVecTB = abs(cos(linspace(-pi/2,pi/2,height))-1).*linspace(-hypSkewTB,hypSkewTB,height);
hypSkewVecTB = linspace(-hypSkewTB,hypSkewTB,height);
hypSkewMatTB = repmat(hypSkewVecTB',1,width)+0.5;
% hypSkewVecLR = abs(cos(linspace(-pi/2,pi/2,width))-1).*linspace(-hypSkewLR,hypSkewLR,width);
hypSkewVecLR = linspace(-hypSkewLR,hypSkewLR,width);
hypSkewMatLR = repmat(hypSkewVecLR,height,1)+0.5;
hypPlane = hypPlane.*(hypSkewMatTB+hypSkewMatLR);
%
hypTwistVecA = linspace(-hypTwistA,hypTwistA,height)';
hypTwistMatA = hypTwistVecA*linspace(0,-abs(hypTwistA),width);
hypTwistVecB = linspace(-hypTwistB,hypTwistB,height)';
hypTwistMatB = fliplr(hypTwistVecB*linspace(0,-abs(hypTwistB),width));
hypTwistVecC = linspace(-hypTwistC,hypTwistC,width);
hypTwistMatC = hypTwistVecC'*linspace(0,-abs(hypTwistC),height);
hypTwistVecD = linspace(-hypTwistD,hypTwistD,width);
hypTwistMatD = fliplr(hypTwistVecD'*linspace(0,-abs(hypTwistD),height));
hypTwistPlane = hypTwistMatA+hypTwistMatB+hypTwistMatC'+hypTwistMatD'+1;
hypPlane = hypPlane.*hypTwistPlane;
% figure,imshow(hypTwistMatD',[])
% size(hypTwistMatC)
% max(hypTwistMatC(:))
% min(hypTwistMatC(:))

% figure, imshow(hypSkewMatTB,[])
% plot(hypSkewMatTB(:,1))
% %%
% plot([cos(linspace(-pi/2,0,hH)).*(-1)+2,cos(linspace(0,pi/2,hH))]-1)
% plot(sin(linspace(-pi/2,pi/2,height)))
% figure,plot(cos(linspace(-pi,0,height)))


% The following then subtracts the hypotenuse of the lens from that of the
% plane at the top of the mirror ('opposite' leg) and calculates the theta
% from origin for each pixel, knowing the distance lens is above plane
origTheta = atan(hypPlane./atMid_proj2wall);
% thSkewVecTB = repmat(linspace(0.5-thSkewTB,0.5+thSkewTB,height)',1,width);
% thSkewVecLR = repmat(linspace(0.5-thSkewLR,0.5+thSkewLR,width),height,1);
% origTheta = origTheta.*(thSkewVecTB+thSkewVecLR).*1.0;


%%%%% Determine the elevation at which the reflected rays intercept the
%%%%% dome, in degrees above (+) or below (-) the equator
mirPlane = hypPlane;
outerRingMir = rangesearch(mirPlane(:),mirRtop*topThreshFactor,1);
mirPlane(hypPlane > mirRtop*topThreshFactor*1.1) = NaN; %test: set ring of dots at max hyps around center
hypA = (mirPlane-mirRcntr);
oppA = sin(mirTheta).*hypA;
hypB = oppA./cos(mirTheta-origTheta);
adjB = sin(origTheta).*hypB;
oppC = cos(origTheta).*hypB;
thetaDepart = pi/2-2*mirTheta+origTheta;

mirPlane = mirPlane-adjB;
oppD = tan(thetaDepart).*mirPlane;
oppE = cos(thetaDepart).*(oppD+oppC);
oppE(abs(oppE) >= sphR) = NaN;
thetaE = asin(oppE./sphR);
eleFrmMir = thetaE-thetaDepart;

stimEleFrmMir = eleFrmMir;
eleFrmMir(eleFrmMir < minTheta) = NaN;
stimEleFrmMir(stimEleFrmMir < deg2rad(-25)) = 0;
stimEleFrmMir(isnan(stimEleFrmMir)) = 0;

%%%%% Determine the elevation at which the central rays intercept the dome,
%%%%% in degrees above the equator.  90 degrees is special, Inf using this
%%%%% method.  Set the center pixel manually (where origTheta=0, oppF=0)

adjT = cos(origTheta).*hypPlane;
adjT(abs(adjT) >= sphR) = NaN;
eleFrmTop = acos(adjT./sphR)+origTheta;

stimEleFrmTop = eleFrmTop;
stimEleFrmTop(stimEleFrmTop < deg2rad(0)) = 0;
stimEleFrmTop(isnan(stimEleFrmTop)) = 0;
stimEleForProc = stimEleFrmTop+stimEleFrmMir;

fadeSpan = deg2rad(5);
mirMaxEle = min(eleFrmMir(outerRingMir{:}));
topThresh = mirMaxEle-fadeSpan;
eleFrmTop(eleFrmTop < topThresh*0.99) = NaN;
topMask = false(height,width);
topMask(eleFrmTop > topThresh*0.99) = true;

elePlane = eleFrmMir;
elePlane(topMask) = eleFrmTop(topMask);

aziFull = atan2(pixYplane,pixXplane);

aziFrmTop = aziFull;
aziFrmMir = aziFull;
aziFull = aziFrmMir;
aziFull(topMask) = aziFrmTop(topMask);
stimAziForProc = aziFull;

aziFrmTop(~topMask) = NaN;
aziFrmMir(isnan(eleFrmMir)) = NaN;

aziPlane = aziFull;
aziPlane(isnan(elePlane)) = NaN;

%
% sphAzi = aziPlane(1:10:end,:);
% sphEle = elePlane(1:10:end,:);
% sphAzi = sphAzi(:,1:10:end);
% sphEle = sphEle(:,1:10:end);
% [x,y,z] = sph2cart(sphAzi,sphEle,300);
% surf(x,y,z)

hXeleVec = (-30:0.5:90);
hXaziVec = (-180:0.5:180);
hXw = numel(hXaziVec);
hXh = numel(hXeleVec);
hXele = repmat(hXeleVec(:),1,hXw);
hXazi = repmat(hXaziVec,hXh,1);

if calibrateOp == 2 || calibrateOp == 3
    hVal = zeros(hXh,hXw);
    if calibrateOp == 2
        lats = (0:10:160);
    else
        lats = 0;
    end
    latsMeet = round(rad2deg([mirMaxEle topThresh]));
    latsMeet = abs(deg2rad(latsMeet)-pi/2).*sphR;
    lats = [lats latsMeet];
    latsMat = repmat(lats,hXh,1);
    latsLutMat = repmat((abs(deg2rad(hXeleVec(:))-pi/2).*sphR),1,numel(lats));
    [~,latNdx] = min(abs(latsLutMat-latsMat));
    hVal(latNdx,:) = 1;
    gapSize = 14;%must be even
    blankVals = (1:gapSize:hXw);
    hXele_mm = abs(deg2rad(hXele)-pi/2).*sphR;
    meetRef = [numel(lats)-1 numel(lats)];
    for iterGap = 1:gapSize/2
        hVal(latNdx(meetRef),blankVals(1:end-1)+iterGap-1) = 0;
    end
    VqA = griddata(deg2rad(hXazi),hXele_mm,hVal,aziPlane,abs(eleFrmMir-pi/2).*sphR);
    hVal = zeros(hXh,hXw);
    hVal(latNdx,:) = 1;
    blankVals = (1:gapSize:hXw);
    for iterGap = (gapSize/2+1):gapSize
        hVal(latNdx(meetRef),blankVals(1:end-1)+iterGap-1) = 0;
    end
    VqB = griddata(deg2rad(hXazi),hXele_mm,hVal,aziPlane,abs(eleFrmTop-pi/2).*sphR);
    Vq = max(VqA,VqB);
    Vq(isnan(Vq)) = 0;
    Vq = Vq+stimRef+initIm;
    calibIm = repmat(uint8(Vq.*255),[1 1 3]);
    imwrite(calibIm,imReadPath)
    judp('send',portNum,hostIP,int8(54))
    return
end

%%%%%%%%%%%%%generating a lat line only image
lats = (-30:10:90);
latsMat = repmat(lats,hXh,1);
latsLutMat = repmat(hXeleVec(:),1,numel(lats));
[~,latNdxA] = min(abs(latsLutMat-latsMat));
hVal = zeros(hXh,hXw);
hVal(latNdxA,:) = 1;
hVal(end-2:end,:) = 1;
VqA = griddata(deg2rad(hXazi),deg2rad(hXele),hVal,aziPlane,eleFrmMir);
VqB = griddata(deg2rad(hXazi),deg2rad(hXele),hVal,aziPlane,eleFrmTop);
Vq = max(VqA,VqB);
Vq(isnan(Vq)) = 0;
latsOnlyIm = Vq;

% save(varPath,'stimEleForProc','stimAziForProc','stimRefROI',...
%     'crosshairsIm','shaderTop','shaderBot','latsOnlyIm','minTheta',...
%     'mirMaxEle','topThresh')

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
useOldStyle = true;
pezNameScan = 'pez3001';
if ~useOldStyle
    scanStatsName = ['photoScanResults_' pezNameScan,...
        '_whiteLED_10AzimuthalSteps_white_pt007_41.mat'];
    % scanStatsName = ['photoScanResults_' pezName,...
    %     '_whiteLED_10AzimuthalSteps.mat'];
else
    scanStatsName = ['photoScanResults_' pezNameScan,...
        '_greenLED_15degLatitudinalSteps.mat'];
end
scanStatsDest = fullfile(variablesDir,'scanningVariables',scanStatsName);
if ~exist(scanStatsDest,'file')
    error('no scan stats file')
end
scanStats = load(scanStatsDest);
scanStats = scanStats.scanStats;
scanmean = @(x) mean(cell2mat(cellfun(@(y) permute(y,[3 2 1]),x,'uniformoutput',false)),3);

fadeSeqVec = linspace(0,1,rad2deg(fadeSpan)+2);
fadeSeq = repmat(fadeSeqVec(2:end-1)',1,360);

rescanResults = cell2mat(scanStats.scanResults_rescan);
minD = median(rescanResults(:));% justified because more than half is black
topDensity = scanmean(scanStats.scanResults_top)';
botDensity = scanmean(scanStats.scanResults_bot)';
if ~useOldStyle
    rangeD = (max([topDensity(:);botDensity(:)])-minD);
    powerFun = 0.007;%white - 0.007%%%%%%%%%
    multiFun = 41;%white - 41 %%%%%%%%%%
else
    rangeD = (prctile([topDensity(:);botDensity(:)],99)-minD);
    powerFun = 1;%white - 0.007%%%%%%%%%
    multiFun = 1;%white - 41 %%%%%%%%%%
end
topDensity = (((topDensity-minD)./(rangeD)).^powerFun)*multiFun;
botDensity = (((botDensity-minD)./(rangeD)).^powerFun)*multiFun;
% topDensity = (topDensity)./range(topDensity(:));
% botDensity = (botDensity)./range(botDensity(:));
filtH = fspecial('average',[3 3]);
topDensity = imfilter(topDensity,filtH,'replicate');
botDensity = imfilter(botDensity,filtH,'replicate');
newMin = min([topDensity(:);botDensity(:)]);


elePos = ((cell2mat(scanStats.degX_top)-90)*(-1))';
aziPos = repmat(scanStats.Properties.RowNames',size(elePos,1),1);
aziPos = round(str2double(aziPos));
[~,sortNdx] = sort(aziPos(1,:));
for iterSort = 1:size(aziPos,1)
    topDensity(iterSort,:) = topDensity(iterSort,sortNdx);
    aziPos(iterSort,:) = aziPos(iterSort,sortNdx);
end
%
eleDestVec = linspace(rad2deg(topThresh),90,round(90-rad2deg(topThresh)))';
aziDestVec = (-179:180);
eleMat = repmat(eleDestVec,1,numel(aziDestVec));
aziMat = repmat(aziDestVec,numel(eleDestVec),1);

expand = @(x) [x x(:,1)];
aziPos = expand(aziPos);
aziPos(:,end) = aziPos(:,end)+360;
topFactor = interp2(expand(elePos)',aziPos',expand(topDensity)',eleMat',aziMat','spline')';
if ~useOldStyle
    topFactor = 1-(topFactor-newMin);
else
    topFactor = topFactor.^(-1);
    filtH = fspecial('average',[5 5]);
    topFactor = imfilter(topFactor,filtH,'replicate');
end
topFacFadePart = topFactor(1:rad2deg(fadeSpan),:);
topFader = topFacFadePart.*fadeSeq;
topFactor(1:rad2deg(fadeSpan),:) = topFader;
Finterp = scatteredInterpolant(deg2rad(eleMat(:)),deg2rad(aziMat(:)),topFactor(:));
vX = Finterp([eleFrmTop(:),aziFrmTop(:)]);
shaderTop = reshape(vX,height,width);
shaderTop(isnan(shaderTop)) = 0;

elePos = ((cell2mat(scanStats.degX_bot)-90)*(-1))';
aziPos = repmat(scanStats.Properties.RowNames',size(elePos,1),1);
aziPos = round(str2double(aziPos));
[~,sortNdx] = sort(aziPos(1,:));
for iterSort = 1:size(aziPos,1)
    botDensity(iterSort,:) = botDensity(iterSort,sortNdx);
    aziPos(iterSort,:) = aziPos(iterSort,sortNdx);
end
eleDestVec = linspace(rad2deg(minTheta),rad2deg(mirMaxEle),...
    round(rad2deg(mirMaxEle)-rad2deg(minTheta)))';
aziDestVec = (-179:180);
eleMat = repmat(eleDestVec,1,numel(aziDestVec));
aziMat = repmat(aziDestVec,numel(eleDestVec),1);

aziPos = expand(aziPos);
aziPos(:,end) = aziPos(:,end)+360;
botFactor = interp2(expand(elePos)',aziPos',expand(botDensity)',eleMat',aziMat','spline')';
if ~useOldStyle
    botFactor = 1-(botFactor-newMin);
else
    botFactor = botFactor.^(-1);
    botFactor = imfilter(botFactor,filtH,'replicate');
end
botFacFadePart = botFactor(end-rad2deg(fadeSpan)+1:end,:);
botFader = botFacFadePart.*flipud(fadeSeq);
botFactor(end-rad2deg(fadeSpan)+1:end,:) = botFader;
Finterp = scatteredInterpolant(deg2rad(eleMat(:)),deg2rad(aziMat(:)),botFactor(:));
vX = Finterp([eleFrmMir(:),aziFrmMir(:)]);
shaderBot = reshape(vX,height,width);
shaderBot(isnan(shaderBot)) = 0;

% mesh([topFactor;botFactor])

%
shaderMasterBrighter = (shaderTop+shaderBot);
shaderMasterBrighter = (shaderMasterBrighter./max(shaderMasterBrighter(:)));
if useOldStyle
    shaderMasterBrighter = mean(cat(3,fliplr(shaderMasterBrighter),shaderMasterBrighter),3);
end
% shaderMasterBrighter = max(cat(3,fliplr(shaderMasterBrighter),shaderMasterBrighter),[],3);
% shaderMasterBrighter = imfilter(shaderMasterBrighter,fspecial('average',[3 3]));
shaderMasterBrighter = max(shaderMasterBrighter,stimRef);
gainMatrixBrighter = repmat(shaderMasterBrighter,[1 1 3]);
gainMatrixBrighter(gainMatrixBrighter < 0) = 0;
gainMatrixBrighter(gainMatrixBrighter > 1) = 1;


% figure,imshow(gainMatrixBrighter)

imwrite(gainMatrixBrighter,imReadPath)
pause(0.25)
%     judp('send',portNum,hostIP,int8(54))
%
hVal = zeros(hXh,hXw);
lats = round(rad2deg((mirMaxEle+topThresh)/2));
lats = [lats -30 0];
latsMat = repmat(lats,hXh,1);
latsLutMat = repmat(hXeleVec(:),1,numel(lats));
[~,latNdx] = min(abs(latsLutMat-latsMat));
hVal(latNdx,:) = 1;
gapSize = 14;%must be even
blankVals = (1:gapSize:hXw);
for iterGap = 1:gapSize/2
    hVal(:,blankVals(1:end-1)+iterGap-1) = 0;
end
VqA = griddata(deg2rad(hXazi),deg2rad(hXele),hVal,aziPlane,eleFrmMir);
hVal = zeros(hXh,hXw);
hVal(latNdx,:) = 1;
blankVals = (1:gapSize:hXw);
for iterGap = (gapSize/2+1):gapSize
    hVal(:,blankVals(1:end-1)+iterGap-1) = 0;
end
VqB = griddata(deg2rad(hXazi),deg2rad(hXele),hVal,aziPlane,eleFrmTop);
Vq = max(VqA,VqB);
Vq(isnan(Vq)) = 0;
Vq = Vq+stimRef+initIm;
calibImB = repmat(uint8(shaderMasterBrighter.*Vq.*255),[1 1 3]);

if calibrateOp == 4
    imwrite(calibImB,imReadPath)
    pause(0.25)
    judp('send',portNum,hostIP,int8(54))
    return
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% figure,imshow(shaderMaster)
%%%%%%%%%   end making of old shaderMaster

% hXeleVec = (-30:90);
% hXaziVec = (-180:180);
% hXw = numel(hXaziVec);
% hXh = numel(hXeleVec);
% hXele = repmat(hXeleVec(:),1,hXw);
% hXazi = repmat(hXaziVec,hXh,1);
lats = (-30:10:90);
latsMat = repmat(lats,hXh,1);
latsLutMat = repmat(hXeleVec(:),1,numel(lats));
[~,latNdxA] = min(abs(latsLutMat-latsMat));
longs = (-180:10:180);
longsMat = repmat(longs,hXw,1);
longsLutMat = repmat(hXaziVec(:),1,numel(longs));
[~,longNdxA] = min(abs(longsLutMat-longsMat));

lats = [-2 2];
latsMat = repmat(lats,hXh,1);
latsLutMat = repmat(hXeleVec(:),1,numel(lats));
[~,latNdxB] = min(abs(latsLutMat-latsMat));
longs = [-180 -90 0 90 180];
longs = [longs-2 longs+2];
longsMat = repmat(longs,hXw,1);
longsLutMat = repmat(hXaziVec(:),1,numel(longs));
[~,longNdxB] = min(abs(longsLutMat-longsMat));

hVal = zeros(hXh,hXw);
hVal(latNdxA,:) = 1;
hVal(:,longNdxA) = 1;
hVal(latNdxB,:) = 0.5;
hVal(:,longNdxB) = 0.5;
VqA = griddata(deg2rad(hXazi),deg2rad(hXele),hVal,aziPlane,eleFrmMir);
VqB = griddata(deg2rad(hXazi),deg2rad(hXele),hVal,aziPlane,eleFrmTop);
Vq = max(VqA,VqB);
Vq(isnan(Vq)) = 0;
Vq = Vq+stimRef;
gridIm = repmat(uint8(shaderMasterBrighter.*Vq.*255),[1 1 3]);


%%%%%%%%%%%%%%generating a gridded background
lats = 0;
latsMat = repmat(lats,hXh,1);
latsLutMat = repmat(hXeleVec(:),1,numel(lats));
[~,latNdxA] = min(abs(latsLutMat-latsMat));

lats = [-2 2];
latsMat = repmat(lats,hXh,1);
latsLutMat = repmat(hXeleVec(:),1,numel(lats));
[~,latNdxB] = min(abs(latsLutMat-latsMat));

hVal = zeros(hXh,hXw);
hVal(latNdxA,:) = 1;
hVal(latNdxB,:) = 0.5;
VqA = griddata(deg2rad(hXazi),deg2rad(hXele),hVal,aziPlane,eleFrmMir);
VqB = griddata(deg2rad(hXazi),deg2rad(hXele),hVal,aziPlane,eleFrmTop);
Vq = max(VqA,VqB);
Vq(isnan(Vq)) = 0;
Vq = Vq+stimRef;
gridBackground = shaderMasterBrighter.*abs(Vq-1);
gridBackground = max(gridBackground,stimRef);

%%%%%%%%%%%%%% vertical lines
longs = (-180:10:180);
longsMat = repmat(longs,hXw,1);
longsLutMat = repmat(hXaziVec(:),1,numel(longs));
[~,longNdx] = min(abs(longsLutMat-longsMat));
hVal = zeros(hXh,hXw);
hVal(:,longNdx) = 1;
VqA = griddata(deg2rad(hXazi),deg2rad(hXele),hVal,aziPlane,eleFrmMir);
VqB = griddata(deg2rad(hXazi),deg2rad(hXele),hVal,aziPlane,eleFrmTop);
Vq = max(VqA,VqB);
Vq(isnan(Vq)) = 0;
vertLinesIm = im2bw(Vq);
vertLinesIm = repmat(uint8(vertLinesIm.*255),[1 1 3]);
whiteIm = uint8(gainMatrixBrighter.*255);
blackIm = repmat(uint8(zeros(height,width)),[1 1 3]);

% for use in the 'GainMatrix'
gainMatrix = gainMatrixBrighter;

save(varPath,'gainMatrix','stimEleForProc','stimAziForProc','stimRefROI',...
    'crosshairsIm','calibImB','gridIm','vertLinesIm','gridBackground',...
    'shaderTop','shaderBot','latsOnlyIm','minTheta','mirMaxEle','topThresh',...
    'gainMatrixBrighter')
%
if calibrateOp == 5
%     imwrite(gridIm,imReadPath)
    imwrite(gainMatrixBrighter,imReadPath)
    judp('send',portNum,hostIP,int8(54))
end


