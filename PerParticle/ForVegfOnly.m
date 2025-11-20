% test data
figure; 
getframe;
x = [77.22, 55.84 , 22.8];
y = [80 , 50 , 20];
error_x = [10, 10, 10];
error_y = [1.84, 2.26, 1.5];
scatter(x,y, 'd', 'filled');
set(gca, 'xlim', [0 100], 'ylim', [0 100]);
hold on;
errorbar(x, y, error_x, error_x, 'linestyle', 'none', 'color', 'k', 'linewidth', .8);
errorbar(x, y, error_y, error_y, 'horizontal', 'linestyle', 'none', 'color', 'k', 'linewidth', .8);

text(x+2,y+5,{'VEGF 165: 80%','VEGF 165: 50%','VEGF 165: 20%'},'FontSize',14);
title('Part of VEGF 165 in Nanochannel Vs in Solution','FontSize',16);
xlabel('Part in Nanochannel [%]');
ylabel('Part in Solution [%]');

figure; 
getframe;
x = 100-x;
y = 100-y;
error_y = [1.84, 2.26, 1.5];
scatter(x,y, 'd', 'filled');
set(gca, 'xlim', [0 100], 'ylim', [0 100]);
hold on;
errorbar(x, y, error_x, error_x, 'linestyle', 'none', 'color', 'k', 'linewidth', .8);
errorbar(x, y, error_y, error_y, 'horizontal', 'linestyle', 'none', 'color', 'k', 'linewidth', .8);

text(x+2,y+5,{'VEGF 121: 20%','VEGF 121: 50%','VEGF 121: 80%'},'FontSize',14);
title('Part of VEGF 121 in Nanochannel Vs in Solution','FontSize',16);
xlabel('Part in Nanochannel [%]');
ylabel('Part in Solution [%]');
