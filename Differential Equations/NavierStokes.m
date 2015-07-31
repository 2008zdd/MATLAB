function u=NavierStokes(n)
% Solves for the velocity field assuming periodic boundary conditions.
nu=1.00;
dt=0.01;

% Construct 3D grid
gv=2*pi*(0:n-1)/n;
[xx,yy,zz]=meshgrid(gv);

% Initial velocity field
u=cat(4, -(xx-pi), -(yy-pi), -(zz-pi));

% Initialize spectral differential operators
ii=[0:n/2-1, 0, -n/2+1:-1]';
jj=[0:n/2-1, 0, -n/2+1:-1]';
kk=[0:n/2-1, 0, -n/2+1:-1]';
[i2,j2,k2]=meshgrid(ii.^2, jj.^2, kk.^2);
Dx=1i*ii;
Dy=1i*reshape(jj, [1 n]);
Dz=1i*reshape(kk, [1 1 n]);
D2=-nu*(i2+j2+k2);

figure(1); % Initialize quiver plot
h=quiver3(xx, yy, zz, u(:,:,:,1), u(:,:,:,2), u(:,:,:,3));
axis equal; view(3);

nframes=1000;
for t=1:nframes
    tic
    u=solveRK4(u, dt, Dx, Dy, Dz, D2); 
    title(sprintf('Calculation time %.0f ms', 1000*toc));
    if(mod(t,10)==0)
        set(h, 'UData', u(:,:,:,1));
        set(h, 'VData', u(:,:,:,2));
        set(h, 'WData', u(:,:,:,3));
        drawnow;
    end
end
end

function ut=partialTime(u, Dx, Dy, Dz, D2)
u1=u(:,:,:,1); u2=u(:,:,:,2); u3=u(:,:,:,3);
% Jacobian Tensor: parital derivates on each direction
Jx=ifft(bsxfun(@times, Dx, fft(u, [], 1)), [], 1);
Jy=ifft(bsxfun(@times, Dy, fft(u, [], 2)), [], 2);
Jz=ifft(bsxfun(@times, Dz, fft(u, [], 3)), [], 3);
% Advection
adv=bsxfun(@times, u1, Jx)+bsxfun(@times, u2, Jy)+bsxfun(@times, u3, Jz);
lap=cat(4, ifftn(D2.*fftn(u1)), ifftn(D2.*fftn(u2)), ifftn(D2.*fftn(u3)));
ut=lap-adv;
end

function u=solveRK4(u, dt, Dx, Dy, Dz, D2)
% Time-stepping by classic Runge Kutta (4th order) 
k1=dt*partialTime(u,      Dx, Dy, Dz, D2);
k2=dt*partialTime(u+k1/2, Dx, Dy, Dz, D2);
k3=dt*partialTime(u+k2/2, Dx, Dy, Dz, D2);
k4=dt*partialTime(u+k3,   Dx, Dy, Dz, D2);
u=u+(k1+2*k2+2*k3+k4)/6;
end