function [] = nbody( n )
% N-body problem simulation

% p is a 3-dimensional array whose pages are the position 
% and velocity vectors for each particle.
p=zeros(3, n, 2);

a=1.0;
b=1.0;

% Initial state
for i=1:n
    th=2*pi*i/n;
    sine=sin(th);
    cosine=cos(th);
    p(:,i,1)=[a*cosine; b*sine; 0];
end
k=interact(p,n);
for i=1:n
    th=2*pi*i/n;
    sine=sin(th);
    cosine=cos(th);  
    
    g=k(:,i,2);
    A=[-a*cosine, -a*sine; -b*sine, b*cosine];
    w2=[1 0]*(A\g(1:2,:));
    p(:,i,2)=sqrt(w2)*[-a*sine; b*cosine; 0];
end

h=0.001;
frames=2000;
plot=scatter3(p(1,:,1), p(2,:,1), p(3,:,1));
for i=1:frames
    % 4th order Classic Runge Kutta
    % p=RungeKutta(@(t,u) interact(u,n), p, 0, step, 1);
    k1=h*interact(p, n);
    k2=h*interact(p+k1/2, n);
    k3=h*interact(p+k2/2, n);
    k4=h*interact(p+k3, n);
    p=p+(k1+2*k2+2*k3+k4)/6;
    
    % Plot
    plot.XData=p(1,:,1);
    plot.YData=p(2,:,1);
    plot.ZData=p(3,:,1);
    drawnow;
end
end

% Gravitational interaction function
function k=interact(p, n)
k=zeros(3, n, 2);
for i=1:n
    g=[0;0;0];
    for j=1:n
        if(i~=j)
            r=p(:,j,1)-p(:,i,1);
            r2=r'*r;
            g=g+r/sqrt(r2*r2*r2);
        end
    end
    k(:,i,1)=p(:,i,2);
    k(:,i,2)=g;
end
end
