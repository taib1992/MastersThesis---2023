function ShowMyHistograms(AllDataForCluster,Cluster,bins,protName,legnedIn)
figure;
sgtitle([protName,' ','Features Histograms'])
k=1;
NumOfChar=size(AllDataForCluster,2)/2;
maxCluster=max(Cluster);
color=['b','r','c','m','g','k','w'];
for i=1:2*NumOfChar
    subplot(NumOfChar,NumOfChar,k)
    if isempty(Cluster)
        h=histogram(AllDataForCluster(:,i),bins{i});
        h.FaceColor=color(7);
    else
        for p=1:maxCluster
            h=histogram(AllDataForCluster(Cluster==p,i),bins{i});
            h.FaceColor=color(p);
            hold on;
        end
    end
    % only for titles
    
    if i==1
        title('Veolcity Histogram');
        xlabel('Veolcity [um/sec]')
        
    end
    if i==2
        title('Time of Arrival Histogram');
        xlabel('Time of Arrival [sec]');
    end
    if i==3
        title('Red Intensity Hisotgram');
        xlabel('Reltive Intensity');
    end
    if i==4
        title('Green Intensity Hisotgram');
        xlabel('Reltive Intensity');
    end
    ylabel('Counts')
    k=k+1;
end


AllDataForClusterNorm=(AllDataForCluster-mean(AllDataForCluster))./(std(AllDataForCluster));


[coeff,score,latent,tsquared,explained] = pca(AllDataForClusterNorm);
figure;
if isempty(Cluster)
    scatter(score(:,1),score(:,2),200,'.','black');
else
    for p=1:maxCluster
        scatter(score(Cluster==p,1),score(Cluster==p,2),200,'.',color(p));
        hold on;
    end
end
title([protName,' ','PCA']);
xlabel('PCA-1');
ylabel('PCA-2');
if ~isempty(Cluster)
    legend(legnedIn)
end
end
