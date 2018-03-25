function [stiff,mass,A1,B1,A2,B2] = lapGalerkin(Dx,Dy,x0,y0,xx,yy,wx,wy,jac,g11,g12,g22)
% Stiffness matrix from Laplacian given a metric 
% Assumes oversampled coefficients
% Also returns nearest Kronecker product approximation

m=size(Dx,1);
n=size(Dy,1);

vol=diag(wx)*( jac)*diag(wy);
C11=diag(wx)*( g22./jac)*diag(wy);
C12=diag(wx)*(-g12./jac)*diag(wy);
C22=diag(wx)*( g11./jac)*diag(wy);

E1=legC(x0, xx);
E2=legC(y0, yy);

function vv=stiffFun(uu)
    uu=reshape(uu,[m,n]);
    v11=Dx'*(E1'*(C11.*(E1*(Dx*uu    )*E2'))*E2);
    v12=Dx'*(E1'*(C12.*(E1*(   uu*Dy')*E2'))*E2);
    v21=    (E1'*(C12.*(E1*(Dx*uu    )*E2'))*E2)*Dy;
    v22=    (E1'*(C22.*(E1*(   uu*Dy')*E2'))*E2)*Dy;
    vv=reshape(v11+v12+v21+v22, size(uu));
end
stiff=@stiffFun;

mass=@(uu) reshape(E1'*(vol.*(E1*reshape(uu,[m,n])*E2'))*E2,size(uu));

function B=lowrank(A,r)
    [U0,S0,V0]=svds(A,r);
    B=U0*S0*V0';
end

% This is so crucial, and I don't know why
P11=lowrank(C11,1);
P12=lowrank(C12,1);
P22=lowrank(C22,1);

% Block-to-row permuted operator (Van Loan, 1993)
% Here we use some nifty algebra to optimize the computation
function b=laphat(x, tflag)
    X=reshape(x,floor(sqrt(numel(x))),[]).';
    if strcmp(tflag,'transp')
        v11=Dx'*(E1'*diag(P11*diag(E2*(   X    )*E2'))*E1)*Dx;
        v12=    (E1'*diag(P12*diag(E2*(   X*Dy')*E2'))*E1)*Dx;
        v21=Dx'*(E1'*diag(P12*diag(E2*(Dy*X    )*E2'))*E1);
        v22=    (E1'*diag(P22*diag(E2*(Dy*X*Dy')*E2'))*E1);
        b=reshape(v11+v12+v21+v22,[],1);
    else
        v11=    (E2'*diag(diag(E1*(Dx*X*Dx')*E1').'*P11)*E2);
        v12=Dy'*(E2'*diag(diag(E1*(Dx*X    )*E1').'*P12)*E2);
        v21=    (E2'*diag(diag(E1*(   X*Dx')*E1').'*P12)*E2)*Dy;
        v22=Dy'*(E2'*diag(diag(E1*(   X    )*E1').'*P22)*E2)*Dy;
        b=reshape(v11+v12+v21+v22,[],1);
    end
end

% Nearest Kronecker Product using Lanczos SVD
[B,S,A]=svds(@laphat, [n*n, m*m], 2);
s=sqrt(diag(S));

% This transformation ensures positive-definitiveness (I don't know how) 
A(:,1:2)=A(:,1:2)*diag(s);
B(:,1:2)=B(:,1:2)*diag(s);

A0=A;
B0=B;

Q=[1,1;1,-1];
cond = true;
i=0;
while(cond)
    Q=Q/sqrt(abs(det(Q)));
    A(:,1:2)=A0(:,1:2)*Q;
    B(:,1:2)=B0(:,1:2)/Q';
    A1=reshape(A(:,1),[m,m]);
    B1=reshape(B(:,1),[n,n]);
    A2=reshape(A(:,2),[m,m]);
    B2=reshape(B(:,2),[n,n]);
    DA=[diag(A1), diag(A2)];
    DB=[diag(B1), diag(B2)];
    
    cond = any([DA(:); DB(:)]<=0);
    if(cond && mod(i,2)==0)
        Q=-Q;
    elseif(cond)
        % I hate this, but I am not able to fix it >:(
        Q=2*rand(2)-1; Q=(Q+Q')/2;
    end
    i=i+1;
end
end