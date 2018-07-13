function geodetic = cartToGeodetic( X, radii )
% Converts Cartesian to geodetic coordinates on an ellipsoidal surface
%
% Syntax:
%   geodetic = carToGeodetic( X, radii )
%
% Description:
%   Converts from Cartesian (x, y, z) coordinates on the ellipsoidal
%   surface to geodetic (latitude, longitude, elevation) coordinates.
%
%   The coordinates are with reference to a centered, aligned ellipsoid.
%   The radii must be provided in the "canonical" order returned by
%   quadric.radii(). The x,y,z coordinates returned are with respect to
%   this order [a <= b <= c].
%
%   The operations are taken from a function written by Sebahattin Bektas,
%   (sbektas@omu.edu.tr):
%
%       Bektas, Sebahattin. "Geodetic computations on triaxial ellipsoid."
%       International Journal of Mining Science (IJMS) 1.1 (2015): 25-34.
%
% Inputs:
%   X                     - 3x1 vector containing the [x, y, z] coordinates
%                           of the point.
%   radii                 - 3x1 vector. Semi-axis lengths of the ellipsoid,
%                           provided in canonical size order (a <= b <= c).
%
% Outputs:
%   geodetic              - 3x1 vector that provides the geodetic
%                           coordinates latitude, longitude, and elevation
%                           in units of degrees and Cartesian distance. The
%                           latitude is defined over the range -90:90, and
%                           the longitude over the range -180:180.
%                           Elevation takes a value of zero for a point
%                           that is on the surface of ellipsoid.
%
% Examples:
%{
    %% Confirm the invertibility of the transform
    % Define an ellipsoidal surface
    S = quadric.scale(quadric.unitSphere,[2,4,5]);
    % Find a point on the surface by intersecting a ray
    p = [0;0;0];
    u = [1;tand(15);tand(-15)];
    u = u./sqrt(sum(u.^2));
    R = [p, u];
    X = quadric.intersectRay(S,R);
    geodetic = quadric.cartToGeodetic( X, quadric.radii(S) );
    Xprime = quadric.geodeticToCart( geodetic, quadric.radii(S) );
    assert(max(abs(X-Xprime)) < 1e-6);
%}
%{
    %% Confirm the invertibility of the transform
    % Define an ellipsoidal surface
    S = quadric.scale(quadric.unitSphere,[2,4,5]);
    % Find a point on the surface by intersecting a ray
    p = [0;0;0];
    u = [1;tand(15);tand(15)];
    u = u./sqrt(sum(u.^2));
    R = [p, u];
    X = quadric.intersectRay(S,R);
    for p1=-1:2:1
        for p2=-1:2:1
            for p3=-1:2:1
                quadrant = [p1; p2; p3];
                geodetic = quadric.cartToGeodetic( X.*quadrant, quadric.radii(S) );
                Xprime = quadric.geodeticToCart( geodetic, quadric.radii(S));
                fprintf('X: %d %d %d; geo: %d %d %d; Xp: %d %d %d \n',sign(p1),sign(p2),sign(p3),sign(geodetic(1)),sign(geodetic(2)),sign(geodetic(3)),sign(Xprime(1)),sign(Xprime(2)),sign(Xprime(3)));
            end
        end
    end
%}


% The geodetic is undefined exactly at the umbilical points on the
% ellipsoidal surface. Here, we detect the presence of zeros in the
% cartesian coordinate and shift these to be slightly non-zero
X(abs(X(1:3))==0) = 1e-6;

ro=180/pi; % convert degrees to radians
eps=0.0005; % three sholder

% Distribute the radii to the variables a, b, c. Bektas' original code
% expected the radii in the opposite order. This is why c is mapped to the
% first value in the radii, and why the Cartesian coordinate is assembled
% as [z y x]
c=radii(1);b=radii(2);a=radii(3);
x=X(3);y=X(2);z=X(1);

ex2=(a^2-c^2)/a^2; ee2=(a^2-b^2)/a^2;

E=1/a^2;F=1/b^2;G=1/c^2;

xo=a*x/sqrt(x^2+y^2+z^2);
yo=b*y/sqrt(x^2+y^2+z^2);
zo=c*z/sqrt(x^2+y^2+z^2);

for i=1:20
    j11=F*yo-(yo-y)*E;
    j12=(xo-x)*F-E*xo;
    
    j21=G*zo-(zo-z)*E;
    j23=(xo-x)*G-E*xo;
    
    A=[ j11   j12   0
        j21   0   j23
        2*E*xo    2*F*yo  2*G*zo  ];
    
    sa=(xo-x)*F*yo-(yo-y)*E*xo;
    sb=(xo-x)*G*zo-(zo-z)*E*xo;
    se=E*xo^2+F*yo^2+G*zo^2-1;
    Ab=[ sa  sb  se]';
    bil=-A\Ab;
    xo=xo+bil(1);
    yo=yo+bil(2);
    zo=zo+bil(3);
    
    if max(abs(bil))<eps
        break
    end
end

% Modified the Bektas code to use atan2 and thus make all four quadrants of
% the geodesic coordinates invertible
fi=ro*atan2(zo*(1-ee2)/(1-ex2),sqrt((1-ee2)^2*xo^2+yo^2));
l=ro*atan2(1/(1-ee2)*yo,xo);

h=sign(z-zo)*sign(zo)*sqrt((x-xo)^2+(y-yo)^2+(z-zo)^2);

geodetic=[fi; l; h];
end