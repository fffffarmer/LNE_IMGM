function affinity = makeGraphMatchingAffinity(parak,target,bfullconnect,bedgesparse)
if length(target)==1%�������ʵ��
    Data = loadRandomData(target,bfullconnect,bedgesparse);%����ʵ��û�е㼯��target����ǲ���
else
    Data = loadTargetData(target,bfullconnect,bedgesparse);%��ʵʵ���е㼯������target�����
end
Sacle_2D = 0.15;
% [KP, KQ, G, H, EG] = calNodeEdgeAffinity(Data, Sacle_2D);
affinity = calNodeEdgeAffinity(Data, Sacle_2D);
% affinity.weight = [1 1 1];
if length(target)==1%����ʵ��
    affinity.asgT{1}.X = eye(target.nInlier(min([parak,length(target.nInlier)]))+target.nOutlier(min([parak,length(target.nOutlier)])));
    affinity.nOutlier = target.nOutlier(min([parak,length(target.nOutlier)]));
else
    affinity.asgT{1}.X = eye(length(target{1}));
    affinity.nOutlier = 0;%��ʵʵ��Ŀǰû��outlier
end
% affinity.asgT{2} = affinity.asgT{1};
% affinity.asgT{3} = affinity.asgT{1};
affinity.adj{1} = Data{1}.adjMatrix;
affinity.adj{2} = Data{2}.adjMatrix;
% affinity.adj{3} = Data{3}.adjMatrix;
%����outlierÿ��ͼ��Ŀһ��

