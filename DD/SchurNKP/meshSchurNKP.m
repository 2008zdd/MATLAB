function [lam] = meshSchurNKP(m, z0, quads, curv, prob, F, metric)
% Schur complement of the NKP preconditioner with quadrileteral domains.
% m = Number of gridpoints in one direction per element
% z0 = Mesh vertices
% quads = Mesh quadrangulation
% curv = Radius of curvature at each quadrilateral side
% prob = Problem type 0 = Poisson, 1 = Eigenmodes
% F = Poisson right-hand side
% metric = conformal factor on top of a flat 2D metric

if(nargin<7)
    metric=@(x,y) 1+0*x+0*y;
elseif(nargin<6)
    F=@(x,y) 1+0*x+0*y;
elseif(nargin<5)
    prob=0;
end

% gmres options
tol=1E-15;
maxit=200;
restart=7;

% kept and removed degrees of freedom
kd=2:m-1; 
rd=[1,m];
vec=@(x) x(:);

% Mapped nodes
X=zeros(m,m,size(quads,1));
Y=zeros(m,m,size(quads,1));

% Differential operator
[Dx,x0]=legD(m); 
Dx=Dx(end:-1:1,end:-1:1); 
x0=x0(end:-1:1);
[xx0,yy0]=ndgrid(x0);

% Constraint operator
a=[1,1;1,1];
b=[0,0;0,0];
C1=zeros(2,m); C1(:,rd)=eye(2);
C2=zeros(2,m); C2(:,rd)=eye(2);
C1=diag(a(1,:))*C1+diag(b(1,:))*Dx(rd,:);
C2=diag(a(2,:))*C2+diag(b(2,:))*Dx(rd,:);

% xq fine grid for over-integration
[xq,wq]=gauleg(-1,1,m+32); xq=xq(end:-1:1);
[xxq,yyq]=ndgrid(xq);

% Mesh topology
[corners, adj] = meshtopo(quads);

% Local to global indexing
[GID,nschur]=loc2glob(m,corners,adj);
nquads=size(quads,1);
idof=nquads*(m-2)^2;
tdof=idof+size(adj,1)*(m-2)+max(corners(:));

% Function handles
stiff=cell(nquads,1); % block stiffness
mass =cell(nquads,1); % block mass
nkp  =cell(nquads,1); % block NKP
gf   =cell(nquads,1); % block NKP Green's function

% Construct Schur NKP preconditioner
ischur=zeros(m*m,16,nquads);
jschur=zeros(m*m,16,nquads);
eschur=zeros(m*m,16,nquads);


for j=1:nquads
map=curvedquad(z0(quads(j,:)),curv(j,:));
% Map collocation nodes
zc=map(xx0,yy0);
X(:,:,j)=real(zc);
Y(:,:,j)=imag(zc);
% Map quadtrature nodes
zq=map(xxq,yyq);
uuq=real(zq);
vvq=imag(zq);
% Evaluate Jacobian determinant jac and metric tensor [g11, g12; g12, g22]
[jac,g11,g12,g22] = diffgeom(map,xq,xq);
% Galerkin stiffness and mass (matrix-free) operators, with their NKP
[stiff{j},mass{j},A1,B1,A2,B2]=saldoGalerkin(metric(uuq,vvq),Dx,x0,xq,wq,jac,g11,g12,g22);
% Update NKP Schur complement and compute local Green functions
[is,js,es,nkp{j},gf{j}]=feedSchurNKP(GID(:,:,j),A1,B1,A2,B2,C1,C2);
ischur(:,:,j)=is;
jschur(:,:,j)=js;
eschur(:,:,j)=es;
end
b=(ischur>0)&(jschur>0);
ischur=ischur(b);
jschur=jschur(b);
eschur=eschur(b);

% Schur LU decomposition
S=sparse(ischur,jschur,eschur,nschur,nschur);
[Lschur,Uschur]=lu(S);


function [I,J]=glob2loc(adj)
    s=adj(1);
    q=adj(2);
    if(s>2)
        % Vertical edge
        J=rd(s-2);
        dr=1-2*(GID(1,J,q)>GID(m,J,q));
        I=abs(min(dr,dr*m)):dr:abs(max(dr,dr*m));
        I=I(GID(I,J,q)>0);
    else
        % Horizontal edge
        I=rd(s);
        dr=1-2*(GID(I,1,q)>GID(I,m,q));
        J=abs(min(dr,dr*m)):dr:abs(max(dr,dr*m));
        J=J(GID(I,J,q)>0);
    end
end

function [vv] = fullop(op,uu)
    vv=reshape(uu,m,m,[]);
    for r=1:size(vv,3)
        vv(:,:,r)=op{r}(vv(:,:,r));
    end
    vv=reshape(vv,size(uu));
end

function [u] = precond(rhs)
    RHS=reshape(rhs(1:idof), m-2, m-2, []);
    v=zeros(m,m,size(RHS,3));
    for r=1:size(v,3)
        v(:,:,r)=gf{r}(RHS(:,:,r), 0);
    end
    
    srhs=rhs(1+idof:end);
    for r=1:size(adj,1)
        [I1,J1]=glob2loc(adj(r,1:2));
        [I2,J2]=glob2loc(adj(r,3:4));
        gid=GID(I1,J1,adj(r,2));
        srhs(gid)=srhs(gid)-vec(nkp{adj(r,2)}(v(:,:,adj(r,2)),I1,J1)) + ...
                           -vec(nkp{adj(r,4)}(v(:,:,adj(r,4)),I2,J2));
    end
    
    % Solve for boundary nodes
    ub=Uschur\(Lschur\srhs);
    u=zeros(size(GID));
    u(GID>0)=ub(GID(GID>0));
    
    % Solve for interior nodes with the given BCs
    for r=1:nquads
        u(:,:,r)=gf{r}(RHS(:,:,r), u(:,:,r));
    end
    u=u(:);
end

function [uu] = assembly(u)
    uu=zeros(m,m,nquads);
    uu(kd,kd,:)=reshape(u(1:idof), m-2,m-2,[]);
    ub=u(1+idof:end);
    uu(GID>0)=ub(GID(GID>0));
end

function [u] = Rtransp(uu)
    uu=reshape(uu,m,m,[]);
    ub=zeros(nschur,1);
    for r=1:size(adj,1)
        [I1,J1]=glob2loc(adj(r,1:2));
        [I2,J2]=glob2loc(adj(r,3:4));
        gid=GID(I1,J1,adj(r,2));
        ub(gid)=ub(gid)+vec(uu(I1,J1,adj(r,2)))+vec(uu(I2,J2,adj(r,4)));
    end
    u=[vec(uu(kd,kd,:)); ub];
end

function [u] = pick(uu)
    uu=reshape(uu,m,m,[]);
    ub=zeros(nschur,1);
    for r=1:size(adj,1)
        [I,J]=glob2loc(adj(r,1:2));
        ub(GID(I,J,adj(r,2)))=vec(uu(I,J,adj(r,2)));
    end
    u=[vec(uu(kd,kd,:)); ub];
end

function [u] = afun(u)
    for r=1:size(u,2)
        u(:,r)=Rtransp(fullop(stiff, assembly(u(:,r))));
    end
end

function [u] = bfun(u)
    for r=1:size(u,2)
        u(:,r)=Rtransp(fullop(mass, assembly(u(:,r))));
    end
end

pcalls=0;
function [u] = pfun(u)
    for r=1:size(u,2)
        pcalls=pcalls+1;
        u(:,r)=pick(precond(u(:,r)));
    end    
end

function [uu,flag,relres,iter]=poissonSolver(F,ub)
    if nargin==1
        ub=zeros(size(F));
    end
    rhs=Rtransp(fullop(mass,F)-fullop(stiff,ub));
    uu=pfun(rhs);
    [uu,flag,relres,iter]=gmres(@afun,rhs,restart,tol,ceil(maxit/restart),[],@pfun,uu);
    uu=ub+reshape(assembly(uu),size(ub));  
end

if(prob==0)
    [uu,~,relres,~]=poissonSolver(F(X,Y));
    display(nquads);
    display(relres);
    lam=[];
    % Testing preconditioner
    %uu=reshape(precond(Rtransp(fullop(mass,F(X,Y)))),size(X));
    
    figure(1);
    for j=1:nquads
        surf(X(:,:,j), Y(:,:,j), uu(:,:,j));
        if j==1, hold on; end
    end 
    hold off;
else
    k=prob;
    
    tol=1E-11;
    [U,lam,~,~,relres]=lobpcg(rand(tdof,k),@afun,@bfun,@pfun,[],tol,maxit);
    relres=relres(:,end);
    display(nquads);
    display(relres);
    
    uuu=zeros(m,m,nquads,k);
    for j=1:k
        uuu(:,:,:,j)=assembly(U(:,j));
    end
    uuu=ipermute(uuu,[1,2,4,3]);
    
    figure(1); zoom off; pan off; rotate3d off;
    for j=1:size(uuu,4)
        modegallery(X(:,:,j), Y(:,:,j), real(uuu(:,:,:,j)));
        if j==1, hold on; end
    end
    hold off;    
end

colormap(jet(256));
view(2);
shading interp; camlight;
dx=diff(xlim());
dy=diff(ylim());
pbaspect([dx,dy,min(dx,dy)]);
display(pcalls);
end