%% Initialization
clear *;clear -global *;close all;clc;
global affinity target
init_path;
setPlotColor;
algpar = setPairwiseSolver();
setObsoleteVariables;

target.config.graphMinCnt=20; 
target.config.graphMaxCnt=50; 
target.config.testCnt = 10;% v
target.config.maxNumSearch = 20;
graphStep = 1;
target.config.database = "synthetic"; % "willow", "synthetic"
load_target_data;

% set algorithms
algNameSepSpace = '                    ';
algSet.algNameSet = {'cao_pc_inc', 'cao_pc_raw', 'cao_c_inc','cao_c_raw','imgm_d','imgm_r','tbimgm_cao_c', 'tbimgm_cao_cDFS', 'tbimgm_cao_cBFS'};
algSet.algEnable =  [ 0,            0,             0,           0,          0,       0,       1,                  1,                 1];
algSet.algColor = { cao_pcClr, cao_pc_rawClr, cao_cClr,cao_c_rawClr,imgm_dClr,imgm_rClr, tbimgm_cao_cClr, tbimgm_cao_cDFSClr, tbimgm_cao_cBFSClr};
algSet.algLineStyle = {'--','--','-','--','-','--','-','--', '--', '--'};
algSet.algMarker = {'.','.','.','.','.','.','.','.','.','.'};

[~,cao_pcIdx] = ismember('cao_pc_inc',algSet.algNameSet);
[~,cao_pc_rawIdx] = ismember('cao_pc_raw',algSet.algNameSet);
[~,cao_cIdx] = ismember('cao_c_inc',algSet.algNameSet);
[~,cao_c_rawIdx] = ismember('cao_c_raw',algSet.algNameSet);
[~,imgm_dIdx] = ismember('imgm_d',algSet.algNameSet);
[~,imgm_rIdx] = ismember('imgm_r',algSet.algNameSet);
[~,tbimgm_cao_cIdx] = ismember('tbimgm_cao_c', algSet.algNameSet);
[~,tbimgm_cao_cDFSIdx] = ismember('tbimgm_cao_cDFS', algSet.algNameSet);
[~,tbimgm_cao_cBFSIdx] = ismember('tbimgm_cao_cBFS', algSet.algNameSet);

baseGraphCnt = target.config.graphMinCnt;
target.config.graphRange = baseGraphCnt:graphStep:target.config.graphMaxCnt-graphStep;
target.config.baseGraphCnt = baseGraphCnt;
nInlier = target.config.nInlier;
nOutlier = target.config.nOutlier;
target.config.nodeCnt = nInlier + nOutlier;
target.config.graphCnt = target.config.graphRange(end) + graphStep;
nodeCnt = target.config.nodeCnt;
graphCnt = target.config.graphCnt;


% algorithms for affinity and CAO
target.config.Sacle_2D = 0.05;
target.config.iterRange = 6;
target.config.distRatioTrue = 0.15;
target.config.testType = 'all';% massOutlier
target.config.constStep = 1.05;% the inflate parameter, e.g. 1.05-1.1
target.config.constWeightMax = 1;% the upperbound, always set to 1
target.config.initConstWeight = 0.2; % initial weight for consitency regularizer, suggest 0.2-0.25
target.config.constIterImmune = 2; % in early iterations, not involve consistency, suggest 1-3
target.config.edgeAffinityWeight = 0.9;% in random graphs, only edge affinity is used, angle is meaningless
target.config.angleAffinityWeight = 1 - target.config.edgeAffinityWeight;
target.config.selectNodeMask = 1:1:nInlier+target.config.nOutlier;
target.config.selectGraphMask{1} = 1:target.config.graphMaxCnt;
target.config.connect = 'nfc';

% data for experiment
paraCnt = length(target.config.graphRange);% paraCnt: iterate over graph #
algCnt = length(algSet.algNameSet);% algCnt: iterate over algorithms
testCnt = target.config.testCnt;% testCnt: iterate over tests
timAve = zeros(paraCnt,algCnt,testCnt);timAveFull = zeros(paraCnt,algCnt);
accAve = zeros(paraCnt,algCnt,testCnt);accAveFull = zeros(paraCnt,algCnt);
scrAve = zeros(paraCnt,algCnt,testCnt);scrAveFull = zeros(paraCnt,algCnt);
conPairAve = zeros(paraCnt,algCnt,testCnt);conPairAveFull = zeros(paraCnt,algCnt);
countPairAve = zeros(paraCnt,algCnt,testCnt);countPairAveFull = zeros(paraCnt,algCnt);

acc = cell(1, algCnt);
scr = cell(1, algCnt);
con = cell(1, algCnt);
prevMatching = cell(1, algCnt);
increMatching = cell(1, algCnt);
matTmp = cell(1, algCnt);

fidPerf = fopen('results.csv','w');
fprintf(fidPerf, 'testType,database,category,testCnt,total node#,outlier#,graph#,alg#,scale,initConstWeight,consStep,constWeightMax,iterImmune\n');
fprintf(fidPerf, '%s,      %s,      %s,      %d,     %d,         %d,      %d,    %d,  %f,   %f,             %f,      %.2f,          %d\n',...
    target.config.testType, target.config.database, target.config.category,...
    testCnt,nodeCnt,target.config.nOutlier,graphCnt,sum(algSet.algEnable),target.config.Sacle_2D,...
    target.config.initConstWeight,target.config.constStep,target.config.constWeightMax,target.config.constIterImmune);
fprintf('testType=%s, database=%s, category=%s, test#=%d, node#=%d, outlier#=%d,graph#=%d, alg#=%d, scale=%.2f, initW=%.2f, stepW=%.2f, maxW=%.2f,iterImmune=%d\n',...
    target.config.testType,target.config.database,target.config.category,testCnt,...
    nodeCnt,target.config.nOutlier,graphCnt,sum(algSet.algEnable),target.config.Sacle_2D,...
    target.config.initConstWeight, target.config.constStep,target.config.constWeightMax,target.config.constIterImmune);
fprintf('\n');fprintf(fidPerf,'\n');


for testk = 1:testCnt
    fprintf('Run test in round %d/%d\n', testk, testCnt);
    
    affinity = generateAffinity(testk);
    rawMat = generatePairAssignment(algpar,nodeCnt,graphCnt,testk);
    %debug
    accuracy_raw = cal_pair_graph_accuracy(rawMat, affinity.GT, target.config.nOutlier, nodeCnt, graphCnt);
    accuracy_ave = mean(accuracy_raw(:));
    fprintf("raw accuracy = %f\n", accuracy_ave);
    %debug
    sigma = 0.3;
    % rrwm pairwise match, once for all graph pairs
    switch target.config.inCntType
        case 'exact' % already known, used in Fig.5 and top two rows in Fig.6
            target.config.inCnt = nodeCnt - target.config.nOutlier;
        case 'all' % in case of few outliers, used in Fig.1,2,3,4
            target.config.inCnt = nodeCnt;
        case 'spec' % specified by user, used in the bottom row of Fig.6
            target.config.inCnt = specNodeCnt;
    end

    target.pairwiseMask = cell(1);
	target.pairwiseMask{1} = ones(graphCnt*nodeCnt,graphCnt*nodeCnt);
    scrDenomMatInCnt = cal_pair_graph_inlier_score(rawMat,affinity.GT,nodeCnt,graphCnt,target.config.inCnt);
    scrDenomMatInCntGT = cal_pair_graph_inlier_score(affinity.GT,affinity.GT,nodeCnt,graphCnt,target.config.inCnt);
    
    for parak = 1:paraCnt 

        param.n = nodeCnt; 
        param.N = baseGraphCnt + (parak-1)*graphStep; % 20
        param.graphStep = graphStep;
        scrDenomCurrent = max(max(scrDenomMatInCnt(1:param.N,1:param.N)));
        baseMat = CAO(rawMat(1:nodeCnt*param.N,1:nodeCnt*param.N), nodeCnt, param.N, target.config.iterRange,scrDenomCurrent, 'pair',1);
        % baseMat = rawMat(1:nodeCnt*param.N,1:nodeCnt*param.N);
        %%%%%%%%%%%% calculate the incremental matching with cao_c_raw %%%%%%%%%%%%%%%%%%%%%
        if algSet.algEnable(cao_c_rawIdx)
            tStart = tic;
            increMatching{cao_c_rawIdx} = CAO(rawMat(1:nodeCnt*(param.N+graphStep),1:nodeCnt*(param.N+graphStep)), nodeCnt, param.N+graphStep, target.config.iterRange, scrDenomCurrent, 'exact', 1);
            tEnd = toc(tStart);
            
            acc{cao_c_rawIdx} = cal_pair_graph_accuracy(increMatching{cao_c_rawIdx},affinity.GT,target.config.nOutlier,nodeCnt,param.N+graphStep);
            scr{cao_c_rawIdx} = cal_pair_graph_score(increMatching{cao_c_rawIdx},affinity.GT,nodeCnt,param.N+graphStep);
            %scr{cao_c_rawIdx} = cal_pair_graph_inlier_score(increMatching{cao_c_rawIdx},affinity.GT,nodeCnt,param.N+graphStep, target.config.inCnt);
            con{cao_c_rawIdx} = cal_pair_graph_consistency(increMatching{cao_c_rawIdx},nodeCnt,param.N+graphStep,0);
            accAve(parak, cao_c_rawIdx, testk) = mean(acc{cao_c_rawIdx}(:));
            scrAve(parak, cao_c_rawIdx, testk) = mean(scr{cao_c_rawIdx}(:));
            conPairAve(parak, cao_c_rawIdx, testk) = mean(con{cao_c_rawIdx}(:));
            timAve(parak, cao_c_rawIdx, testk) = tEnd;
            countPairAve(parak, cao_c_rawIdx, testk) = (param.N+graphStep);
        end
        
        %%%%%%%%%%% calculate the incremental matching with cao_c_inc %%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % previous matching: caoPrevMatching
        if algSet.algEnable(cao_cIdx)
            if parak == 1
                prevMatching{cao_cIdx} = baseMat;
            end
            
            matTmp{cao_cIdx} = rawMat(1:nodeCnt*(param.N+graphStep),1:nodeCnt*(param.N+graphStep));
            matTmp{cao_cIdx}(1:nodeCnt*param.N,1:nodeCnt*param.N)=prevMatching{cao_cIdx};
            tStart = tic;
            increMatching{cao_cIdx} = CAO(matTmp{cao_cIdx}, nodeCnt, param.N+graphStep , target.config.iterRange, scrDenomCurrent, 'exact',1);
            tEnd = toc(tStart);
            prevMatching{cao_cIdx} = increMatching{cao_cIdx};

            acc{cao_cIdx} = cal_pair_graph_accuracy(increMatching{cao_cIdx},affinity.GT,target.config.nOutlier,nodeCnt,param.N+graphStep);
            scr{cao_cIdx} = cal_pair_graph_score(increMatching{cao_cIdx},affinity.GT,nodeCnt,param.N+graphStep);
            %scr{cao_cIdx} = cal_pair_graph_inlier_score(increMatching{cao_cIdx},affinity.GT,nodeCnt,param.N+graphStep, target.config.inCnt);
            con{cao_cIdx} = cal_pair_graph_consistency(increMatching{cao_cIdx},nodeCnt,param.N+graphStep,0);
            
            accAve(parak, cao_cIdx, testk) = mean(acc{cao_cIdx}(:));
            scrAve(parak, cao_cIdx, testk) = mean(scr{cao_cIdx}(:));
            conPairAve(parak, cao_cIdx, testk) = mean(con{cao_cIdx}(:));
            timAve(parak, cao_cIdx, testk) = tEnd;
            countPairAve(parak, cao_cIdx, testk) = (param.N+graphStep);
        end

        %%%%%%%%%%% calculate the incremental matching with imgm_d %%%%%%%%%%%%%%%%%%%%%%%
        if algSet.algEnable(imgm_dIdx)
            if parak == 1
                prevMatching{imgm_dIdx} = baseMat;
            end
            matTmp{imgm_dIdx} = rawMat(1:nodeCnt*(param.N+graphStep),1:nodeCnt*(param.N+graphStep));
            matTmp{imgm_dIdx}(1:nodeCnt*param.N,1:nodeCnt*param.N)=prevMatching{imgm_dIdx};
            
            scrDenomMatInCntTmp = cal_pair_graph_inlier_score(matTmp{imgm_dIdx},affinity.GT(1:nodeCnt*(param.N+graphStep),1:nodeCnt*(param.N+graphStep)),nodeCnt,param.N+graphStep,nodeCnt);
            conDenomMatInCntTmp = cal_pair_graph_consistency(matTmp{imgm_dIdx},nodeCnt,param.N+graphStep,0);
            

            simAP = (1-sigma)*scrDenomMatInCntTmp + sigma*conDenomMatInCntTmp;
            % param.subMethodParam.scrDenom = max(max(scrDenomMatInCntTmp(1:param.N,1:param.N)));
            param.iterMax = target.config.iterRange;
            param.visualization = 0;
            param.method = 1; % isDPP = 1; isAP = 2; isRand = 3; isTIP = 4;
            tStart = tic;
            increMatching{imgm_dIdx} = IMGM_old(simAP, matTmp{imgm_dIdx}, param);
            tEnd = toc(tStart);
            prevMatching{imgm_dIdx} = increMatching{imgm_dIdx};
            
            acc{imgm_dIdx} = cal_pair_graph_accuracy(increMatching{imgm_dIdx},affinity.GT,target.config.nOutlier,nodeCnt,param.N+graphStep);
            scr{imgm_dIdx} = cal_pair_graph_score(increMatching{imgm_dIdx},affinity.GT,nodeCnt,param.N+graphStep);
            %scr{imgm_dIdx} = cal_pair_graph_inlier_score(increMatching{imgm_dIdx},affinity.GT,nodeCnt,param.N+graphStep, target.config.inCnt);
            con{imgm_dIdx} = cal_pair_graph_consistency(increMatching{imgm_dIdx},nodeCnt,param.N+graphStep,0);
            
            accAve(parak, imgm_dIdx, testk) = mean(acc{imgm_dIdx}(:));
            scrAve(parak, imgm_dIdx, testk) = mean(scr{imgm_dIdx}(:));
            conPairAve(parak, imgm_dIdx, testk) = mean(con{imgm_dIdx}(:));
            timAve(parak, imgm_dIdx, testk) = tEnd;
            countPairAve(parak, imgm_dIdx, testk) = (param.N+graphStep);
        end

        %%%%%%%%%%% calculate the incremental matching with imgm_r %%%%%%%%%%%%%%%%%%%%%%%        
        if algSet.algEnable(imgm_rIdx)
            if parak == 1
                prevMatching{imgm_rIdx} = baseMat;
            end
            matTmp{imgm_rIdx} = rawMat(1:nodeCnt*(param.N+graphStep),1:nodeCnt*(param.N+graphStep));
            matTmp{imgm_rIdx}(1:nodeCnt*param.N,1:nodeCnt*param.N)=prevMatching{imgm_rIdx};
            
            scrDenomMatInCntTmp = cal_pair_graph_inlier_score(matTmp{imgm_rIdx},affinity.GT(1:nodeCnt*(param.N+graphStep),1:nodeCnt*(param.N+graphStep)),nodeCnt,param.N+graphStep,nodeCnt);
            conDenomMatInCntTmp = cal_pair_graph_consistency(matTmp{imgm_rIdx},nodeCnt,param.N+graphStep,0);
            
            simAP = (1-sigma)*scrDenomMatInCntTmp + sigma*conDenomMatInCntTmp;
            param.subMethodParam.scrDenom = max(max(scrDenomMatInCntTmp(1:param.N,1:param.N)));
            param.iterMax = target.config.iterRange;
            param.visualization = 0;
            param.method = 3; % isDPP = 1; isAP = 2; isRand = 3; isTIP = 4;
            tStart = tic;
            increMatching{imgm_rIdx} = IMGM_old(simAP, matTmp{imgm_rIdx}, param);
            tEnd = toc(tStart);
            prevMatching{imgm_rIdx} = increMatching{imgm_rIdx};
            
            acc{imgm_rIdx} = cal_pair_graph_accuracy(increMatching{imgm_rIdx},affinity.GT,target.config.nOutlier,nodeCnt,param.N+graphStep);
            scr{imgm_rIdx} = cal_pair_graph_score(increMatching{imgm_rIdx},affinity.GT,nodeCnt,param.N+graphStep);
            %scr{imgm_rIdx} = cal_pair_graph_inlier_score(increMatching{imgm_rIdx},affinity.GT,nodeCnt,param.N+graphStep, target.config.inCnt);
            con{imgm_rIdx} = cal_pair_graph_consistency(increMatching{imgm_rIdx},nodeCnt,param.N+graphStep,0);
            
            accAve(parak, imgm_rIdx, testk) = mean(acc{imgm_rIdx}(:));
            scrAve(parak, imgm_rIdx, testk) = mean(scr{imgm_rIdx}(:));
            conPairAve(parak, imgm_rIdx, testk) = mean(con{imgm_rIdx}(:));
            timAve(parak, imgm_rIdx, testk) = tEnd;
            countPairAve(parak, imgm_rIdx, testk) = (param.N+graphStep);
        end

       %%%%%%%%%%%% calculate the incremental matching with tbimgm_cao_c %%%%%%%%%%%%%%%%%%%%
        if algSet.algEnable(tbimgm_cao_cIdx)
            % param for tbimgm_cao_cIdx
            param.subMethodParam.name = 'CAO';
            param.subMethodParam.useCstDecay = 1;
            param.subMethodParam.cstDecay  = 0.7;
            param.subMethodParam.useWeightedDecay  = 0;
            param.subMethodParam.iterMax = target.config.iterRange;
            param.subMethodParam.scrDenom = scrDenomCurrent;
            param.subMethodParam.optType = 'exact';
            param.subMethodParam.useCstInlier = 1;
            param.bVerbose = 0;
            param.maxNumSearch = target.config.maxNumSearch;
            % previous matching: prevMatching{tbimgm_cao_cIdx}
            if parak == 1
                prevMatching{tbimgm_cao_cIdx} = baseMat;
            end
            matTmp{tbimgm_cao_cIdx} = rawMat(1:nodeCnt*(param.N+graphStep),1:nodeCnt*(param.N+graphStep));
            matTmp{tbimgm_cao_cIdx}(1:nodeCnt*param.N,1:nodeCnt*param.N)=prevMatching{tbimgm_cao_cIdx};
            scrDenomMatInCntTmp = cal_pair_graph_inlier_score(matTmp{tbimgm_cao_cIdx},affinity.GT(1:nodeCnt*(param.N+graphStep),1:nodeCnt*(param.N+graphStep)),nodeCnt,param.N+graphStep,nodeCnt);
            conDenomMatInCntTmp = cal_pair_graph_consistency(matTmp{tbimgm_cao_cIdx},nodeCnt,param.N+graphStep,0) - eye(param.N+graphStep, param.N+graphStep);
            
            scrDenomCurrent = max(max(scrDenomMatInCntTmp));
            scrDenomMatInCntTmp = scrDenomMatInCntTmp / scrDenomCurrent;
            
            simAP = (1-sigma)*scrDenomMatInCntTmp + sigma*conDenomMatInCntTmp;
            param.subMethodParam.scrDenom = max(max(scrDenomMatInCntTmp(1:param.N,1:param.N)));

            if param.N < 10
                tStart = tic;
                increMatching{tbimgm_cao_cIdx} = CAO(matTmp{tbimgm_cao_cIdx}, nodeCnt, param.N+graphStep , target.config.iterRange, scrDenomCurrent, 'exact',1);
                tEnd = toc(tStart);
                numPairMatch = 0;
            else
                tStart = tic;
                [increMatching{tbimgm_cao_cIdx}, numPairMatch] = ANC_IMGM(affinity, simAP, matTmp{tbimgm_cao_cIdx}, target, param);
                tEnd = toc(tStart);
            end
            prevMatching{tbimgm_cao_cIdx} = increMatching{tbimgm_cao_cIdx};
            
            acc{tbimgm_cao_cIdx} = cal_pair_graph_accuracy(increMatching{tbimgm_cao_cIdx},affinity.GT,target.config.nOutlier,nodeCnt,param.N+graphStep);
            scr{tbimgm_cao_cIdx} = cal_pair_graph_score(increMatching{tbimgm_cao_cIdx},affinity.GT,nodeCnt,param.N+graphStep);
            % scr{tbimgm_cao_cIdx} = cal_pair_graph_inlier_score(increMatching{tbimgm_cao_cIdx},affinity.GT,nodeCnt,param.N+graphStep, target.config.inCnt);
            con{tbimgm_cao_cIdx} = cal_pair_graph_consistency(increMatching{tbimgm_cao_cIdx},nodeCnt,param.N+graphStep,0);
            
            accAve(parak, tbimgm_cao_cIdx, testk) = mean(acc{tbimgm_cao_cIdx}(:));
            scrAve(parak, tbimgm_cao_cIdx, testk) = mean(scr{tbimgm_cao_cIdx}(:));
            conPairAve(parak, tbimgm_cao_cIdx, testk) = mean(con{tbimgm_cao_cIdx}(:));
            timAve(parak, tbimgm_cao_cIdx, testk) = tEnd;
            countPairAve(parak, tbimgm_cao_cIdx, testk) = numPairMatch;
        end
        
        %%%%%%%%%%%% calculate the incremental matching with tbimgm_cao_cDFS %%%%%%%%%%%%%%%%%%%%
        if algSet.algEnable(tbimgm_cao_cDFSIdx)
            % param for tbimgm_cao_cDFSIdx
            param.subMethodParam.name = 'CAO';
            param.subMethodParam.useCstDecay = 1;
            param.subMethodParam.cstDecay  = 0.7;
            param.subMethodParam.useWeightedDecay  = 0;
            param.subMethodParam.iterMax = target.config.iterRange;
            param.subMethodParam.scrDenom = scrDenomCurrent;
            param.subMethodParam.optType = 'exact';
            param.subMethodParam.useCstInlier = 1;
            param.bVerbose = 0;
            param.maxNumSearch = target.config.maxNumSearch;
            % previous matching: prevMatching{tbimgm_cao_cIdx}
            if parak == 1
                prevMatching{tbimgm_cao_cDFSIdx} = baseMat;
            end
            matTmp{tbimgm_cao_cDFSIdx} = rawMat(1:nodeCnt*(param.N+graphStep),1:nodeCnt*(param.N+graphStep));
            matTmp{tbimgm_cao_cDFSIdx}(1:nodeCnt*param.N,1:nodeCnt*param.N)=prevMatching{tbimgm_cao_cDFSIdx};
            scrDenomMatInCntTmp = cal_pair_graph_inlier_score(matTmp{tbimgm_cao_cDFSIdx},affinity.GT(1:nodeCnt*(param.N+graphStep),1:nodeCnt*(param.N+graphStep)),nodeCnt,param.N+graphStep,nodeCnt);
            conDenomMatInCntTmp = cal_pair_graph_consistency(matTmp{tbimgm_cao_cDFSIdx},nodeCnt,param.N+graphStep,0) - eye(param.N+graphStep, param.N+graphStep);
            
            scrDenomCurrent = max(max(scrDenomMatInCntTmp));
            scrDenomMatInCntTmp = scrDenomMatInCntTmp / scrDenomCurrent;
            
            simAP = (1-sigma)*scrDenomMatInCntTmp + sigma*conDenomMatInCntTmp;
            param.subMethodParam.scrDenom = max(max(scrDenomMatInCntTmp(1:param.N,1:param.N)));

            if param.N < 10
                tStart = tic;
                increMatching{tbimgm_cao_cDFSIdx} = CAO(matTmp{tbimgm_cao_cDFSIdx}, nodeCnt, param.N+graphStep , target.config.iterRange, scrDenomCurrent, 'exact',1);
                tEnd = toc(tStart);
                numPairMatch = 0;
            else
                tStart = tic;
                [increMatching{tbimgm_cao_cDFSIdx}, numPairMatch] = ANC_IMGM_dfs(affinity, simAP, matTmp{tbimgm_cao_cDFSIdx}, target, param);
                tEnd = toc(tStart);
            end
            prevMatching{tbimgm_cao_cDFSIdx} = increMatching{tbimgm_cao_cDFSIdx};
            
            acc{tbimgm_cao_cDFSIdx} = cal_pair_graph_accuracy(increMatching{tbimgm_cao_cDFSIdx},affinity.GT,target.config.nOutlier,nodeCnt,param.N+graphStep);
            scr{tbimgm_cao_cDFSIdx} = cal_pair_graph_score(increMatching{tbimgm_cao_cDFSIdx},affinity.GT,nodeCnt,param.N+graphStep);
            con{tbimgm_cao_cDFSIdx} = cal_pair_graph_consistency(increMatching{tbimgm_cao_cDFSIdx},nodeCnt,param.N+graphStep,0);
            
            accAve(parak, tbimgm_cao_cDFSIdx, testk) = mean(acc{tbimgm_cao_cDFSIdx}(:));
            scrAve(parak, tbimgm_cao_cDFSIdx, testk) = mean(scr{tbimgm_cao_cDFSIdx}(:));
            conPairAve(parak, tbimgm_cao_cDFSIdx, testk) = mean(con{tbimgm_cao_cDFSIdx}(:));
            timAve(parak, tbimgm_cao_cDFSIdx, testk) = tEnd;
            countPairAve(parak, tbimgm_cao_cDFSIdx, testk) = numPairMatch;
        end
        
        %%%%%%%%%%%% calculate the incremental matching with tbimgm_cao_c %%%%%%%%%%%%%%%%%%%%
        if algSet.algEnable(tbimgm_cao_cBFSIdx)
            param.subMethodParam.name = 'CAO';
            param.subMethodParam.useCstDecay = 1;
            param.subMethodParam.cstDecay  = 0.7;
            param.subMethodParam.useWeightedDecay  = 0;
            param.subMethodParam.iterMax = target.config.iterRange;
            param.subMethodParam.scrDenom = scrDenomCurrent;
            param.subMethodParam.optType = 'exact';
            param.subMethodParam.useCstInlier = 1;
            param.bVerbose = 0;
            param.maxNumSearch = target.config.maxNumSearch;
            % previous matching: prevMatching{tbimgm_cao_cIdx}
            if parak == 1
                prevMatching{tbimgm_cao_cBFSIdx} = baseMat;
            end
            matTmp{tbimgm_cao_cBFSIdx} = rawMat(1:nodeCnt*(param.N+graphStep),1:nodeCnt*(param.N+graphStep));
            matTmp{tbimgm_cao_cBFSIdx}(1:nodeCnt*param.N,1:nodeCnt*param.N)=prevMatching{tbimgm_cao_cBFSIdx};
            scrDenomMatInCntTmp = cal_pair_graph_inlier_score(matTmp{tbimgm_cao_cBFSIdx},affinity.GT(1:nodeCnt*(param.N+graphStep),1:nodeCnt*(param.N+graphStep)),nodeCnt,param.N+graphStep,nodeCnt);
            conDenomMatInCntTmp = cal_pair_graph_consistency(matTmp{tbimgm_cao_cBFSIdx},nodeCnt,param.N+graphStep,0) - eye(param.N+graphStep, param.N+graphStep);
            
            scrDenomCurrent = max(max(scrDenomMatInCntTmp));
            scrDenomMatInCntTmp = scrDenomMatInCntTmp / scrDenomCurrent;
            
            simAP = (1-sigma)*scrDenomMatInCntTmp + sigma*conDenomMatInCntTmp;
            param.subMethodParam.scrDenom = max(max(scrDenomMatInCntTmp(1:param.N,1:param.N)));

            if param.N < 10
                tStart = tic;
                increMatching{tbimgm_cao_cBFSIdx} = CAO(matTmp{tbimgm_cao_cBFSIdx}, nodeCnt, param.N+graphStep , target.config.iterRange, scrDenomCurrent, 'exact',1);
                tEnd = toc(tStart);
                numPairMatch = 0;
            else
                tStart = tic;
                [increMatching{tbimgm_cao_cBFSIdx}, numPairMatch] = ANC_IMGM_bfs(affinity, simAP, matTmp{tbimgm_cao_cBFSIdx}, target, param);
                tEnd = toc(tStart);
            end
            prevMatching{tbimgm_cao_cBFSIdx} = increMatching{tbimgm_cao_cBFSIdx};
            
            acc{tbimgm_cao_cBFSIdx} = cal_pair_graph_accuracy(increMatching{tbimgm_cao_cBFSIdx},affinity.GT,target.config.nOutlier,nodeCnt,param.N+graphStep);
            scr{tbimgm_cao_cBFSIdx} = cal_pair_graph_score(increMatching{tbimgm_cao_cBFSIdx},affinity.GT,nodeCnt,param.N+graphStep);
            % scr{tbimgm_cao_cBFSIdx} = cal_pair_graph_inlier_score(increMatching{tbimgm_cao_cBFSIdx},affinity.GT,nodeCnt,param.N+graphStep, target.config.inCnt);
            con{tbimgm_cao_cBFSIdx} = cal_pair_graph_consistency(increMatching{tbimgm_cao_cBFSIdx},nodeCnt,param.N+graphStep,0);
            
            accAve(parak, tbimgm_cao_cBFSIdx, testk) = mean(acc{tbimgm_cao_cBFSIdx}(:));
            scrAve(parak, tbimgm_cao_cBFSIdx, testk) = mean(scr{tbimgm_cao_cBFSIdx}(:));
            conPairAve(parak, tbimgm_cao_cBFSIdx, testk) = mean(con{tbimgm_cao_cBFSIdx}(:));
            timAve(parak, tbimgm_cao_cBFSIdx, testk) = tEnd;
            countPairAve(parak, tbimgm_cao_cBFSIdx, testk) = numPairMatch;
        end
        
        fprintf('test in round %d/%d, Start from %d graphs, %d graphs incremented\n',testk, testCnt, baseGraphCnt, parak*graphStep);
        fprintf('%-18s%-18s%-18s%-18s%-18s%-18s\n','field\alg', 'accuracy', 'score', 'consistency', 'time', 'numPairMatch');
        for alg = find(algSet.algEnable)
            fprintf('%-18s%-18f%-18f%-18f%-18f%-18d\n\n',algSet.algNameSet{alg}, accAve(parak, alg, testk), scrAve(parak, alg, testk), conPairAve(parak, alg, testk), timAve(parak, alg, testk), countPairAve(parak, alg, testk));
        end
    end

end % for paraCnt
    
% rename the algorithm names to be more friendly
for i=1:length(algSet.algNameSet)
    if strcmp(target.config.testType,'massOutlier')
        algSet.algNameSetDisplay{cao_Idx} = 'cao^{cst}';
        algSet.algNameSetDisplay{i} = strrep(algSet.algNameSet{i},'_s','^{sim}');
        algSet.algNameSetDisplay{i} = strrep(algSet.algNameSetDisplay{i},'o_','o-');
        algSet.algNameSetDisplay{i} = strrep(algSet.algNameSetDisplay{i},'c_','c^{cst}');
    else
        algSet.algNameSetDisplay{i} = strrep(algSet.algNameSet{i},'_','-');
        if algSet.algNameSetDisplay{i}(end)=='-'
            algSet.algNameSetDisplay{i}(end) = '*';
        end
    end
end

fprintf('--------------------------------------------------------------overall performance-------------------------------------------------------------------\n');
algNamePreSpace = '                          ';
fprintf(fidPerf,'overall mean\n');
fprintf(algNamePreSpace);
fprintf(fidPerf,',,');
for algk=1:algCnt
    if algSet.algEnable(algk)==0,continue;end
    fprintf([algSet.algNameSetDisplay{algk},algNameSepSpace]);
    fprintf(fidPerf,[algSet.algNameSetDisplay{algk},',,,,']);
end
fprintf('\n');fprintf(fidPerf,'\n');
fprintf('grh# itr#  ');fprintf(fidPerf,'grh#, itr#');
for algk=1:algCnt
    if algSet.algEnable(algk)==0,continue;end
    fprintf(' acc   scr   con   tim   pair');
    fprintf(fidPerf,', acc,  score, consis, time, pairmatch');
end
fprintf('\n');fprintf(fidPerf,'\n');
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %
for parak=1:paraCnt
    viewCnt=target.config.graphMinCnt + parak - 1;
    for algk = 1:algCnt
        timAveFull(parak,algk) = mean(timAve(parak,algk,:));
        accAveFull(parak,algk) = mean(accAve(parak,algk,:));
        scrAveFull(parak,algk) = mean(scrAve(parak,algk,:));
        conPairAveFull(parak,algk) = mean(conPairAve(parak,algk,:));
        countPairAveFull(parak, algk) = mean(countPairAve(parak, algk, :));
    end
    fprintf(' %02d,  %02d ',viewCnt,testCnt);fprintf(fidPerf,' %02d,  %02d',viewCnt,testCnt);
    for algk=1:algCnt
        if algSet.algEnable(algk)==0,continue;end
        fprintf('| %.3f %.3f %.3f %.3f %4d',accAveFull(parak,algk),scrAveFull(parak,algk),conPairAveFull(parak,algk),timAveFull(parak,algk), countPairAveFull(parak, algk));
        fprintf(fidPerf,', %.3f, %.3f, %.3f, %.3f, %4d',accAveFull(parak,algk),scrAveFull(parak,algk),conPairAveFull(parak,algk),timAveFull(parak,algk), countPairAveFull(parak, algk));% fprintf(cc,  score, consis
    end
    fprintf('\n');fprintf(fidPerf,'\n');
end

legendOff = 0;
savePath = sprintf('exp_online_%s_%s.mat', target.config.database, target.config.category);
save(savePath, 'target', 'algSet', 'accAveFull', 'scrAveFull', 'conPairAveFull', 'timAveFull', 'countPairAveFull');
ave.accuracy = accAveFull;
ave.score = scrAveFull;
ave.consistency = conPairAveFull;
ave.time = timAveFull;
ave.matchingNumber = countPairAveFull;
fields = fieldnames(ave);
for ifield = 1:length(fields)
    xtag='Arriving graph';ytag=[fields{ifield}, '(',target.config.category,')'];
    plotResult_new(legendOff,target.config.graphRange-baseGraphCnt+1, getfield(ave,fields{ifield}), algSet, xtag, ytag);
end
