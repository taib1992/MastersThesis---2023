
clear;
close all;
clc;

%% add folders
addpath(genpath('experiments'));
addpath(genpath('Localization'));
addpath(genpath('Utils'));
addpath(genpath('PerParticle'));
%% experiments file

% selecting experiment, choo230726_153353_Cameraca_ova_dual_fret_alter_0_5mm_troloxse the experiment name as writen in the

expe_name = 'ca_ova_dual_fret_alter_0_5mm_trolox';
%% geting all the frames in the folder

experiment_path = [pwd,'\experiments\',expe_name,'\'];
table_frames = dir([experiment_path,'\*.tiff']);
frame_names = strcat(experiment_path,natsortfiles({table_frames.name}));
num_frames = size(table_frames,1);

%% visualzing a sample image to set limits for the experiment.
%

for frame_idx = 1% sample frame+d)
    frame = imread(frame_names{frame_idx});
    figure
    clims = [min(frame(:)) max(frame(:))];
    imagesc(frame,clims); colormap gray; colorbar;
    title(frame_idx)
    pause(0.1)
end
%% laser pairing and limits

num_channels = 1;

% for 532 laser:
c_532.uper_lim = 56; c_532.low_lim = 240;
c_532.left_lim = 100; c_532.right_lim = 400;
c_532.img_range = range2index(size(frame),c_532.low_lim,c_532.uper_lim,c_532.left_lim,c_532.right_lim);
c_532.start_frame = 1;


% for 640 laser:
c_640.uper_lim = 340; c_640.low_lim = 490;
c_640.left_lim = 120; c_640.right_lim = 320;
c_640.img_range = range2index(size(frame),c_640.low_lim,c_640.uper_lim,c_640.left_lim,c_640.right_lim);
c_640.start_frame = 1;


channel = [c_532,c_640];

%% choose the correct frames - by green or red laser on and which channel;
frame_vec=[];
Video=[];
GreenLaserOn=0; %0/1 - 0 off 1 on;
RedLaserOn=1; %0/1 - 0 off 1 on;
FrameTime=0.1/(GreenLaserOn+RedLaserOn);
GreenOrRedChannel=2; % 1 is green channel, 2 is red channel (now we use the red)

for i=1:num_frames
    frame = imread([experiment_path,'\Frame',num2str(i),'.tiff']);
    frameRed=frame(channel(2).uper_lim:channel(2).low_lim,channel(2).left_lim:channel(2).right_lim);
    frameGreen=frame(channel(1).uper_lim:channel(1).low_lim,channel(1).left_lim:channel(1).right_lim);
    if GreenOrRedChannel==2
        Video(:,:,i)=frameRed; %Video is the whole video of the a channel (for 2 types of laser)
    else
        Video(:,:,i)=frameGreen;
    end
    
    if  mean(frameRed(:))>500 % get rid of black frames
        if GreenLaserOn
            if mean(frameGreen(:))>400
                frame_vec(end+1)=i;
            end
        end
        if RedLaserOn
            if mean(frameGreen(:))<400
                frame_vec(end+1)=i;
            end
        end
    end
end
%% creating back ground map
c_532.bg_map = create_bg_map(c_532.img_range,c_532.start_frame,num_channels,frame_names);
c_640.bg_map = create_bg_map(c_640.img_range,c_640.start_frame,num_channels,frame_names,frame_vec);
c_532.particle_data = {};
c_640.particle_data = {};

figure; imagesc(c_532.bg_map)
title('Green Channel Back Ground');
figure; imagesc(c_640.bg_map)
title('Red Channel Back Ground');

% struct array

channel = [c_532,c_640];

%% finding particles center
for j=GreenOrRedChannel
    LoG_fwhm =3; %higher- more particles (the maxmial edge of the particle)
    bgth_factor =3; %lower- more particles (how above the background should I be)
    %
    
    %
    prs_val= 1;
    tot_frames = numel(frame_vec);
    
    pro_bar = waitbar(prs_val/tot_frames,"analysing frames...");
    
    for i=frame_vec
        
        frame = imread([experiment_path,'Frame',num2str(i),'.tiff']);
        frame = double(frame(channel(j).uper_lim:channel(j).low_lim,channel(j).left_lim:channel(j).right_lim));
        [x,y,p_size,energy] = particle_detection_2(frame,channel(j).bg_map,LoG_fwhm,bgth_factor);
        frame_table = table(x,y,p_size,energy);
        % size filter
        min_size = 1; max_size = 100;
        size_filter = p_size>min_size & p_size<max_size;
        
        %saving after filtering
        channel(j).particle_data{i} = frame_table(size_filter,:);
        
        % progress
        waitbar(prs_val/tot_frames,pro_bar,"analysing frames...");
        prs_val = prs_val+1;
        
    end
    close(pro_bar)
end



%% plot Particel Histogram
NumOfParticle=[];
temp=[];
FrameRes=40; % how many frame are being accumlated to one bin
for i=1:length(channel(GreenOrRedChannel).particle_data)
    if ~isempty(channel(GreenOrRedChannel).particle_data{i})
        yLocData=channel(GreenOrRedChannel).particle_data{i}.y;
        yMiddle=round(size(frame,2)/3);
        temp=repmat(i,1,sum(ismember(yLocData,[yMiddle-3:yMiddle+3])));
        if temp~=0
            NumOfParticle=[NumOfParticle,temp];
        end
    end
end
figure;  histogram(NumOfParticle,0:FrameRes:length(channel(GreenOrRedChannel).particle_data))
title('Number of Particles');
xlabel('Frame Number');

%% find average intensity
lookAround=2;
AllintensityPerParticlePerFrame=[];
baseProfile=mean(Video(:,:,frame_vec),3);
for i=1:length(frame_vec)
    
    particleData=channel(GreenOrRedChannel).particle_data{frame_vec(i)};
    particleData=particleData{:,:};
    particleData=particleData';
    intensityPerParticlePerFrame=[];
    getEnergy=Video(:,:,frame_vec(i))-baseProfile;
    for wantedPlace=1:size(particleData,2)
        intensityPerParticlePerFrame(end+1)=mean(mean(getEnergy(max(particleData(1,wantedPlace)-lookAround,1):min(particleData(1,wantedPlace)+lookAround,size(getEnergy,1)),max(particleData(2,wantedPlace)-lookAround,1):min(particleData(2,wantedPlace)+lookAround,size(getEnergy,2)))));
    end
    AllintensityPerParticlePerFrame(i)=sum(intensityPerParticlePerFrame);
    particleData=[];
end
figure; plot(frame_vec,AllintensityPerParticlePerFrame)

%% play and save the movie
v = VideoWriter('experimentMovie.mp4');
v.FrameRate =1/FrameTime;
open(v);
figure;
for i=frame_vec(1:end)
    %play the movie;
    frame = imread([experiment_path,'\Frame',num2str(i),'.tiff']);
    frame=frame(channel(GreenOrRedChannel).uper_lim:channel(GreenOrRedChannel).low_lim,channel(GreenOrRedChannel).left_lim:channel(GreenOrRedChannel).right_lim);
    imagesc(frame);
    colormap(gray);
    title(num2str(i))
    pause(FrameTime);
    
    y=uint8(255 * mat2gray(frame));
    %insert markers of particles to the video
    try
        y= insertMarker(y, [channel(GreenOrRedChannel).particle_data{i}.y , channel(GreenOrRedChannel).particle_data{i}.x]);
    end
    %save it
    y=imresize(y,4);
    writeVideo(v,y);
end
close(v);
%% Plot the bulk analysis

allVid=[];

for colInd=median(channel(GreenOrRedChannel).left_lim:channel(GreenOrRedChannel).right_lim)
    for i=1:length(frame_vec)
        frame = imread([experiment_path,'\Frame',num2str(frame_vec(i)),'.tiff']);
        frame=frame(channel(GreenOrRedChannel).uper_lim:channel(GreenOrRedChannel).low_lim,channel(GreenOrRedChannel).left_lim:channel(GreenOrRedChannel).right_lim);
        %colInd=median(channel(j).left_lim:channel(j).right_lim);
        allVid(:,end+1)=frame(:,round(size(frame,2)/2));
    end
    min_val=min(min(allVid(:,1:100)));
    max_val=max(max(allVid(:,1:100)));
    clims = [min(min(allVid(:,1:100))) 0.85*max(max(allVid(:,1:100)))];
    figure;
    subplot(2,1,1);
    imagesc(frame_vec,1:size(allVid,1),allVid,clims);
    xlabel('Frame Number');
    title('Kymograph')
    colormap(gray);
    subplot(2,1,2);
    colSum=mean(allVid);
    norm_colSum=(colSum-min(colSum))./(max(colSum)-min(colSum));
    plot(frame_vec,norm_colSum);
    xlim([frame_vec(1) frame_vec(end)])
    title('Intensity Analysis');
    xlabel('Frame Number');
    ylabel('Relative Intensity');
end

%% track and exctract features
framesInBatch=100; %how many frames in one run- set to 120
overlap=0; % how many overlaps in our frames time
FirstFrame=600;
LastFrame=799;
maxYStd=9*framesInBatch/50; % maximal std in y movement to later on remove higher std than this value
minimalAge=4;
lookAround=2;
invisibleForTooLong=10;
XnoiseKalman=1;
YnoiseKalman=1;

allStd=[];
allSpeed=[];
allSpeedNormCurr=[];
allYdiff=[];
AllDataForCluster=[];
AllDataForClusterNorm=[];
tempFRET=[];
KeepMe=[];
baseRedProfile=mean(Video(:,:,frame_vec(1:400)),3);
baseFRETProfile= mean(Video(:,:,setdiff(1:frame_vec(400)-2,frame_vec(1:400))),3); %mean(Video(:,:,setdiff(1:400,frame_vec(1:100))),3)
S=[];
redOverTime=nan(55,2000);
FRETCAOVAOverTime=nan(55,2000);
velocityOverTime=nan(55,2000);
pp=1;
for i=FirstFrame:round(framesInBatch/overlap):LastFrame
    [a,b]=min(abs(frame_vec-i));
    VecFrame=frame_vec(b:b+framesInBatch-1);
    %calculate the route of each protein
    KeepMe=[];
    mat=MultiObjectTracking(VecFrame,channel,GreenOrRedChannel,expe_name,invisibleForTooLong,XnoiseKalman,YnoiseKalman,KeepMe);
    xSpeed=[];
    EnergyOfParticle=[];
    EnergyOfParticleFRET=[];
    for idWanted=1:1500
        n=1;
        trackLoc=[];
        EnergyTrackPerParticle=[];
        EnergyTrackPerParticleFRET=[];
        tempVel=[];
        FrameNum=[];
        FrameNumFRET=[];
        trackLocFRET=[];
        for j=1:length(mat)
            getEnergy=Video(:,:,VecFrame(j))-baseRedProfile;
            if any([mat{j}.id]==idWanted)
                wantedPlace=find([mat{j}.id]==idWanted);
                locMat=reshape([mat{j}.bbox],4,length([mat{j}.bbox])/4);
                trackLoc(:,n)=locMat(1:2,wantedPlace); %(x,y) location of a protein
                ageVec=[mat{j}.age];
                age(idWanted)=ageVec(wantedPlace); % how many frames we has the protein
                kk=getEnergy(max(locMat(2,wantedPlace)-lookAround,1):min(locMat(2,wantedPlace)+lookAround,size(getEnergy,1)),max(locMat(1,wantedPlace)-lookAround,1):min(locMat(1,wantedPlace)+lookAround,size(getEnergy,2)));
                EnergyTrackPerParticle(n)=mean(kk(:)); % the red intensity over the route
                kk=[];
                FrameNum(n)=VecFrame(j); % the frames it appeared in the red video
                n=n+1;
            end
        end
        % find fret route of each protein
        if length(FrameNum)>1
            allFrame=FrameNum(1):FrameNum(end)+1;
            FrameNumFRET=setdiff(allFrame,FrameNum);
            trackLocFRET(1,:)=round(interp1(FrameNum,trackLoc(1,:),FrameNumFRET,'linear','extrap'));
            trackLocFRET(2,:)=round(interp1(FrameNum,trackLoc(2,:),FrameNumFRET,'linear','extrap'));
            for p=1:length(FrameNumFRET)
                getEnergyFRET=Video(:,:,FrameNumFRET(p))-baseFRETProfile;
                for m=0 % for fast proteins m/n==-1:1, otherwise 0
                    for n=0
                        kkFRET=getEnergyFRET(max(trackLocFRET(2,p)-lookAround+m,1):min(trackLocFRET(2,p)+lookAround+m,size(getEnergy,1)),max(trackLocFRET(1,p)+n-lookAround,1):min(trackLocFRET(1,p)+n+lookAround,size(getEnergy,2)));
                        tempFRET(end+1)=mean(kkFRET(:));
                        kkFRET=[];
                    end
                end
                EnergyTrackPerParticleFRET(p)=max(tempFRET);
                tempFRET=[];
            end
        end
        % extract 4 features per protein
        if ~isempty(trackLoc) && age(idWanted)>=minimalAge
            whereDidIgo=trackLoc(1,end)-trackLoc(1,1);
            if std(trackLoc(2,:))<maxYStd && whereDidIgo>0 && max(trackLoc(1,:))>= round(size(getEnergy,2)/2) && min(trackLoc(1,:))<= round(size(getEnergy,2)/2)
                redOverTime(1:length(EnergyTrackPerParticle),pp)=EnergyTrackPerParticle;
                FRETCAOVAOverTime(1:length(EnergyTrackPerParticleFRET),pp)=EnergyTrackPerParticleFRET;
                tempVel=5.4*(0.05/FrameTime).*(diff(trackLoc(1,:)).^2 + diff(trackLoc(2,:)).^2).^0.5;
                velocityOverTime(1:length(tempVel),pp)=tempVel;
                xSpeed(idWanted)=5.4*(0.05/FrameTime)*sum((diff(trackLoc(1,:)).^2 + diff(trackLoc(2,:)).^2).^0.5)/age(idWanted);
       
                
                EnergyOfParticle(idWanted)=prctile(EnergyTrackPerParticle,50);
                EnergyOfParticleFRET(idWanted)=prctile(EnergyTrackPerParticleFRET,50);
                FrameOfMiddle(idWanted)=0.05*FrameNum(find(trackLoc(1,:)>=round(size(getEnergy,2)/2) ,1));
                pp=pp+1;
                 AllDataForCluster(end+1,:)=[xSpeed(idWanted),FrameOfMiddle(idWanted),EnergyOfParticle(idWanted),EnergyOfParticleFRET(idWanted)]';
                KeepMe(end+1)=idWanted;
                S{1,end+1}=trackLoc;
                S{2,end}=FrameNum;
                
            end
            
        end
    end
end


bins{1}=5.4*[1:0.3:5]; % bins for velocity histogram
bins{2}=0.05*[1400:200:4000]; %bins for time of arrival histogram
bins{3}=-100:95:2000; %bins for red histogram
bins{4}=-100:60:2000; %bins for fret histogram
ShowMyData(AllDataForCluster,[],bins); % presenting the data in 4x4 histogram/scatter plot

AllDataForClusterNorm=(AllDataForCluster-mean(AllDataForCluster))./(std(AllDataForCluster));

%PCA
score=[];
[coeff,score,latent,tsquared,explained] = pca(AllDataForClusterNorm);
figure; scatter(score(:,1),score(:,2),'.');
title('PCA - CA and OVA');
xlabel('PCA-1');
ylabel('PCA-2');

%t-SNE
Y = tsne(AllDataForClusterNorm);
figure; scatter(Y(:,1),Y(:,2),'.');
title('t-SNE');
%% Classify the data
%choose the number of classifies
topgrade=[];

for thresh=185% to remove outliers if wanted
    vec= AllDataForCluster(:,4)>thresh;
    AllDataForClusterNorm=(AllDataForCluster(vec,:)-mean(AllDataForCluster(vec,:)))./(std(AllDataForCluster(vec,:)));
    Y = tsne(AllDataForClusterNorm);

    for regul=[0]
        for sent=[-1]
            grade=[];
            %figure;
            for k=1:10 % number of clusters
                try
                    initialGuess = kmeans(AllDataForCluster(vec,2),k);

                    options = statset('Display','off','MaxIter',5000,'TolFun',1^sent);
                    GMMmodel = fitgmdist(AllDataForCluster(vec,:),k,'Options',options,'Start',initialGuess,'RegularizationValue',regul);
                    clusterGMM = cluster(GMMmodel,AllDataForCluster(vec,:));
                    GMMmodel.ComponentProportion
                    if k==2
                        modelWanted=GMMmodel;
                        initialGuessWanted=initialGuess;
                        ShowMyData(AllDataForCluster(vec,:),cluster(modelWanted,AllDataForCluster(vec,:)),bins);
                    end
                    
                    % some eval methods can have vlaue for 1 cluster ,  so
                    % artificially adding one point to a different cluster
                    if k==1
                        clusterGMM(1)=2;
                    end
                    % grade is the matrix for eval values
                    grade(1,end+1)=GMMmodel.BIC;
                    grade(2,end)=GMMmodel.AIC;
                    eva1 = evalclusters(AllDataForCluster(vec,:),clusterGMM,'CalinskiHarabasz');
                    grade(3,end)=eva1.CriterionValues;
                    eva2 = evalclusters(AllDataForCluster(vec,:),clusterGMM,'DaviesBouldin');
                    grade(4,end)=eva2.CriterionValues;
                    eva3 = evalclusters(AllDataForCluster(vec,:),clusterGMM,'silhouette');
                    grade(5,end)=eva3.CriterionValues;
                    grade(1,end)=0;
                end
                
            end
            [~,f]=max(grade(3,:));
            f
            if  f==2
                %thresh
                topgrade(:,:,end+1)=grade;
                initialGuessBest=initialGuessWanted;
                bestY=Y;
                topModel=modelWanted;
                ShowMyData(AllDataForCluster(vec,:),cluster(topModel,AllDataForCluster(vec,:)),bins);
                title([num2str(sent),' ',num2str(regul)])
            end
            color=['b','r','m','c','g','k','w'];
            
            
        end
    end
    
    
    %PCA
    score=[];
    [coeff,score,latent,tsquared,explained] = pca(AllDataForClusterNorm);
    figure; gscatter(score(:,1),score(:,2),clusterGMM,color(1:4));
    title('classified - PCA');
    xlabel('PCA-1');
    ylabel('PCA-2');
    legend('');
    
    %t-SNE
    %     Y = tsne(AllDataForClusterNorm);
    %     figure; gscatter(Y(:,1),Y(:,2),clusterGMM,color(1:4));
    %     title('classified - t-SNE');
end
%% the end
finalAllDataForCluster=AllDataForCluster(vec,:);
FinalGrade=squeeze(topgrade(:,:,2))';
FinalCluster=cluster(topModel,finalAllDataForCluster);
ShowMyData(finalAllDataForCluster,FinalCluster,bins);
figure;
gscatter(score(:,1),score(:,2),FinalCluster,color(1:4));


%you need to take AllDataForCluster(vec,:) - the one without outliers

%                 ClusterGMM - the cluster

%                 score(:,1) & score (:,2) - the PCA

%                 grade - all 5 methods but number 3 (calinski-harabatsz)
%                 is the importent one
