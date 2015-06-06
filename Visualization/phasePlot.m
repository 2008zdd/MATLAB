function [] = phasePlot(f, x0, x1, y0, y1, n)
hmap(1:256,1)=linspace(0,1,256); 
hmap(:,[2 3])=1;
colormap(hsv2rgb(hmap));

x=linspace(x0, x1, n);
y=linspace(y0, y1, n);
[re, im]=meshgrid(x, y);
C=(re+1i*im);

z=f(reshape(C,[1,n*n]));
z=reshape(z,[n,n]);

image(angle(z),'CDataMapping','scaled');
xlabel('Re(z)');
ylabel('Im(z)');
caxis([-pi,pi]);
colorbar('YTick', linspace(-pi, pi,5), ...
         'YTickLabel', {'-\pi','-\pi/2','0','\pi/2','\pi'});

ax = gca;
ax.XTick = linspace(0,n,5);
ax.YTick = linspace(0,n,5);
ax.XTickLabel = linspace(x0,x1,5);
ax.YTickLabel = linspace(y1,y0,5);
end