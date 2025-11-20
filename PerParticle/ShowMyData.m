function ShowMyData(AllDataForCluster,Cluster,bins)
figure;
k=1;
NumOfChar=size(AllDataForCluster,2);
maxCluster=max(Cluster);
color=['b','r','m','c','g','k','w'];
for i=1:NumOfChar
    for j=1:NumOfChar
        subplot(NumOfChar,NumOfChar,k)
        if i==j
            if isempty(Cluster)
                histogram(AllDataForCluster(:,i),bins{i});
            else
                for p=1:maxCluster
                    h=histogram(AllDataForCluster(Cluster==p,i),bins{i});
                    h.FaceColor=color(p);
                    hold on;
                end
            end
        else
            if isempty(Cluster)
                scatter(AllDataForCluster(:,i),AllDataForCluster(:,j),'.')
            else
                for p=1:maxCluster
                    scatter(AllDataForCluster(Cluster==p,i),AllDataForCluster(Cluster==p,j),color(p),'.');
                    hold on;
                end
            end
        end
        % only for titles
        if j==1
            if i==1
                ylabel('Veolcity');
            end
            if i==2
                ylabel('Frame# Appearence');
            end
            if i==3
                ylabel('Red Intensity');
            end
            if i==4
                ylabel('FRET Intensity');
            end
        end
        
        if i==1
            if j==1
                title('Veolcity');
            end
            if j==2
                title('Frame# Appearence');
            end
            if j==3
                title('Red Intensity');
            end
            if j==4
                title('FRET Intensity');
            end
        end
        k=k+1;
    end
end