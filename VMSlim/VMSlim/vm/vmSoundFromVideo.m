function [S] = vmSoundFromVideo(vHandle, nscalesin, norientationsin, varargin)
%   Extracts audio from tiny vibrations in video.
%   Optional argument DownsampleFactor lets you specify some factor to
%   downsample by to make processing faster. For example, 0.5 will
%   downsample to half size, and run the algorithm.

tic;
startTime = toc;
% Parameters

defaultnframes = 0;
defaultDownsampleFactor = 1;
defaultsamplingrate = -1;
p = inputParser();
addOptional(p, 'DownsampleFactor', defaultDownsampleFactor, @isnumeric);   
addOptional(p, 'NFrames', defaultnframes, @isnumeric);   
addOptional(p, 'SamplingRate', defaultsamplingrate, @isnumeric);   
parse(p, varargin{:});
nScales = nscalesin;
nOrients = norientationsin;
dSampleFactor = p.Results.DownsampleFactor;
numFramesIn = p.Results.NFrames;
samplingrate = p.Results.SamplingRate;

if(samplingrate<0)
    samplingrate = vHandle.FrameRate;
end


'Reading first frame of video'
colorframe = vHandle.read(1);
'Successfully read first frame of video'

if(dSampleFactor~=1)
    colorframe = imresize(colorframe,dSampleFactor);
end

fullFrame = im2single(squeeze(mean(colorframe,3)));
refFrame = fullFrame;

[h,w] = size(refFrame);%height and width of video in pixels

nF = numFramesIn;
if(nF==0)
    %depending on matlab and type of video you are using, may need to read
    %the last frame
    %lastFrame = read(vHandle, inf); 
    nF = vHandle.NumberOfFrames;%number of frames
end  


%params.nScales = nScales;
%params.nOrientations = nOrients;
%params.dSampleFactor = dSampleFactor;
%params.nFrames = nF;

%%

[pyrRef, pind] = buildSCFpyr(refFrame, nScales, nOrients-1);

for j = 1:nScales
    for k = 1:nOrients
        bandIdx = 1+nOrients*(j-1)+k;    
    end
end

%

totalsigs = nScales*nOrients;
signalffs = zeros(nScales,nOrients,nF);
ampsigs = zeros(nScales,nOrients,nF);

%

% Process
nF

for q = 1:nF
    if(mod(q,floor(nF/100))==1)
        progress = q/nF;
        currentTime = toc;
        ['Progress:' num2str(progress*100) '% done after ' num2str(currentTime-startTime) ' seconds.']
    end
    
    vframein = vHandle.read(q);
    if(dSampleFactor == 1)
        fullFrame = im2single(squeeze(mean(vframein,3)));
    else
        fullFrame = im2single(squeeze(mean(imresize(vframein,dSampleFactor),3)));
    end
    
    im = fullFrame;
    
    pyr = buildSCFpyr(im, nScales, nOrients-1);
    pyrAmp = abs(pyr);
    pyrDeltaPhase = mod(pi+angle(pyr)-angle(pyrRef), 2*pi) - pi;   
    
    
    for j = 1:nScales
        bandIdx = 1 + (j-1)*nOrients + 1;
        curH = pind(bandIdx,1);
        curW = pind(bandIdx,2);        
        for k = 1:nOrients
            bandIdx = 1 + (j-1)*nOrients + k;
            amp = pyrBand(pyrAmp, pind, bandIdx);
            phase = pyrBand(pyrDeltaPhase, pind, bandIdx);
            
            %weighted signals with amplitude square weights. 
            phasew = phase.*(abs(amp).^2);
            
            sumamp = sum(abs(amp(:)));
            ampsigs(j,k,q)= sumamp;
            
            signalffs(j,k,q)=mean(phasew(:))/sumamp;
        end
    end    
end

%avx is average x
S.samplingRate = samplingrate;

%%

sigOut = zeros(nF, 1);
for q=1:nScales
    for p=1:nOrients
        [sigaligned, shiftam] = vmAlignAToB(squeeze(signalffs(q,p,:)), squeeze(signalffs(1,1,:)));
        sigOut = sigOut+sigaligned;
        shiftam
    end
end

S.aligned = sigOut;

%sometimes the alignment aligns on noise and boosts it, in which case just
%use averaging with no alignment, or highpass before alignment
S.averageNoAlignment = mean(reshape(double(signalffs),nScales*nOrients,nF)).';

highpassfc = 0.05;
[b,a] = butter(3,highpassfc,'high');
S.x = filter(b,a,S.aligned);

%sometimes butter doesn't fix the first few entries
S.x(1:10)=mean(S.x);

maxsx = max(S.x);
minsx = min(S.x);
if(maxsx~=1.0 || minsx ~= -1.0)
    range = maxsx-minsx;
    S.x = 2*S.x/range;
    newmx = max(S.x);
    offset = newmx-1.0;
    S.x = S.x-offset;
end


end
