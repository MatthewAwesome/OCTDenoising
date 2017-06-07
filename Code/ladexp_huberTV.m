function [ x ] = ladexp_huberTV( z, par )
%LADEXP_HUBERTV Takes a noisy OCT image outputs an estimate for the latent image
%
%   Inputs:
%
%       z: noisy OCT image (a single B-scan)
%
%       par:
%       par.gamma: weight on the Lagrangian multiplier (default: 2)
%       par.lambda: weight on huber TV regularization (default: 0.5)
%       par.delta: a small constant for linearization (default: 0.002)
%       par.theta: correction parameter (default: 0.98)
%       par.c1: distribution mean coefficient (default: 0.959)
%       par.c2: distribution variance coefficient (default: 0.0804)
%       par.maxIter: maximum number of iterations (default: 30)
%
%   Output:
%
%       x: estimated latent image
%
%-------------------------------------------------------------

%-------------------------------------------------------------
%   Parameter selection
%-------------------------------------------------------------
% default parameters
par0.lambda = 0.5;
par0.gamma = 2;
par0.delta = 0.002;
par0.theta = 0.98;
par0.c1 = 0.959;
par0.c2 = 0.0804;
par0.maxIter = 30;

if exist('par','var')
    if ~isstruct(par)
        error('dualrecons: parameter structure is not a matlab struct');
    end
    % merge default with given values
    params = mergeParam(par0, par);
else
    params = par0;
end

lambda = params.lambda;
gamma = params.gamma;
delta = params.delta; 
theta = params.theta;
c1 = params.c1;
c2 = params.c2;
maxIter = params.maxIter;

if ~isfloat(z)
    z=im2double(z);
end

%-------------------------------------------------------------
%   Initialization
%-------------------------------------------------------------
z(isnan(z)) = 1e-4;
xold = log(z);
xbar = xold;
[m,n] = size(xbar);
yold = zeros(m,2*n);
pold = zeros(m,2*n);

yold(:,1:2*n) = K1(xold);

%-------------------------------------------------------------
%   Linearized ADMM on exponential form with huber TV
%-------------------------------------------------------------

for iter = 1:maxIter
    
    %%% update x
    df =  -1/(2*c2)*z.*exp(-xold) + c1/(2*c2)*sqrt(z).*exp(-xold/2) + 0.5;
    x = xold - delta*( df - gamma*K1_T((yold-K1(xold))) - K1_T(pold)  );
    
    %%% update y
    thresh_huber = 0.02; % based on the range of image values
    range = max(max(K1(x)))-min(min(K1(x)));
    pd = (K1(x) - pold/gamma)/range;
    pdnorm = sqrt( pd(:,1:n).^2 + pd(:,n+1:2*n).^2 );
%     AA = zeros(size(pdnorm));
%     AA(pdnorm-lambda/alpha > pdnorm/(1+lambda/(alpha*thresh_huber))) = 1;
%     figure; imshow(AA);
    y = range* repmat(max(pdnorm-lambda/gamma, pdnorm/(1+lambda/(gamma*thresh_huber))),1,2).*(pd./repmat(max(pdnorm,1e-5),1,2));
%     v = K1(x)-pold/alpha;
%     vnorm = sqrt( v(:,1:n).^2 + v(:,n+1:2*n).^2 );
%     y = repmat(max(vnorm - lambda/alpha, 0)./max(vnorm,1e-6), 1,2) .* v;
    
    %%% update p
    p = pold + gamma*(y - K1(x));
    
    
    %%% correction step
    dx = (1/delta)*(xold-x) - df +  -1/(2*c2)*z.*exp(-x) + c1/(2*c2)*sqrt(z).*exp(-x/2)+0.5;
    dy = gamma*(yold-y) - gamma*K1(xold-x);
    dp = (1/gamma)*(pold-p);
    r = norm(dx,'fro')^2 + norm(dy,'fro')^2 + norm(dp,'fro')^2;
    phi = reshape((pold-p),1,[])*reshape((K1(xold)-yold),[],1) + ...
        reshape((xold-x),1,[])*reshape(dx,[],1) + ...
        reshape((yold-y),1,[])*reshape(dy,[],1);
    beta = theta*phi/r;
    
    x = x-beta*dx;
    y = y-beta*dy;
    p = p-beta*dp;
    
    %%% stopping
    if sum(reshape((x-xold).^2,[],1))/sqrt(numel(x)) <0.0005
       break
    else
        yold = y;
        xold = x;
        pold = p;

    end
    
end

x = exp(x);

end

% compute gradients
function [x] = K1(u)
    x = [u(:,[2:end end])-u, u([2:end end],:,:)-u];
end

% compute negative divergence
function [u] = K1_T(x)
    n = size(x,2)/2;
    u = ( -x(:,1:n) + x(:,[1 1:n-1]) ) + ( -x(:,(n+1):2*n) + x([1 1:end-1],(n+1):2*n) );
end
