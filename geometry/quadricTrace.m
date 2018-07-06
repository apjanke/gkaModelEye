clear opticalSystem
clear intersectionCoords
clear rayPath

opticalSystem(1,:)=[nan(1,10) nan nan(1,6) 1.357];


% %% Back lens surface
S = quadric.unitTwoSheetHyperboloid();
S = quadric.scale(S,[ 1.9667 3.4064 3.4064]);
S = quadric.translate(S,[-7.3-1.9667 0 0]);
boundingBox=[-7.3 -5.14 -4 4 -4 4];
opticalSystem(end+1,:)=[quadric.matrixToVec(S) -1 boundingBox 1.371];

%% Back lens gradient shells
nLensVals = linspace(1.371,1.418,7);
for ii = 2:length(nLensVals)-1
    nBackQuadric = [-0.010073731138546 0 0 0.0; 0 -0.002039930555556 0 0; 0 0 -0.002039930555556 0; 0 0 0 1.418000000000000];
    S = nBackQuadric;
    S(end,end)=S(end,end)-nLensVals(ii);
    S=S./S(end,end);
    S = quadric.translate(S,[-5.14 0 0]);
    boundingBox=[-7.3 -5.14 -4 4 -4 4];
    opticalSystem(end+1,:)=[quadric.matrixToVec(S) 1 boundingBox nLensVals(ii+1)];
end

nLensVals = linspace(1.418,1.371,7);
for ii = 2:length(nLensVals)-1
    nFrontQuadric = [0.022665895061728 0 0 0; 0 0.002039930555556 0 0; 0 0 0.002039930555556 0; 0 0 0 1.371000000000000];
    S = nFrontQuadric;
    S(end,end)=nLensVals(ii)-1.418;
    S = quadric.translate(S,[-5.14-0.065277777777778 0 0]);
    S=S./S(end,end);
    boundingBox=[-5.14 3.7 -4 4 -4 4];
    opticalSystem(end+1,:)=[quadric.matrixToVec(S) 1 boundingBox nLensVals(ii)];
end

%% Front lens surface
S = quadric.unitTwoSheetHyperboloid();
S = quadric.scale(S,[ 1.9133 4.6867 4.6867]);
S = quadric.translate(S,[-3.7+1.9133 0 0]);
boundingBox=[-5.14 -3.7 -4 4 -4 4];
opticalSystem(end+1,:)=[quadric.matrixToVec(S) 1 boundingBox 1.3335];

S = quadric.unitSphere();
S = quadric.scale(S,[ 13.7716  9.3027  9.3027]);
S = quadric.translate(S,[-14.3216 0 0]);
boundingBox=[-4 0 -8 8 -8 8];
opticalSystem(end+1,:)=[quadric.matrixToVec(S) 1 boundingBox 1.3747];

S = quadric.unitSphere();
S = quadric.scale(S,[ 14.2600  10.4300 10.2700    ]);
S = quadric.translate(S,[-14.2600 0 0]);
boundingBox=[-4 0 -8 8 -8 8];
opticalSystem(end+1,:)=[quadric.matrixToVec(S) 1 boundingBox 1.0];


p = [-23.58;0;0];
u = [1;tand(-10);0];
u = u./sqrt(sum(u.^2));
R = [p, u];


surfColors = {'',[0.5 0.5 0.5],[0.5 0.6 0.5],[0.5 0.7 0.5],[0.5 0.8 0.5],[0.5 0.9 0.5],[0.5 1.0 0.5],[0.5 1.0 0.5],[0.5 0.9 0.5],[0.5 0.8 0.5],[0.5 0.7 0.5],[0.5 0.6 0.5],[0.5 0.5 0.5],'blue','blue'};

[outputRay, rayPath] = rayTraceQuadrics(R, opticalSystem);

figure

for ii=2:size(opticalSystem,1)
    % Obtain a function handle for the polynomial
    F = quadric.vecToFunc(opticalSystem(ii,1:10));
    boundingBox = opticalSystem(ii,12:17);
    % Plot the surface
    plotSurface(F,boundingBox,surfColors{ii})
    hold on
        
end

% Plot the ray
rayPath(end+1,:,1) = rayPath(end,:,1)+rayPath(end,:,2)*3;

plot3(rayPath(:,1,1),rayPath(:,2,1),rayPath(:,3,1),'-r');

camlight 
lighting gouraud


function plotSurface(F,boundingBox,surfColor)

[xx, yy, zz]=meshgrid( linspace(boundingBox(1),boundingBox(2),100),...
    linspace(boundingBox(3),boundingBox(4),100),...
    linspace(boundingBox(5),boundingBox(6),100));
    vertices = isosurface(xx, yy, zz, F(xx, yy, zz), 0);

p = patch(vertices);
p.FaceColor = surfColor;
p.EdgeColor = 'none';
alpha(0.1);
daspect([1 1 1])
view(3); 
axis tight
axis equal

end
