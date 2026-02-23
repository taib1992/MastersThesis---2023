function mat=MultiObjectTracking(VecFrame,channel,GreenOrRed,expe_Path,invisibleForTooLong,XnoiseKalman,YnoiseKalman,KeepMe)
% Create System objects used for reading video, detecting moving objects,
% and displaying the results.
obj = setupSystemObjects();
open(obj.writerObj)
tracks = initializeTracks(); % Create an empty array of tracks.
mat=[];
nextId = 1; % ID of the next track
limy=channel(GreenOrRed).uper_lim:channel(GreenOrRed).low_lim;
limx=channel(GreenOrRed).left_lim:channel(GreenOrRed).right_lim;
m=1;
% Detect moving objects, and track them across video frames.
for k=VecFrame
    %frame = readFrame(obj.reader);
    t=Tiff([expe_Path,'Frame',num2str(k),'.tiff']);
    y=read(t);
    y = mat2gray(y);
    y=y(limy,limx);
    frame = uint8(255 * mat2gray(y));
    [centroids, bboxes, mask] = detectObjects(frame);
    centroids=[channel(GreenOrRed).particle_data{k}.y,channel(GreenOrRed).particle_data{k}.x];
    bboxes=[centroids,channel(GreenOrRed).particle_data{k}.p_size,channel(GreenOrRed).particle_data{k}.p_size];
    predictNewLocationsOfTracks();
    [assignments, unassignedTracks, unassignedDetections] = ...
    detectionToTrackAssignment();
    updateAssignedTracks();
    updateUnassignedTracks();
    deleteLostTracks();
    createNewTracks();
    mat{m}=tracks;
    m=m+1;
    displayTrackingResults(m,KeepMe);
end
close(obj.writerObj);
    function obj = setupSystemObjects()
        % Initialize Video I/O
        % Create objects for reading a video from a file, drawing the tracked
        % objects in each frame, and playing the video.
        
        % Create a video reader.
        obj.reader = VideoReader('atrium.mp4');
        
        % Create two video players, one to display the video,
        % and one to display the foreground mask.
        obj.maskPlayer = vision.VideoPlayer('Position', [740, 400, 700, 400]);
        obj.videoPlayer = vision.VideoPlayer('Position', [20, 400, 700, 400]);
        obj.writerObj = VideoWriter('TrackingVideo','Motion JPEG AVI');
        obj.writerObj.Quality=100;
        obj.writerObj.FrameRate = 10;
        % Create System objects for foreground detection and blob analysis
        
        % The foreground detector is used to segment moving objects from
        % the background. It outputs a binary mask, where the pixel value
        % of 1 corresponds to the foreground and the value of 0 corresponds
        % to the background.
        
        obj.detector = vision.ForegroundDetector('NumGaussians', 3, ...
            'NumTrainingFrames', 10, 'MinimumBackgroundRatio', 0.8);
        
        % Connected groups of foreground pixels are likely to correspond to moving
        % objects.  The blob analysis System object is used to find such groups
        % (called 'blobs' or 'connected components'), and compute their
        % characteristics, such as area, centroid, and the bounding box.
        
        obj.blobAnalyser = vision.BlobAnalysis('BoundingBoxOutputPort', true, ...
            'AreaOutputPort', true, 'CentroidOutputPort', true, ...
            'MinimumBlobArea', 3);
    end
    function tracks = initializeTracks()
        % create an empty array of tracks
        tracks = struct(...
            'id', {}, ...
            'bbox', {}, ...
            'kalmanFilter', {}, ...
            'age', {}, ...
            'totalVisibleCount', {}, ...
            'consecutiveInvisibleCount', {});
    end
    function [centroids, bboxes, mask] = detectObjects(frame)
        
        % Detect foreground.
        mask = obj.detector.step(frame);
        
        % Apply morphological operations to remove noise and fill in holes.
        mask = imopen(mask, strel('rectangle', [2,3]));
        %mask = imclose(mask, strel('rectangle', [15, 15]));
        mask = imfill(mask, 'holes');
        
        % Perform blob analysis to find connected components.
        [~, centroids, bboxes] = obj.blobAnalyser.step(mask);
    end
    function predictNewLocationsOfTracks()
        for i = 1:length(tracks)
            bbox = tracks(i).bbox;
            % Predict the current location of the track.
            predictedCentroid = predict(tracks(i).kalmanFilter);
            
            % Shift the bounding box so that its center is at
            % the predicted location.
            predictedCentroid = int32(predictedCentroid);% - int32(bbox(3:4)) / 2;
            tracks(i).bbox = [predictedCentroid, bbox(3:4)];
        end
    end
    function [assignments, unassignedTracks, unassignedDetections] = ...
            detectionToTrackAssignment()
        
        nTracks = length(tracks);
        nDetections = size(centroids, 1);
        
        % Compute the cost of assigning each detection to each track.
        cost = zeros(nTracks, nDetections);
        for i = 1:nTracks
            cost(i, :) = distance(tracks(i).kalmanFilter, centroids);
        end
        
        % Solve the assignment problem.
        costOfNonAssignment = 20;
        [assignments, unassignedTracks, unassignedDetections] = ...
            assignDetectionsToTracks(cost, costOfNonAssignment);
    end

    function updateAssignedTracks()
        numAssignedTracks = size(assignments, 1);
        for i = 1:numAssignedTracks
            trackIdx = assignments(i, 1);
            detectionIdx = assignments(i, 2);
            centroid = centroids(detectionIdx, :);
            bbox = bboxes(detectionIdx, :);
            
            % Correct the estimate of the object's location
            % using the new detection.
            correct(tracks(trackIdx).kalmanFilter, centroid);
            
            % Replace predicted bounding box with detected
            % bounding box.
            tracks(trackIdx).bbox = bbox;
            
            % Update track's age.
            tracks(trackIdx).age = tracks(trackIdx).age + 1;
            
            % Update visibility.
            tracks(trackIdx).totalVisibleCount = ...
                tracks(trackIdx).totalVisibleCount + 1;
            tracks(trackIdx).consecutiveInvisibleCount = 0;
        end
    end

    function updateUnassignedTracks()
        for i = 1:length(unassignedTracks)
            ind = unassignedTracks(i);
            tracks(ind).age = tracks(ind).age + 1;
            tracks(ind).consecutiveInvisibleCount = ...
                tracks(ind).consecutiveInvisibleCount + 1;
        end
    end
    function deleteLostTracks()
        if isempty(tracks)
            return;
        end
        
        invisibleForTooLong = invisibleForTooLong;
        ageThreshold = 5;
        
        % Compute the fraction of the track's age for which it was visible.
        ages = [tracks(:).age];
        tempi=[tracks(:).bbox];
        locations=tempi(1:4:length(tempi));
        
        totalVisibleCounts = [tracks(:).totalVisibleCount];
        visibility = totalVisibleCounts ./ ages;
        
        % Find the indices of 'lost' tracks.
        lostInds = (ages < ageThreshold & visibility < 0.6) | ...
            [tracks(:).consecutiveInvisibleCount] >= invisibleForTooLong | locations >= size(frame,2)-10;
        
        % Delete lost tracks.
        tracks = tracks(~lostInds);
    end

    function createNewTracks()
        centroids = centroids(unassignedDetections, :);
        bboxes = bboxes(unassignedDetections, :);
        
        for i = 1:size(centroids, 1)
            
            centroid = centroids(i,:);
            bbox = bboxes(i, :);
            
            % Create a Kalman filter object.
            kalmanFilter = configureKalmanFilter('ConstantVelocity', ...
                centroid, [1, 1], [XnoiseKalman,YnoiseKalman], 1);
            
            % Create a new track.
            newTrack = struct(...
                'id', nextId, ...
                'bbox', bbox, ...
                'kalmanFilter', kalmanFilter, ...
                'age', 1, ...
                'totalVisibleCount', 1, ...
                'consecutiveInvisibleCount', 0);
            
            % Add it to the array of tracks.
            tracks(end + 1) = newTrack;
            
            % Increment the next id.
            nextId = nextId + 1;
        end
    end
    function displayTrackingResults(m,KeepMe)
        % Convert the frame and the mask to uint8 RGB.
        frame = im2uint8(frame);
        NoMarks=frame;
        mask = uint8(repmat(mask, [1, 1, 3])) .* 255;
        logVec=[];
        minVisibleCount = 5;
        if ~isempty(tracks)
            
            % Noisy detections tend to result in short-lived tracks.
            % Only display tracks that have been visible for more than
            % a minimum number of frames.
            reliableTrackInds = ...
                [tracks(:).totalVisibleCount] > minVisibleCount;
            reliableTracks = tracks(reliableTrackInds);
            ids = int32([reliableTracks(:).id]);
            if ~isempty(KeepMe)
                    logVec=ismember(ids,KeepMe);
                    ids=ids(ismember(ids,KeepMe));
            end
            % Display the objects. If an object has not been detected
            % in this frame, display its predicted bounding box.
            if ~isempty(ids)
                % Get bounding boxes.
                bboxes = cat(1, reliableTracks.bbox);
                if ~isempty(logVec)
                bboxes = bboxes(logVec,:);
                else
                
                end
                
                % Get ids.
                
                %ids=ids-2; %%%%%
                % Create labels for objects indicating the ones for
                % which we display the predicted rather than the actual
                % location.
                labels = cellstr(int2str(ids'));
                predictedTrackInds = ...
                    [reliableTracks(:).consecutiveInvisibleCount] > 0;
                 if ~isempty(logVec)
                    predictedTrackInds = predictedTrackInds(logVec);
                end
                isPredicted = cell(size(labels));
                isPredicted(predictedTrackInds) = {' P'};
               
                labels = strcat(labels, isPredicted);
                
             
                %Temp{1}=labels{ids==1};
                %Temp{2}=labels{ids==2};
                %Temp{3}=labels{ids==3};

                % Draw the objects on the frame.
                DrawIt=bboxes;%([ids==1|ids==2|ids==3],:);
                DrawIt(:,1:2)=DrawIt(:,1:2)-round(0.5*DrawIt(:,3:4));
                %cc=[round(255/60*ids'),round(255/60*ids'),round(255/60*ids')];
                frame = insertObjectAnnotation(frame,'rectangle',DrawIt,labels);
                
                % Draw the objects on the mask.
                %mask = insertObjectAnnotation(mask, 'rectangle', ...
                %    bboxes, labels);
            end
        end
        
        % Display the mask and the frame.
        %obj.maskPlayer.step(mask);
        pause(0.05)
        obj.videoPlayer.step(imresize(frame(:,:,1),4));
        obj.maskPlayer.step(imresize(NoMarks(:,:,1),4));
        if size(size(frame),2)==3
            NoMarks = uint8(repmat(NoMarks, [1, 1, 3]));
        end
        writeVideo(obj.writerObj, imresize([frame;NoMarks],1));
        %figure; imshow(imresize(frame(:,:,1),5))
        %title(['Time of: ',num2str((m-1)*0.05), 'Seconds'])
   
    end
end