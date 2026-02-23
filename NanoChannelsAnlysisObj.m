classdef NanoChannelsAnlysisObj < handle
    % NanoChannelsAnlysisObj - Single particle tracking and FRET analysis class
    % Handles localization, tracking, feature extraction, and clustering
    % of dual-channel fluorescence microscopy data.
    %
    % Usage:
    %   pa = NanoChannelsAnlysisObj('ca_ova_dual_fret_alter_0_5mm_trolox');
    %   pa.loadFrames();
    %   pa.setChannelLimits();
    %   pa.selectFrames();
    %   pa.createBackgroundMaps();
    %   pa.detectParticles();
    %   pa.trackAndExtractFeatures();
    %   pa.classifyData();

    %% ----------------------------------------------------------------
    %  Properties
    %  ----------------------------------------------------------------
    properties
        % Experiment
        ExpPath         
        FrameNames    
        NumFrames      

        % Channels
        C532               % Green channel (532 nm laser)
        C640            % Red channel (640 nm laser)
        Channel           % Combined [C532, C640]

        % Acquisition settings
        GreenLaserOn  = false
        RedLaserOn   = true
        GreenOrRedChannel  = 2   % 1 = green, 2 = red

        % Frame selection
        FrameVec   % Indices of valid frames
        Video      % Raw video stack (ROI, selected channel)

        % Detection parameters
        LoG_FWHM   = 3
        BgthFactor  = 3
        MinSize    = 1
        MaxSize   = 100

        % Tracking parameters
        FramesInBatch  = 365
        Overlap  = 0
        FirstFrame  = 400
        LastFrame = 1135
        MaxYStd  = [] % set automatically if empty
        MinimalAge   = 4
        LookAround  =  2
        InvisibleForTooLong = 10
        XNoiseKalman    = 1
        YNoiseKalman    = 1

        % Results
        AllDataForCluster    % [speed, time, redEnergy, FRETenergy]
        FinalCluster      
        TrackLocations       % S{1,:} = trackLoc, S{2,:} = frameNums
        RedOverTime      
        FRETOverTime        
        VelocityOverTime    

        % Clustering model
        GMMModel            % fitgmdist output
        PCAScore          
        PCACoeff           
        PCAExplained   
        maxNumClusters = 10;

        % Histogram bins
        Bins     
    end

    properties (Access = private)
        SampleFrame         % First frame image (for sizing)
        FrameTime        % Effective frame time (s)
    end

    %% ----------------------------------------------------------------
    %  Constructor
    %  ----------------------------------------------------------------
    methods
        function obj = NanoChannelsAnlysisObj(expPath)
            obj.ExpPath = [expPath,'\'];
            % Default histogram bins
            obj.Bins{1} = 5.4 * (1:0.3:5);
            obj.Bins{2} = 0.05 * (obj.FirstFrame:50:obj.LastFrame);
            obj.Bins{3} = -100:95:1500;
            obj.Bins{4} = -100:60:1000;
        end
    end

    %% ----------------------------------------------------------------
    %  Public Methods
    %  ----------------------------------------------------------------
    methods (Access = public)

        % ----------------------------------------------------------
        function loadFrames(obj)
            % Discover all .tiff frames in the experiment folder.
            tableFrames   = dir([obj.ExpPath, '*.tiff']);
            obj.FrameNames = strcat(obj.ExpPath, natsortfiles({tableFrames.name}));
            obj.NumFrames  = size(tableFrames, 1);
            fprintf('Found %d frames in: %s\n', obj.NumFrames, obj.ExpPath);
        end

        % ----------------------------------------------------------
        function setChannelLimits(obj, c532, c640)
            % setChannelLimits() - use defaults, or pass custom structs.
            % Each struct must have fields: uper_lim, low_lim, left_lim, right_lim.
            if nargin < 2
                c532.uper_lim = 56;  c532.low_lim = 240;
                c532.left_lim = 100; c532.right_lim = 400;
            end
            if nargin < 3
                c640.uper_lim = 340; c640.low_lim = 490;
                c640.left_lim = 120; c640.right_lim = 320;
            end

            obj.SampleFrame = imread(obj.FrameNames{1});

            c532.img_range  = range2index(size(obj.SampleFrame), ...
                c532.low_lim, c532.uper_lim, c532.left_lim, c532.right_lim);
            c532.start_frame = 1;
            c532.particle_data = {};
            c532.bg_map = [];

            c640.img_range  = range2index(size(obj.SampleFrame), ...
                c640.low_lim, c640.uper_lim, c640.left_lim, c640.right_lim);
            c640.start_frame = 1;
            c640.particle_data = {};
            c640.bg_map = [];

            obj.C532    = c532;
            obj.C640    = c640;
            obj.Channel = [c532, c640];
        end

        % ----------------------------------------------------------
        function visualizeSampleFrame(obj, frameIdx)
            % Show a sample frame with auto contrast limits.
            if nargin < 2, frameIdx = 1; end
            frame = imread(obj.FrameNames{frameIdx});
            clims = [min(frame(:)), max(frame(:))];
            figure;
            imagesc(frame, clims); colormap gray; colorbar;
            title(['Frame ', num2str(frameIdx)]);
        end

        % ----------------------------------------------------------
        function selectFrames(obj)
            % Build FrameVec (valid frames) and Video stack.
            numCh = obj.GreenLaserOn + obj.RedLaserOn;
            obj.FrameTime = 0.1 / numCh;

            ch     = obj.Channel;
            chIdx  = obj.GreenOrRedChannel;
            obj.FrameVec = [];
            obj.Video    = [];

            for i = 1:obj.NumFrames
                frame = imread([obj.ExpPath, 'Frame', num2str(i), '.tiff']);
                frameRed   = frame(ch(2).uper_lim:ch(2).low_lim, ch(2).left_lim:ch(2).right_lim);
                frameGreen = frame(ch(1).uper_lim:ch(1).low_lim, ch(1).left_lim:ch(1).right_lim);

                if chIdx == 2
                    obj.Video(:,:,i) = frameRed;
                else
                    obj.Video(:,:,i) = frameGreen;
                end

                if mean(frameRed(:)) > 500
                    if obj.GreenLaserOn && mean(frameGreen(:)) > 400
                        obj.FrameVec(end+1) = i;
                    end
                    if obj.RedLaserOn && mean(frameGreen(:)) < 400
                        obj.FrameVec(end+1) = i;
                    end
                end
            end
            fprintf('Selected %d valid frames.\n', numel(obj.FrameVec));
        end

        % ----------------------------------------------------------
        function createBackgroundMaps(obj)
            % Compute background maps for both channels.
            numCh = 1;
            obj.C532.bg_map = create_bg_map(obj.C532.img_range, ...
                obj.C532.start_frame, numCh, obj.FrameNames);
            obj.C640.bg_map = create_bg_map(obj.C640.img_range, ...
                obj.C640.start_frame, numCh, obj.FrameNames, obj.FrameVec);

            obj.Channel = [obj.C532, obj.C640];

            figure; imagesc(obj.C532.bg_map); colormap gray;
            title('Green Channel Background');
            figure; imagesc(obj.C640.bg_map); colormap gray;
            title('Red Channel Background');
        end

        % ----------------------------------------------------------
        function detectParticles(obj)
            % Run LoG-based particle detection on all valid frames.
            j         = obj.GreenOrRedChannel;
            ch        = obj.Channel;
            frameVec  = obj.FrameVec;
            totFrames = numel(frameVec);
            prsVal    = 1;
            proBar    = waitbar(0, 'Detecting particles...');

            for i = frameVec
                frame = imread([obj.ExpPath, 'Frame', num2str(i), '.tiff']);
                frame = double(frame(ch(j).uper_lim:ch(j).low_lim, ...
                                     ch(j).left_lim:ch(j).right_lim));

                [x, y, p_size, energy] = particle_detection_2(frame, ch(j).bg_map, ...
                    obj.LoG_FWHM, obj.BgthFactor);

                frameTable  = table(x, y, p_size, energy);
                sizeFilter  = p_size > obj.MinSize & p_size < obj.MaxSize;
                ch(j).particle_data{i} = frameTable(sizeFilter, :);

                waitbar(prsVal/totFrames, proBar, 'Detecting particles...');
                prsVal = prsVal + 1;
            end
            close(proBar);

            % Push results back into object
            if j == 1, obj.C532 = ch(j); else, obj.C640 = ch(j); end
            obj.Channel = ch;
            fprintf('Particle detection complete.\n');
        end

        % ----------------------------------------------------------
        function plotParticleHistogram(obj)
            % Histogram of particle counts vs. frame number.
            chIdx    = obj.GreenOrRedChannel;
            pData    = obj.Channel(chIdx).particle_data;
            frameRes = 40;
            numOfParticle = [];

            for i = 1:length(pData)
                if ~isempty(pData{i})
                    yLocData = pData{i}.y;
                    yMiddle  = round(size(obj.SampleFrame, 2) / 3);
                    temp     = repmat(i, 1, sum(ismember(yLocData, (yMiddle-3):(yMiddle+3))));
                    if ~isempty(temp)
                        numOfParticle = [numOfParticle, temp]; %#ok<AGROW>
                    end
                end
            end

            figure;
            histogram(numOfParticle, 0:frameRes:length(pData));
            title('Number of Particles');
            xlabel('Frame Number');
        end

        % ----------------------------------------------------------
        function plotAverageIntensity(obj)
            % Plot summed intensity of detected particles per frame.
            chIdx      = obj.GreenOrRedChannel;
            frameVec   = obj.FrameVec;
            lookAround = obj.LookAround;
            vid        = obj.Video;
            baseProfile = mean(vid(:,:,frameVec), 3);
            allIntensity = zeros(1, length(frameVec));

            for i = 1:length(frameVec)
                pData = obj.Channel(chIdx).particle_data{frameVec(i)};
                if isempty(pData), continue; end
                pd    = pData{:,:}';
                getEn = vid(:,:,frameVec(i)) - baseProfile;
                intPerParticle = zeros(1, size(pd,2));

                for k = 1:size(pd,2)
                    r1 = max(pd(1,k)-lookAround, 1);
                    r2 = min(pd(1,k)+lookAround, size(getEn,1));
                    c1 = max(pd(2,k)-lookAround, 1);
                    c2 = min(pd(2,k)+lookAround, size(getEn,2));
                    intPerParticle(k) = mean(mean(getEn(r1:r2, c1:c2)));
                end
                allIntensity(i) = sum(intPerParticle);
            end

            figure;
            plot(frameVec, allIntensity);
            xlabel('Frame Number');
            ylabel('Total Intensity');
            title('Average Intensity Over Time');
        end

        % ----------------------------------------------------------
        function saveMovie(obj, filename)
            % Save an annotated MP4 movie of the selected channel.
            if nargin < 2, filename = 'experimentMovie.mp4'; end
            chIdx = obj.GreenOrRedChannel;
            ch    = obj.Channel(chIdx);

            v = VideoWriter(filename, 'MPEG-4');
            v.FrameRate = 1 / obj.FrameTime;
            open(v);
            figure;

            for i = obj.FrameVec
                frame = imread([obj.ExpPath, 'Frame', num2str(i), '.tiff']);
                frame = frame(ch.uper_lim:ch.low_lim, ch.left_lim:ch.right_lim);
                imagesc(frame); colormap(gray); title(num2str(i));
                pause(obj.FrameTime);

                y = uint8(255 * mat2gray(frame));
                y = insertMarker(y, [ch.particle_data{i}.y, ch.particle_data{i}.x]);
                y = imresize(y, 4);
                writeVideo(v, y);
            end
            close(v);
            fprintf('Movie saved to: %s\n', filename);
        end

        % ----------------------------------------------------------
        function plotKymograph(obj)
            % Plot kymograph and normalised intensity along central column.
            chIdx    = obj.GreenOrRedChannel;
            ch       = obj.Channel(chIdx);
            frameVec = obj.FrameVec;
            allVid   = [];

            for i = 1:length(frameVec)
                frame = imread([obj.ExpPath, 'Frame', num2str(frameVec(i)), '.tiff']);
                frame = frame(ch.uper_lim:ch.low_lim, ch.left_lim:ch.right_lim);
                allVid(:, end+1) = frame(:, round(size(frame,2)/2)); %#ok<AGROW>
            end

            clims = [min(min(allVid(:,1:100))), 0.85*max(max(allVid(:,1:100)))];
            figure;
            subplot(2,1,1);
            imagesc(frameVec, 1:size(allVid,1), allVid, clims);
            colormap(gray); xlabel('Frame Number'); title('Kymograph');

            subplot(2,1,2);
            colSum      = mean(allVid);
            normColSum  = (colSum - min(colSum)) ./ (max(colSum) - min(colSum));
            plot(frameVec, normColSum);
            xlim([frameVec(1), frameVec(end)]);
            title('Intensity Analysis');
            xlabel('Frame Number'); ylabel('Relative Intensity');
        end

        % ----------------------------------------------------------
        function trackAndExtractFeatures(obj)
            % Multi-object tracking and feature extraction over batches.
            if isempty(obj.MaxYStd)
                obj.MaxYStd = 9 * obj.FramesInBatch / 50;
            end

            chIdx      = obj.GreenOrRedChannel;
            ch         = obj.Channel;
            frameVec   = obj.FrameVec;
            lookAround = obj.LookAround;
            vid        = obj.Video;

            baseRedProfile  = mean(vid(:,:, frameVec(1:400)), 3);
            baseFRETProfile = mean(vid(:,:, setdiff(1:frameVec(400)-2, frameVec(1:400))), 3);

            obj.AllDataForCluster = [];
            obj.TrackLocations    = {};
            obj.RedOverTime       = nan(55, 2000);
            obj.FRETOverTime      = nan(55, 2000);
            obj.VelocityOverTime  = nan(55, 2000);
            tempFRET = [];
            pp = 1;

            for i = obj.FirstFrame : round(obj.FramesInBatch/max(obj.Overlap,1)) : obj.LastFrame
                [~, b]   = min(abs(frameVec - i));
                try
                    vecFrame = frameVec(b : b + obj.FramesInBatch - 1);
                catch
                    continue
                end

                mat = MultiObjectTracking(vecFrame, ch, chIdx, obj.ExpPath, ...
                    obj.InvisibleForTooLong, obj.XNoiseKalman, obj.YNoiseKalman, []);

                for idWanted = 1:1500
                    n         = 1;
                    trackLoc  = [];
                    EnergyTP  = [];
                    FrameNum  = [];
                    age       = zeros(1, idWanted);

                    for j = 1:length(mat)
                        getEnergy = vid(:,:,vecFrame(j)) - baseRedProfile;
                        if any([mat{j}.id] == idWanted)
                            wp      = find([mat{j}.id] == idWanted);
                            locMat  = reshape([mat{j}.bbox], 4, []);
                            trackLoc(:,n) = locMat(1:2, wp);
                            ageVec        = [mat{j}.age];
                            age(idWanted) = ageVec(wp);
                            r1 = max(locMat(2,wp)-lookAround,1);
                            r2 = min(locMat(2,wp)+lookAround, size(getEnergy,1));
                            c1 = max(locMat(1,wp)-lookAround,1);
                            c2 = min(locMat(1,wp)+lookAround, size(getEnergy,2));
                            kk = getEnergy(r1:r2, c1:c2);
                            EnergyTP(n) = mean(kk(:));
                            FrameNum(n) = vecFrame(j);
                            n = n + 1;
                        end
                    end

                    % FRET route interpolation
                    trackLocFRET  = [];
                    if length(FrameNum) > 1
                        allFrame     = FrameNum(1):FrameNum(end)+1;
                        FrameNumFRET = setdiff(allFrame, FrameNum);
                        EnergyTPF     = zeros(1,length(FrameNumFRET));
                        trackLocFRET(1,:) = round(interp1(FrameNum, trackLoc(1,:), FrameNumFRET, 'linear', 'extrap'));
                        trackLocFRET(2,:) = round(interp1(FrameNum, trackLoc(2,:), FrameNumFRET, 'linear', 'extrap'));

                        for p = 1:length(FrameNumFRET)
                            getEF = vid(:,:,FrameNumFRET(p)) - baseFRETProfile;
                            r1 = max(trackLocFRET(2,p)-lookAround,1);
                            r2 = min(trackLocFRET(2,p)+lookAround, size(getEF,1));
                            c1 = max(trackLocFRET(1,p)-lookAround,1);
                            c2 = min(trackLocFRET(1,p)+lookAround, size(getEF,2));
                            kkF = getEF(r1:r2, c1:c2);
                            tempFRET(end+1) = mean(kkF(:)); %#ok<AGROW>
                            EnergyTPF(p)    = max(tempFRET);
                            tempFRET        = [];
                        end
                    end

                    % Feature extraction
                    if ~isempty(trackLoc) && age(idWanted) >= obj.MinimalAge
                        whereDidIgo = trackLoc(1,end) - trackLoc(1,1);
                        halfW       = round(size(getEnergy,2)/2);
                        yStdOK      = std(trackLoc(2,:)) < obj.MaxYStd;
                        crossMid    = max(trackLoc(1,:)) >= halfW && min(trackLoc(1,:)) <= halfW;

                        if yStdOK && whereDidIgo > 0 && crossMid
                            obj.RedOverTime(1:length(EnergyTP),  pp) = EnergyTP;
                            obj.FRETOverTime(1:length(EnergyTPF), pp) = EnergyTPF;
                            tempVel = 5.4 * (0.05/obj.FrameTime) .* ...
                                sqrt(diff(trackLoc(1,:)).^2 + diff(trackLoc(2,:)).^2);
                            obj.VelocityOverTime(1:length(tempVel), pp) = tempVel;

                            xSpd    = 5.4*(0.05/obj.FrameTime) * ...
                                sum(sqrt(diff(trackLoc(1,:)).^2+diff(trackLoc(2,:)).^2)) / age(idWanted);
                            frameM  = 0.05 * FrameNum(find(trackLoc(1,:) >= halfW, 1));
                            redE    = prctile(EnergyTP,  50);
                            fretE   = prctile(EnergyTPF, 50);

                            obj.AllDataForCluster(end+1,:) = [xSpd, frameM, redE, fretE];
                            obj.TrackLocations{1,end+1}    = trackLoc;
                            obj.TrackLocations{2,end}      = FrameNum;
                            pp = pp + 1;
                        end
                    end
                end % idWanted
            end % batch loop

            fprintf('Tracking complete. %d valid tracks found.\n', pp-1);
            ShowMyData(obj.AllDataForCluster, [], obj.Bins);
        end

        % ----------------------------------------------------------
        function runPCA(obj, dataIn)
            % PCA on normalised cluster data.
            if nargin < 2, dataIn = obj.AllDataForCluster; end
            dataNorm = obj.normaliseData(dataIn);
            [obj.PCACoeff, obj.PCAScore, ~, ~, obj.PCAExplained] = pca(dataNorm);
            figure;
            scatter(obj.PCAScore(:,1), obj.PCAScore(:,2), '.');
            title('PCA'); xlabel('PCA-1'); ylabel('PCA-2');
        end

        % ----------------------------------------------------------
        function runTSNE(obj, dataIn)
            % t-SNE on normalised cluster data.
            if nargin < 2, dataIn = obj.AllDataForCluster; end
            dataNorm = obj.normaliseData(dataIn);
            Y = tsne(dataNorm);
            figure;
            scatter(Y(:,1), Y(:,2), '.');
            title('t-SNE');
        end

        % ----------------------------------------------------------
        function classifyData(obj,numClusters)
            % GMM classification with BIC/AIC/silhouette evaluation

            if nargin < 2 || isempty(numClusters), numClusters = 2;  end

            dataFilt = obj.AllDataForCluster;
            %dataNorm = obj.normaliseData(dataFilt);
            color    = 'brmcgkw';
            grade    = zeros(5,obj.maxNumClusters);
            options  = statset('Display','off','MaxIter',5000);

            for k = 1:obj.maxNumClusters
                try
                    initialGuess = kmeans(dataFilt(:,2), k);
                    gmmMdl       = fitgmdist(dataFilt, k, 'Options', options, ...
                                            'Start', initialGuess, 'RegularizationValue', 0);
                    clusterGMM   = cluster(gmmMdl, dataFilt);
                    if k == 1, clusterGMM(1) = 2; end

                    grade(1,k) = gmmMdl.BIC;
                    grade(2,k) = gmmMdl.AIC;
                    grade(3,k) = evalclusters(dataFilt, clusterGMM, 'CalinskiHarabasz').CriterionValues;
                    grade(4,k) = evalclusters(dataFilt, clusterGMM, 'DaviesBouldin').CriterionValues;
                    grade(5,k) = evalclusters(dataFilt, clusterGMM, 'silhouette').CriterionValues;

                    if k == numClusters
                        obj.GMMModel     = gmmMdl;
                        obj.FinalCluster = clusterGMM;
                    end

                catch e
                    warning('GMM failed for k=%d: %s', k, e.message);
                end
            end

            % Show results
            ShowMyData(dataFilt, obj.FinalCluster, obj.Bins);

            % PCA scatter coloured by cluster
            obj.runPCA(dataFilt);
            figure;
            gscatter(obj.PCAScore(:,1), obj.PCAScore(:,2), obj.FinalCluster, color(1:numClusters));
            title('Classified - PCA'); xlabel('PCA-1'); ylabel('PCA-2'); legend('');

            fprintf('Classification complete. Best k by Calinski-Harabasz: %d\n', ...
                find(grade(3,:)==max(grade(3,:))));
        end

        % ----------------------------------------------------------
        function runAll(obj)
            % Convenience method: run the full pipeline end-to-end.
            obj.loadFrames();
            obj.setChannelLimits();
            obj.visualizeSampleFrame();
            obj.selectFrames();
            obj.createBackgroundMaps();
            obj.detectParticles();
            obj.plotParticleHistogram();
            obj.plotAverageIntensity();
            obj.trackAndExtractFeatures();
            obj.runPCA();
            obj.runTSNE();
            obj.classifyData();
        end

    end

    %% ----------------------------------------------------------------
    %  Private / Static Helpers
    %  ----------------------------------------------------------------
    methods (Access = private)
        function dataNorm = normaliseData(~, data)
            dataNorm = (data - mean(data)) ./ std(data);
        end
    end

end