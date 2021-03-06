function [] = schrodTiles( m )
% Time-dependent Schrodinger equation with domain decomposition method 
% using Schur complement
n=m;

% Timestep
dt=0.01;

% L-shaped membrane
adjx=[2 1];
adjy=[3 1];

% UIUC block-I
adjx=[3 4; 4 5; 6 7; 7 8; 10 11; 11 12; 12 13];
adjy=[4 2; 2 1; 1 7; 6 9; 9 10; 14 13; 15 14; 16 15; 17 16];

% UIUC block-I
adjx=[3 4; 4 5; 6 7; 7 8];
adjy=[4 2; 2 1; 1 7];

% Topology
[topo,net,RL,TB]=ddtopo(adjx,adjy);
pos=ddpatches(topo);
x0=real(pos);
y0=imag(pos);

% Degrees of freedom
rd1=[1,m];
rd2=[1,n];
kd1=2:m-1;
kd2=2:n-1;

E1=eye(m);
E2=eye(n);

% Differential operators
[Dx,x]=chebD(m);
[Dy,y]=chebD(n);
H1=-1/2*Dx*Dx;
H2=-1/2*Dy*Dy;
A1=1/2*E1-dt/2i*H1;
A2=1/2*E2-dt/2i*H2;

% Constraint operators
C1=E1(rd1,:);
C2=E2(rd2,:);

% Left Propagator Schur complement
[S,~,V1,V2,Q]=ddschur(adjx,adjy,A1,A2,Dx,Dy,C1,C2);
[Lschur, Uschur, bschur]=lu(S,'vector');

figure(2);
imagesc(log(abs(S)));
colormap(gray(256)); colorbar;

% Propagation in a square [-1,1]^2
W1=inv(V1(kd1,kd1));
W2=inv(V2(kd2,kd2));
lhsprop=@(uu) V1(kd1,kd1)*(Q(kd1,kd2).*(W1*uu*W2.'))*V2(kd2,kd2).';

% Right propagator
rhspropfull=@(uu) uu+dt/2i*(H1*uu+uu*H2');

% Poisson solver
function [uuu]=propagate(uuu)
    F=zeros(m-2,n-2,size(uuu,3));
    for j=1:size(uuu,3)
        pp=rhspropfull(uuu(:,:,j));
        F(:,:,j)=pp(kd1,kd2);
    end
    
    v=cell([size(net,1),1]);
    for j=1:size(net,1)
        v{j}=lhsprop(F(:,:,j));
    end
    
    rhs=zeros(m-2, size(RL,1)+size(TB,1));
    for j=1:size(RL,1)
        rhs(:,RL(j,1))=-(Dx(rd1(2),kd1)*v{adjx(j,1)}-Dx(rd1(1),kd1)*v{adjx(j,2)});
    end
    for j=1:size(TB,1)
        rhs(:,TB(j,1))=-(v{adjy(j,1)}*Dy(rd2(2),kd2)'-v{adjy(j,2)}*Dy(rd2(1),kd2)');
    end
    rhs=rhs(:);

    % Solve for boundary nodes
    b=Uschur\(Lschur\rhs(bschur));
    b=reshape(b, m-2, []);
    b=[b, zeros(m-2,1)];
    
    % Solve for interior nodes with the given BCs
    for j=1:size(uuu,3)
        uuu(rd1,kd2,j)=b(:,net(j,1:2)).';
        uuu(kd1,rd2,j)=b(:,net(j,3:4));
        uuu(kd1,kd2,j)=lhsprop(F(:,:,j)-A1(kd1,rd1)*b(:,net(j,1:2)).'-b(:,net(j,3:4))*A2(kd2,rd2).');        
    end
end

[xx,yy]=ndgrid(x,y);
uuu=zeros(m,n,size(net,1));
sig=0.2;
zg=[1i];
ph=@(xx,yy) 2*pi*real(exp(1i)*(xx+1i*yy));

for i=1:size(uuu,3)
    for k=1:size(zg,1)
        uuu(:,:,i)=uuu(:,:,i)+exp(-((xx+x0(i)-real(zg(k))).^2+(yy+y0(i)-imag(zg(k))).^2)/(2*sig^2));
    end
    uuu(:,:,i)=uuu(:,:,i).*exp(1i*ph(xx+x0(i),yy+y0(i)));
    
end

fig1=figure(1);
h=cell(size(uuu,3),1);
for i=1:size(uuu,3)
    h{i}=surf(xx+x0(i), yy+y0(i), real(uuu(:,:,i)));
    if i==1, hold on; end
end
hold off;
colormap(jet(256)); 
shading interp;
view(2);

xl=xlim(); dx=xl(2)-xl(1);
yl=ylim(); dy=yl(2)-yl(1);
pbaspect([dx,dy,min(dx,dy)]);
axis manual; grid off; axis off;
zl=[-1,1]; 
center=true;
set(gcf, 'Position', [100, 100, 720, 920]);


% Create .gif file
filename='schrod.gif';
im=frame2im(getframe(gcf));
[imind,cm]=rgb2ind(im,256);
imwrite(imind,cm,filename,'gif','DelayTime',0,'Loopcount',inf);

function timeEvol(obj,event,time)
    uuu=propagate(uuu);
    vvv=abs(uuu).^2;
    for p=1:size(vvv,3)
        set(h{p}, 'Zdata', vvv(:,:,p));
    end
    umax=max(vvv(:));
    umin=min(vvv(:));
    umid=(umax+umin)/2;
    umax=umax-umid;
    umin=umin-umid;
    r1=0.4; r2=0.95;
    if(umax<r1*(zl(2)-umid))
        zl(2)=umid+umax/r1;
    elseif(umax>r2*(zl(2)-umid))
        zl(2)=umid+umax/r2;
    end
    if(umin>r1*(zl(1)-umid))
        zl(1)=umid+umin/r1;
    elseif(umin<r2*(zl(1)-umid))
        zl(1)=umid+umin/r2;
    end
    if center
        zlim(max(abs(zl))*[-1,1]);
    else
        zlim(zl);
    end
    set(fig1,'Name',sprintf('N = %d, %d fps',numel(uuu),round(1/tmr.InstantPeriod)));
    drawnow;
    
    im=frame2im(getframe(gcf));
    [imind,cm]=rgb2ind(im,256);
    imwrite(imind,cm,filename,'gif','DelayTime',0,'WriteMode','append');
end
fps=20;
tf=10;
nplots=ceil(tf/dt);
tmr=timer('StartDelay', 0, 'Period', round(1/fps,3), 'TasksToExecute', nplots, 'ExecutionMode','fixedRate');
tmr.TimerFcn = @timeEvol;
start(tmr);
end