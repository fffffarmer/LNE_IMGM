load('exp_partition_synthetic_deform.mat');
init_path;
graphRange = target.config.graphRange;
baseGraphCnt = target.config.baseGraphCnt;
ave.accuracy = accAveFull;
ave.score = scrAveFull;
ave.consistency = conPairAveFull;
ave.time = timAveFull;
ave.matchingNumber = countPairAveFull;
legendOff = 0;
fields = fieldnames(ave);
figure(1);
for ifield = 1:length(fields)
    xtag='Arriving graph';ytag=[fields{ifield}];
    plotResult_new(legendOff,graphRange-baseGraphCnt+1, getfield(ave,fields{ifield}), algSet, xtag, ytag);
end