function [ initialMatch, simdot ] = descmatch_dot( desc1, desc2, bSelf, distRatio, distThres, kNN, bFullMatch )

% distRatio: Only keep matches in which the ratio of vector angles from the
%   nearest to second nearest neighbor is less than distRatio.
%distRatio = 0.6;   
initialMatch = [];
simdot = [];
%kNN = 50;
if bFullMatch
    np1 = size(desc1, 2);
    np2 = size(desc2, 2);
    simdot = desc2' * desc1; % np2, np1
    simdot = reshape(simdot, 1, np1*np2);
    [X, Y] = meshgrid(1:np1, 1:np2);
    initialMatch = [X(:), Y(:)]';
else
    nMax = min(kNN, size(desc2,2));
    % For each descriptor in the first image, select its match to second image.
    desc1t = desc1';                          % Precompute matrix transpose
    for i = 1:size(desc1,2)
       dotprods = desc1t(i,:) * desc2;        % Computes vector of dot products
       [vals,indx] = sort(dotprods,'descend');
       initialMatch = [ initialMatch [ i*ones(1,nMax); indx(1:nMax) ] ];
       simdot = [ simdot vals(1:nMax) ];
    end
end
