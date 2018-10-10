function [stimTrigStruct] = initializeFramesFromFileUDP(stimStruct,fileName)

stimLoad = load(fullfile('Z:\pez3000_variables\visual_stimuli',fileName));
stimulusStruct = stimLoad.stimulusStruct;

%%%%% Establish variables needed in stimulus presentation
stimEleForProc = stimStruct.stimEleForProc;
stimAziForProc = stimStruct.stimAziForProc;
win = stimStruct.win;
warpmap = stimStruct.warpmap;
warpoperator = stimStruct.warpoperator;
stimRefROI = stimStruct.stimRefROI;

winRect = Screen('Rect',win);
height = winRect(4);
width = winRect(3);
hH = round(height/2);
hW = round(width/2);

eleScale = stimulusStruct.eleScale;%Determines resolution of undistorted image at the cost of speed
aziScale = stimulusStruct.aziScale;

eleCrop = imcrop(stimEleForProc,[hW-hH+1 1 height height]);
aziCrop = imcrop(stimAziForProc,[hW-hH+1 1 height height]);
aziSmall = imresize(aziCrop,[eleScale aziScale]);
eleSmall = imresize(eleCrop,[eleScale aziScale]);

%
winRect = Screen('Rect',win);
drawDest = CenterRect([0 0 height height],winRect);
warpimage = zeros(eleScale,aziScale,3);

% Determine where to place the "warp map":
img = uint8(zeros(eleScale,aziScale));
imgForTex = repmat(img,[1 1 3]);
imgtexDummy = Screen('MakeTexture',win,imgForTex);
imgRect = Screen('Rect',imgtexDummy);
refRect = CenterRect(imgRect,winRect);
xoffset = refRect(RectLeft);
yoffset = refRect(RectTop);
[xp, yp] = RectCenter(winRect);
xp = xp-xoffset;
yp = yp+yoffset;%dunno why this works, from ImageWarpingDemo (WRW)
warpDest = CenterRectOnPoint(imgRect,xp,yp);

eleOff = repmat(linspace(-eleScale/2+1,eleScale/2,eleScale)',1,aziScale);
aziOff = repmat(linspace(-aziScale/2+1,aziScale/2,aziScale),eleScale,1);


imgCell = stimulusStruct.imgCell;
imgReset = stimulusStruct.imgReset;
imgtexReset = Screen('MakeTexture',win,imgReset);

stimRefImageB = uint8(zeros(3,3,3));
stimRefTexB = Screen('MakeTexture',win,stimRefImageB);
% Apply image warpmap to image:
warpedtex = Screen('TransformTexture',imgtexReset,warpoperator,warpmap,[]);
% Draw and show the warped image:
Screen('DrawTexture',win,warpedtex,[],drawDest);
Screen('DrawTexture',win,stimRefTexB,[],stimRefROI);
Screen('Flip',win);
Screen('Close',warpedtex);

%%% Prepare main image textures
textureCt = numel(imgCell);
imgtex = cell(textureCt,1);
for iterPrep = 1:textureCt
    imgCat = imgCell{iterPrep};
    imgtex{iterPrep} = Screen('MakeTexture',win,imgCat);
end
imgFin = stimulusStruct.imgFin;
imgtexFin = Screen('MakeTexture',win,imgFin);

if isfield(stimulusStruct,'flipReference')
    flipReference = stimulusStruct.flipReference;
else
    flipReference = (1:textureCt);
end

%%% Flicker preparation
frameCt = numel(flipReference);
stimRefImageWA = uint8(cat(3,zeros(5)+10,zeros(5)+255,zeros(5)+255));
stimRefImageWB = uint8(cat(3,zeros(5)+255,zeros(5)+10,zeros(5)+10));
stimRefImCell = {stimRefImageWA,stimRefImageWB};
stimRefRefs = repmat([1 2]',ceil(frameCt/2),1);
stimRefRefs = stimRefRefs(:);
whiteCt = 0;
stimtex = cell(frameCt,1);
for iterPrep = 1:frameCt
    stimIm = stimRefImCell{stimRefRefs(iterPrep)};
    stimtex{iterPrep} = Screen('MakeTexture',win,stimIm);
    if stimRefRefs(iterPrep) == 1
        whiteCt = whiteCt+2;
    else
        whiteCt = whiteCt+1;
    end
end


stimTrigStruct = struct('stimTotalDuration',stimulusStruct.stimTotalDuration,...
    'drawDest',drawDest,'warpimage',warpimage,'aziSmall',aziSmall,'eleSmall',eleSmall,...
    'eleOff',eleOff,'aziOff',aziOff,'warpDest',warpDest,'win',win,...
    'warpmap',warpmap,'warpoperator',warpoperator,'stimRefROI',stimRefROI,...
    'whiteCt',whiteCt,'imgtexReset',imgtexReset,'imgtexFin',imgtexFin,...
    'stimRefTexB',stimRefTexB,'eleScale',eleScale,'aziScale',aziScale);
stimTrigStruct(1).imgtex = imgtex;
stimTrigStruct(1).stimtex = stimtex;
if isfield(stimulusStruct,'numLoops')
    stimTrigStruct(1).numLoops = stimulusStruct.numLoops;
end
stimTrigStruct(1).flipReference = flipReference;
