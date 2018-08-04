function cornea = cornea( eye )
% Returns the cornea sub-field of an eye model structure
%
% Syntax:
%  cornea = human.cornea( eye )
%
% Description:
%   The corneal front surface is taken from Table 1 of Navarro 2006:
%
%       Navarro, Rafael, Luis Gonz�lez, and Jos� L. Hern�ndez. "Optics of
%       the average normal cornea from general and canonical
%       representations of its surface topography." JOSA A 23.2 (2006):
%       219-232.
%
%   Their dimensions [a,b,c] correspond to [p2, p3, p1] in the current
%   model. The Navarro model includes a rotation of the corneal axis such
%   that the apex is displaced to the nasal visual field. This is modeled
%   here as well.
%
%   The radius of curvature at the vertex of the cornea was found by
%   Atchison to vary as a function of spherical ametropia (Table 1):
%
%       Atchison, David A. "Optical models for human myopic eyes." Vision
%       research 46.14 (2006): 2236-2250.
%
%   The Navarro parameters are adjusted here to reflect this variation by
%   ametropia.
%
% Inputs:
%   eye                   - Structure.
%
% Outputs:
%   cornea                - Structure.
%


%% Front corneal surface
% Atchison provides parameters for a radially symmetric ellipsoid in terms
% of the radius of curvature (R) at the vertex and its asphericity (Q). R
% varies with spherical ametropia (D):
%
%   R = 7.77 + 0.022 * D
%   Q = -0.15
%
% Because the asphericity of the cornea did not change, the change in R
% corresponds to an overall scaling of the ellipsoid in all dimensions. We
% adjust the Navarro values to account for this effect. R and Q are related
% to the radii of an ellipse along the primary and secondy axes (a, b) by:
%
%   R = b^2/a
%	Q = (b^2 / a^2) - 1
%
% when Q < 0. Therefore, given R and Q, we can obtain a and b, which
% correspond to the radii of the ellipsoid model, with a corresponding to
% the axial dimension, and b to the horizontal and vertical dimensions.
% Checking my algebra here:
%{
    syms a b R Q
    eqn1 = R == b^2/a;
    eqn2 = Q == (b^2 / a^2) - 1;
    solution = solve([eqn1, eqn2]);
    solution.a
    solution.b
%}
% We calculate the change in parameters of the Navarro model that would be
% expected given the Atchison effect for ametropia.
%{
    R = @(D) 7.77 + 0.022 .* D;
    Q = -0.15;
    a = @(D) R(D) ./ (Q+1);
    b = @(D) R(D) .* sqrt(1./(Q+1));
    radiiAtchFront = @(D) [a(D) b(D) b(D)];
    % Show that the ametropia correction scales all radii equally
    radiiAtchFront(0)./radiiAtchFront(1)
    % Calculate the proportion change in radius
    radiusScalerPerD = 1-a(1)/a(0);
    radiiNavFront = [14.26   10.43   10.27];
    radiiNavFrontCorrected = @(D) radiiNavFront.* (D.*radiusScalerPerD+1);
    % Report the ratio of the Atchison and Navarro axial radii
    % for the front surface of the cornea; we use this below.
    atchNavScaler = a(0) ./ radiiNavFront(1)
%}
radii = [14.26   10.43   10.27] .* ...
    ((eye.meta.sphericalAmetropia .* -0.0028)+1);
S = quadric.scale(quadric.unitSphere,radii);

% Rotate the quadric surface towards the nasal field
switch eye.meta.eyeLaterality
    case 'Right'
        S = quadric.rotate(S,[ 0 0 181.5 ]);
    case 'Left'
        S = quadric.rotate(S,[ 0 0 -181.5 ]);
    otherwise
        error('eye laterality not defined')
end

% We set the center of the cornea front surface ellipsoid so that the axial
% apex (prior to rotation) is at position [0, 0, 0]
S = quadric.translate(S,[-radii(1) 0 0]);

% Store these values
cornea.front.S = quadric.matrixToVec(S);
cornea.front.side = 1;
cornea.front.boundingBox=[-4 0 -8 8 -8 8];


%% Back corneal surface
% Atchison finds that the back surface of the cornea does not vary by
% ametropia. Navarro does not provide posterior cornea parameters.
% Therefore, we scale the parameters provided by Atchison to relate to the
% axial corneal radius specified by Navarro:
%{
    R = 6.4;
    Q = -0.275;
    a = R ./ (Q+1);
    b = R .* sqrt(1./(Q+1));
    % Taken from the prior block of code
    atchNavScaler = 0.6410;
    radiiAtchBack = [a b b];
    % Scale the overall back cornea ellipsoid to match Navarro
    radiiNavBack = radiiAtchBack./atchNavScaler;
    % Now scale the relative horizontal and vertical axes so that
    % the relationship between the horizontal (and vertical) radii
    % and the axial radius is of the same proportion to the front
    % surface in the Atchison model
    radiiAtchFront0D = radiiAtchFront(0);
    frontHorizToAxAtch = radiiAtchFront0D(2)/radiiAtchFront0D(1);
    backHorizToAxAtch = b / a;
    radiiNavFront0D = radiiNavFrontCorrected(0);
    frontHorizToAxNav = radiiNavFront0D(2)/radiiNavFront0D(1);
    backHorizToAxNav = radiiNavBack(2)/radiiNavBack(1);
    targetBackHorizToAxNav = backHorizToAxAtch / frontHorizToAxAtch * frontHorizToAxNav;
    radiiNavBackCorrected = [a a*targetBackHorizToAxNav a*targetBackHorizToAxNav]./atchNavScaler
%}
radii = [ 13.7716    9.3027    9.3027];
S = quadric.scale(quadric.unitSphere,radii);

% Rotate the quadric surface towards the nasal field
switch eye.meta.eyeLaterality
    case 'Right'
        S = quadric.rotate(S,[ 0 0 181.5 ]);
    case 'Left'
        S = quadric.rotate(S,[ 0 0 -181.5 ]);
    otherwise
        error('eye laterality not defined')
end

% The center of the back cornea ellipsoid is positioned so that
% there is 0.55 mm of corneal thickness between the front and back
% surface of the cornea at the apex, following Atchison 2006.
S = quadric.translate(S,[-0.55-radii(1) 0 0]);

% Store these values
cornea.back.S = quadric.matrixToVec(S);
cornea.back.side = 1;
cornea.back.boundingBox=[-4 0 -8 8 -8 8];

% Assemble the combined corneal surfaces
cornea.S = [cornea.back.S; cornea.front.S];
cornea.boundingBox = [cornea.back.boundingBox; cornea.front.boundingBox];
cornea.side = [1; 1];
cornea.mustIntersect = [1; 1];
cornea.index = returnRefractiveIndex( 'cornea', eye.meta.spectralDomain );
cornea.label = {'cornea.back'; 'cornea.front'};
cornea.plot.color = {'blue'; 'blue'};

% Code here to calculate the Navarro 1985 corneal parameters that
% were used by Fedtke 2010 in her simulation. These may be used for
% comparison.
%{
    % cornea front
    R = 7.72;
    Q = -0.26;
    a = R ./ (Q+1);
    b = R .* sqrt(1./(Q+1));
    [a b b]
    % cornea back
    R = 6.5;
    Q = 0;
    a = R ./ (Q+1);
    b = R .* sqrt(1./(Q+1));
    [a b b]
    cornea.front.radii = [10.4324    8.9743    8.9743];
    cornea.back.radii = [6.5000    6.5000    6.5000];
%}

end