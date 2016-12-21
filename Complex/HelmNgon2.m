function [lam] = HelmNgon2(n,N,k)
% Helmholtz equation solved on two adjacent, regular n-gons
z0=exp(2i*pi/n*(0:n-1)');
z1=exp(1i*pi/n)*z0-cos(pi/n);
z2=-conj(z1);

p=polygon(z0);
f=diskmap(p);
f=center(f,0);

N(1:2)=N;
[A1,~,B1,r,th]=chebLapPol(N(1), N(2));
B1=B1(2:end,2:end);
[V1,L1]=eig(A1(2:end,2:end),'vector'); W1=inv(V1);
L2=-[0:N(2)/2-1 -N(2)/2:-1].^2;
[L1,L2]=ndgrid(L1,L2); LL=L1+L2;
function [u]=poissonDisk(F)
    u=real(V1*fft((W1*ifft(B1*F,[],2))./LL,[],2));
end

zz=r*exp(1i*th);
J=abs(evaldiff(f,zz(2:end,:))).^2;
function [u]=poissonNgon(F)
    F=reshape(F,size(J));
    u=poissonDisk(J.*F);
    u=u(:);
end

[U,lam]=eigs(@poissonNgon,numel(J),k,'sm');
[lam,id]=sort(diag(lam),'descend');
psi=zeros(N);
psi(2:end,:)=reshape(U(:,id(k)),size(J));

ww=f(zz);
uu=real(ww);
vv=imag(ww);

psi=psi(:,[end,1:end])/max(psi(:));
uu=uu(:,[end,1:end]);
vv=vv(:,[end,1:end]);

figure(1);
surfl(uu,vv,psi,'light');
title(sprintf('\\lambda_{%d} = %.8f', k, lam(k)));
colormap(jet(256)); shading interp;
view(2); axis square manual;
end