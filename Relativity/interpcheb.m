function [ uu ] = interpcheb(u,xx,dim)
% Interpolation from Chebyshev nodes to any other grid [-1,1]
if nargin<3
    [~,dim]=max(size(u)>1);
end
xx=xx(:);
n=size(u,dim);
N=2*n-2;
uhat=fftshift(ifft(u,N,dim,'symmetric'),dim);

% Naive calculation
% uhat(1)=uhat(1)/2;
% uu=ChebT(2*uhat(1:n), xx);

% Non-equispaced FFT
m=length(xx);
M=2*m-2;
plan=nfft(1,N,M);
plan.x=acos([xx; -xx(end-1:-1:2)])/(2*pi);
nfft_precompute_psi(plan);

function [uu]=dointerp(uhat)
    plan.fhat=uhat(:);
    nfft_trafo(plan);
    uu=plan.f(1:m);
end

uucell=cellfun(@dointerp, num2cell(uhat, dim), 'UniformOutput', false);
uu=ipermute(cat(ndims(u), uucell{:}), [dim, setdiff(1:ndims(u), dim)]);

if isreal(u)
    uu=real(uu);
end
end