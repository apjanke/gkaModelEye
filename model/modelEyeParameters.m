function eye = modelEyeParameters( varargin )
% Return the parameters of a model eye
%
% Syntax:
%  eye = modelEyeParameters()
%
% Description:
%   This routine returns the parameters of a model eye used in the
%   sceneGeometry routines.
%
%   The parameters returned by this routine correspond to the eyeWorld
%   coordinate space used in pupilProjection_fwd, which is relative to the
%   optic / pupil axis, with the apex of the cornea set as zero in depth.
%   The space has the dimensions [depth, horizontal, vertical]; negative
%   values of depth are towards the back of the eye. The model assumes the
%   optical and pupil axis of the eye are algined.
%
% Inputs:
%   none
%
% Optional key/value pairs:
%  'sphericalAmetropia'   - Scalar, in units of diopters. The
%                           dimensions of the posterior chamber of the eye
%                           (and to a lesser extent the curvature of the
%                           cornea) change with the observed refractive
%                           error of the subject. This value is the
%                           spherical refractive correction for the
%                           subject. A negative number is the correction
%                           that would be used for a myopic person.
%  'axialLength'          - Scalar. This is the axial length along the 
%                           optical axis. When set, this fixes the axial
%                           length of the eye to the passed value in
%                           millimeters. As the modeled anterior chamber
%                           depth is not variable, this change is enforced
%                           on the posterior chamber. The remaining
%                           dimensions of the posterior chamber are scaled
%                           to fit the proportions predicted by the
%                           Atchison model for the specified degree of
%                           ametropia.
%  'eyeLaterality'        - A text string that specifies which eye (left,
%                           right) to model. Allowed values (in any case)
%                           are {'left','right','L','R','OS','OD'}
%  'species'              - A text string that specifies the species to be
%                           modeled. Supported values (in any case) are
%                           {'human'}
%  'spectralDomain'       - String, options include {'vis','nir'}.
%                           This is the wavelength domain within which
%                           imaging is being performed. The refractive
%                           indices vary based upon this choice.
%  'visualAxisDegRetina'  - 1x3 vector. This is the position of the fovea 
%                           w.r.t. to optical axis in degrees of retina.
%                           The values are [azimuth, elevation, torsion].
%                           Used in model development.
%  'opticDiscAxisDegRegina'  - 1x3 vector. This is the position of the  
%                           optic disc w.r.t. to optical axis in degrees of
%                           retina. The values are [azimuth, elevation,
%                           torsion]. Used in model development.
%
% Outputs:
%   eye                   - A structure with fields that contain the values
%                           for the model eye.
%
% Examples:
%{
    % Default parameters, corresponding to an emmetropic, right, human eye
    eye = modelEyeParameters();
%}
%{
    % Parameters for an myopic (-3), left, human eye
    eye = modelEyeParameters('sphericalAmetropia',-3,'eyeLaterality','left');
%}


%% input parser
p = inputParser; p.KeepUnmatched = true;

% Optional
p.addParameter('sphericalAmetropia',0,@isscalar);
p.addParameter('axialLength',[],@(x)(isempty(x) || isscalar(x)));
p.addParameter('cornealAxis',[],@(x)(isempty(x) || isnumeric(x)));
p.addParameter('eyeLaterality','Right',@ischar);
p.addParameter('species','Human',@ischar);
p.addParameter('spectralDomain','nir',@ischar);
p.addParameter('visualAxisDegRetina',[],@(x)(isempty(x) || isnumeric(x)));
p.addParameter('opticDiscAxisDegRetina',[],@(x)(isempty(x) || isnumeric(x)));

% parse
p.parse(varargin{:})

% Interpret the passed laterality
switch p.Results.eyeLaterality
    case {'right','RIGHT','Right','R','r','od','OD'}
        eyeLaterality = 'Right';
    case {'left','LEFT','Left','L','l','os','OS'}
        eyeLaterality = 'Left';
    otherwise
        error('Please specify a valid eye laterality for the model eye');
end

% Switch parameters at the top level by species
switch p.Results.species

    %% Human eye
    case {'human','Human','HUMAN'}
                

        %% Cornea
        % We model the cornea as an ellipsoid, taking the "canonical
        % representation" parameters from Table 1 of Navarro 2006:
        %
        %   Navarro, Rafael, Luis Gonz�lez, and Jos� L. Hern�ndez. "Optics
        %   of the average normal cornea from general and canonical
        %   representations of its surface topography." JOSA A 23.2 (2006):
        %   219-232.
        %
        % Their dimensions [a,b,c] correspond to our [p2, p3, p1].
        %
        % The radius of curvature at the vertex of the cornea was found by
        % Atchison to vary as a function of spherical ametropia (Table 1):
        %
        %	Atchison, David A. "Optical models for human myopic eyes."
        %	Vision research 46.14 (2006): 2236-2250.
        %
        % Atchison provides parameters for a radially symmetric ellipsoid
        % in terms of the radius of curvature (R) at the vertex and its
        % asphericity (Q). R varies with spherical ametropia (D):
        %
        %   R = 7.77 + 0.022 * D
        %   Q = -0.15
        % 
        % Because the asphericity of the cornea did not change, the change
        % in R corresponds to an overall scaling of the ellipsoid in all
        % dimensions. We adjust the Navarro values to account for this
        % effect. R and Q are related to the radii of an ellipse along the
        % primary and secondy axes (a, b) by:
        %
        %   R = b^2/a
        %	Q = (b^2 / a^2) - 1
        %
        % when Q < 0. Therefore, given R and Q, we can obtain a and b,
        % which correspond to the radii of the ellipsoid model, with a
        % corresponding to the axial dimension, and b to the horizontal and
        % verical dimensions. Checking my algebra here:
        %{
            syms a b R Q
            eqn1 = R == b^2/a;
            eqn2 = Q == (b^2 / a^2) - 1;
            solution = solve([eqn1, eqn2]);
            solution.a
            solution.b
        %}        
        % We calculate the change in parameters of the Navarro model that
        % would be expected given the Atchison effect for ametropia. 
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
        % Atchison finds that the back surface of cornea does not vary by
        % ametropia. Navarro does not provide posterior cornea parameters.
        % Therefore, we scale the parameters provided by Atchison to relate
        % to the axial corneal radius specified by Navarro:
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
        eye.cornea.front.radii = [14.26   10.43   10.27] .* ...
            ((p.Results.sphericalAmetropia .* -0.0028)+1);
        eye.cornea.back.radii = [ 13.7716    9.3027    9.3027];
        
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
            eye.cornea.front.radii = [10.4324    8.9743    8.9743];
            eye.cornea.back.radii = [6.5000    6.5000    6.5000];
        %}
        
        % We set the center of the cornea front surface ellipsoid so that
        % the axial apex (prior to rotation) is at position [0, 0, 0]
        eye.cornea.front.center = [-eye.cornea.front.radii(1) 0 0];
                
        % The center of the back cornea ellipsoid is positioned so that
        % there is 0.55 mm of corneal thickness between the front and back
        % surface of the cornea at the apex, following Atchison 2006.
        eye.cornea.back.center = [-0.55-eye.cornea.back.radii(1) 0 0];
        
        % Navarro 2006 measured the angle of rotation of the axes of the
        % corneal ellipsoid relative to the keratometric axis, which is the
        % axis that connects a fixation point with the center of curvature
        % of the cornea. We convert those angles here to be relative to the
        % optic axis of the eye. To do so, we first assume that the
        % keratometric axis is equal to the fixation axis. Next, we add the
        % Navarro measurements to the alpha angle values that we have for
        % the model.
        %{
            % Navarro values for the displacement of the corneal axis from
            % keratometric axis for the right eye (in degrees)
            keratometricAxisWRTcornealAxis = [2.35 0.85 0.02];
            % assume that the fixation and keratometric axes are equal
            fixationAxisWRTcornealAxis = [2.35 0.85 0.02];
            % specify our alpha angles
            eye = modelEyeParameters();
            fixationAxisWRTopticalAxis = eye.axes.visual.degField;
            % Now obtain the corneal axes relative to optical axis
            cornealAxisWRTopticalAxis = fixationAxisWRTopticalAxis - fixationAxisWRTcornealAxis            
        %}
        if isempty(p.Results.cornealAxis)
            switch eyeLaterality
                case 'Right'
                    eye.cornea.axis = [3.4460    1.6500   -0.0200];
                case 'Left'
                    eye.cornea.axis = [-3.4460    1.6500   -0.0200];
            end
        else
            eye.cornea.axis = p.Results.cornealAxis;
        end
        
        
        %% Iris
        % The iris has a thickness. This thickness influences the
        % properties of the entrance pupil, as when the eye is rotated
        % w.r.t. the camera either front or back surface of the iris
        % aperture defines the near or far edge of the entrance pupil.
        eye.iris.thickness = 0.15;

        % We position the anterior surface of the iris at the depth of the
        % anterior point of the lens. We model an eye with zero iris angle,
        % thus making the iris a plane. We adjust the position of the iris
        % so that it is centered within the rotated corneal ellipse. This
        % is consistent with reports that the iris is shifted slightly
        % upward with respect to the pupil center, although inconsistent
        % with the report that it is shifted temporally:
        %
        %   ...the typical entrance pupil is decentered
        %   approximately 0.15 mm nasally and 0.1 mm inferior to the
        %   geometric center of the visible iris circumference
        %
        % Bennett, Edward S., and Barry A. Weissman, eds. Clinical contact
        % lens practice. Lippincott Williams & Wilkins, 2005, p119
        switch eyeLaterality
            case 'Right'
                eye.iris.center = [-4+eye.iris.thickness/2 0.35 0.35];
            case 'Left'
                eye.iris.center = [-4+eye.iris.thickness/2 -0.35 0.35];
        end
        
        % Define the iris radius. One study measured the horizontal visible
        % iris diameter (HVID) in 200 people, and found a mean of 11.8 with
        % a range of 10.2 - 13.0.
        %
        %    PJ Caroline & MP Andrew. "The Effect of Corneal Diameter on
        %    Soft Lens Fitting, Part 1" Contact Lens Spectrum, Issue: April
        %    2002
        %    https://www.clspectrum.com/issues/2002/april-2002/contact-lens-case-reports
        %
        % Bernd Bruckner of the company Appenzeller Kontaktlinsen AG
        % supplied me with a tech report from his company (HVID & SimK
        % study) that measured HVID in 461 people. These data yield a mean
        % iris radius of 5.92 mm, 0.28 SD. The values from the histogram
        % are represented here, along with a Gaussian fit to the
        % distribution
        %{
            counts = [0 2 2 0 0 4 5 12 19 23 36 44 52 41 39 37 43 30 28 12 15 10 4 1 0 2 0];
            HVIDRadiusmm = (10.5:0.1:13.1)/2;
            hvidGaussFit = fit(HVIDRadiusmm', counts', 'gauss1');
            hvidRadiusMean = hvidGaussFit.b1;
            hvidRadiusSD =  hvidGaussFit.c1;
            figure
            plot(HVIDRadiusmm, hvidGaussFit(HVIDRadiusmm), '-r')
            hold on
            plot(HVIDRadiusmm, counts, '*k')
            xlabel('HVID radius in mm')
            ylabel('counts')
        %}
        % The HVID is the refracted iris size. We can use the forward model
        % to find the size of the true iris.
        %{
            sceneGeometry = createSceneGeometry();
            sceneGeometry.refraction = [];
            % Get the area in pixels of a "pupil" that is the same radius
            % as the HVID when there is no ray tracing
            hvidP=pupilProjection_fwd([0 0 0 hvidRadiusMean],sceneGeometry);
            % Restore ray tracing
            sceneGeometry = createSceneGeometry();
            % Set up the objective function
            myArea = @(p) p(3);
            myObj = @(r) (hvidP(3) - myArea(pupilProjection_fwd([0 0 0 r],sceneGeometry)))^2;
            [r,pixelError] = fminsearch(myObj,5.5);
            fprintf('An unrefracted iris radius of %4.2f yields a refracted HVID of %4.2f \n',r,hvidRadiusMean)
        %}
        % We use this true iris size and then subject the iris perimeter
        % points to refraction
        eye.iris.radius = 5.57;

        
        %% Pupil
        % The pupil is an aperture in the iris, centered on the optical
        % axis
        eye.pupil.center = [eye.iris.center(1) 0 0];
        
        % The actual pupil of the eye is elliptical. Further, the
        % eccentricity and theta of the entrance pupil ellipse changes with
        % pupil dilation:
        %
        %   Wyatt, Harry J. "The form of the human pupil." Vision Research
        %   35.14 (1995): 2021-2036.
        %
        % Wyatt reported the average ellipse parameters for the entrance
        % pupil (with the visual axis aligned with camera axis) under dim
        % and bright light conditions. We calculate the corresponding
        % parameters of the actual pupil on the optical axis. We then fit a
        % hyperbolic tangent (sigmoidal) function to the the eccentricity
        % of the actual pupil as a function of the actual pupil radius. The
        % theta values observed by Wyatt were close to vertically
        % orientated in the dark, and horizontally oriented in the light.
        % We find that a slight tilt away from vertical for the dilated
        % pupil allows our model to fit the Mathur 2013 obliquity component
        % perfectly. When the actual pupil eccentricity is below zero, the
        % theta is set to zero (horizontal), and above zero value it is set
        % to ~pi/2 (vertical). In the forward model, we take the absolute
        % value of the eccentricity returned by the parameters for the
        % actual pupil eccentrivity.
        %{
            % Observed entrance pupil diameters reported in Wyatt 1995.
            entranceRadius = [3.09/2 4.93/2];
            % Wyatt reported an eccentricity of the pupil of 0.21 under
            % dark conditions. We find that using that value produces
            % model results that disagree with Malthur 2013. We have
            % adopted an upper value of 0.18 instead. We also use the 
            % convention of a negative eccentricity for a horizontal major
            % axis and a positive eccentricity for vertical.
            entranceEccen = [-0.12 0.18];
            % Prepare scene geometry and eye pose aligned with visual axis
            sceneGeometry = createSceneGeometry();
            % Fix the actual pupil eccentricity at 0
            sceneGeometry.eye.pupil.eccenFcnString = '@(x) 0';
            sceneGeometry.eye.pupil.thetas = [0, 0];
            % Obtain the pupil area in the image for each entrance radius
            % assuming no ray tracing
            sceneGeometry.refraction = [];
            pupilImage = pupilProjection_fwd([-sceneGeometry.eye.axes.visual.degField(1), -sceneGeometry.eye.axes.visual.degField(2), 0, entranceRadius(1)],sceneGeometry);
            actualArea(1) = pupilImage(3);
            pupilImage = pupilProjection_fwd([-sceneGeometry.eye.axes.visual.degField(1), -sceneGeometry.eye.axes.visual.degField(2), 0, entranceRadius(2)],sceneGeometry);
            actualArea(2) = pupilImage(3);
            % Add the ray tracing function to the sceneGeometry
            sceneGeometry = createSceneGeometry();
            % Search across actual pupil radii to find the values that match
            % the observed entrance areas.
            myPupilEllipse = @(radius) pupilProjection_fwd([-sceneGeometry.eye.axes.visual.degField(1), -sceneGeometry.eye.axes.visual.degField(2), 0, radius],sceneGeometry);
            myArea = @(ellipseParams) ellipseParams(3);
            myObj = @(radius) (myArea(myPupilEllipse(radius))-actualArea(1)).^2;
            actualRadius(1) = fminunc(myObj, entranceRadius(1));
            myObj = @(radius) (myArea(myPupilEllipse(radius))-actualArea(2)).^2;
            actualRadius(2) = fminunc(myObj, entranceRadius(2));
            % Now find the actual pupil eccentricity that produces the
            % observed entrance pupil eccentricity
            place = {'eye' 'pupil' 'eccenFcnString'};
            sceneGeometry.eye.pupil.thetas = [0, 0];
            mySceneGeom = @(eccen) setfield(sceneGeometry,place{:},['@(x) ' num2str(eccen)]);
            myPupilEllipse = @(eccen) pupilProjection_fwd([-sceneGeometry.eye.axes.visual.degField(1), -sceneGeometry.eye.axes.visual.degField(2), 0, actualRadius(1)],mySceneGeom(eccen));
            myEccen = @(ellipseParams) ellipseParams(4);
            myObj = @(eccen) 1e4*(myEccen(myPupilEllipse(eccen))-abs(entranceEccen(1))).^2;
            actualEccen(1) = -fminsearch(myObj, 0.1);
            sceneGeometry.eye.pupil.thetas = [pi/2, pi/2];
            mySceneGeom = @(eccen) setfield(sceneGeometry,place{:},['@(x) ' num2str(eccen)]);
            myPupilEllipse = @(eccen) pupilProjection_fwd([-sceneGeometry.eye.axes.visual.degField(1), -sceneGeometry.eye.axes.visual.degField(2), 0, actualRadius(2)],mySceneGeom(eccen));
            myEccen = @(ellipseParams) ellipseParams(4);
            myObj = @(eccen) 1e4*(myEccen(myPupilEllipse(eccen))-abs(entranceEccen(2))).^2;
            actualEccen(2) = fminsearch(myObj, 0.2);        
            % We then interpolate the observed values, assuming that the
            % observed values are close to asymptote
            actualRadiusInterp = [actualRadius(1)-.5 actualRadius(1) mean(actualRadius) actualRadius(2) actualRadius(2)+.5];
            actualEccenInterp = [actualEccen(1)/0.96 actualEccen(1) mean(actualEccen) actualEccen(2) actualEccen(2)/0.96];
            % Fit a hand-tuned sigmoidal function
            sigFit = @(scaleX, shiftY, scaleY, x) (tanh((x-mean(actualRadius)).*scaleX)+shiftY)*scaleY;
            fitEccen = fit(actualRadiusInterp',actualEccenInterp',sigFit);
            fprintf('eye.pupil.eccenParams = [-%4.3f %4.3f %4.3f %4.3f];\n',mean(actualRadius),fitEccen.scaleX,fitEccen.shiftY,fitEccen.scaleY);
            % Plot the fit
            figure
            plot(actualRadiusInterp,actualEccenInterp,'kx');
            hold on
            plot(0.5:.1:3,fitEccen(0.5:.1:3),'-r');        
        %}
        % Specify the params and equation that defines the actual pupil
        % ellipse. This can be invoked as a function using str2func.
        eye.pupil.eccenParams = [-1.749 -4.770 0.099 -0.145]; 
        eye.pupil.eccenFcnString = sprintf('@(x) (tanh((x+%f).*%f)+%f)*%f',eye.pupil.eccenParams(1),eye.pupil.eccenParams(2),eye.pupil.eccenParams(3),eye.pupil.eccenParams(4)); 

        % The theta values of the actual pupil ellipse for eccentricities
        % less than, and greater than, zero.
        switch eyeLaterality
            case 'Right'
                eye.pupil.thetas = [0  3/7*pi];
            case 'Left'
                eye.pupil.thetas = [0  4/7*pi];
        end
        
        
        %% Posterior chamber
        % Atchison 2006 provides radii of curvature and asphericities for a
        % biconic model of the posterior chamber, with these values varying
        % by spherical ametropia. Parameters for the the decentration and
        % tilt of the posterior chamber are also provided:
        %
        %	Atchison, David A., et al. "Shape of the retinal surface in
        %   emmetropia and myopia." Investigative ophthalmology & visual
        %   science 46.8 (2005): 2698-2707.
        %
        % I model the posterior chamber as a centered ellipsoid. I convert
        % the 4 parameeters of the Atchison biconic model to a 3 radii of
        % an ellipsoid by numeric approximation. To match Atchison's axial
        % length formula (Eq 19), I had to inflate the effect of spherical
        % ametropia upon the asphericity coefficients very sligtly.
        % Atchison gives the values:
        %
        %   Qx = 0.27+0.026*SR
        %   Qy = 0.25+0.017*SR
        %
        % and I increased the effects of SR to be 0.0272 and 0.0182 upon Qx
        % and Qy, respectively. I suspect this adjustment is the result of
        % a small, systematic underestimation of the ellipsoid radii by my
        % numeric approximation.
        %   
        %{
            % Numeric approximation of Atchison 2006 biconic model of 
            % posterior chamber with ellipsoid radii
            radii = [];
            for SR = -2:2
            Cx = 1/(12.91+0.094*SR);
            Cy = 1/(12.72-0.004*SR);
            Qx = 0.27+0.0272*SR;
            Qy = 0.25+0.0182*SR;
            biconicZ = @(x,y) (Cx.*x.^2 + Cy.*y.^2)./(1+sqrt( 1-(1+Qx).* Cx.^2.*x.^2 - (1+Qy).*Cy.^2.*y.^2));
            myObj = @(p) -biconicZ(p,0);
            [radiusX] = fminsearch(myObj,10);
            myObj = @(p) -biconicZ(0,p);
            [radiusY] = fminsearch(myObj,10);
            radiusZ = max([biconicZ(radiusX,0) biconicZ(0,radiusY)]);
            radii = [radii; [radiusZ, radiusX, radiusY]];
            end
            slopes = mean(diff(radii));
            fprintf('axial radius = %4.4f %4.4f * SR\n',radii(3,1),slopes(1));
            fprintf('horizontal radius = %4.4f %4.4f * SR \n',radii(3,2),slopes(2));
            fprintf('vertical radius = %4.4f %4.4f * SR \n',radii(3,3),slopes(3));
        %}
        postChamberRadiiEmetrope = [10.1760 11.4558 11.3771];
        postChamberRadiiAmetropiaSlope = [-0.1495 -0.0393 -0.0864];
        eye.posteriorChamber.radii = ...
            postChamberRadiiEmetrope + postChamberRadiiAmetropiaSlope.* p.Results.sphericalAmetropia;

        % Our model holds the depth of the anterior chamber constant.
        % Atchison found that anterior chamber depth does not vary with
        % spherical ametropia, although this is not a consistent finding:
        %
        %   Hosny, Mohamed, et al. "Relationship between anterior chamber
        %   depth, refractive state, corneal diameter, and axial length."
        %   Journal of Refractive Surgery 16.3 (2000): 336-340.
        %
        % To position the posterior chamber, we need to know the distance
        % between the apex of the anterior chamber and the apex of the
        % posterior chamber. I derive the value for this distance from the
        % Atchison 2006 model eye.
        posteriorChamberApexDepth = 23.5800 - postChamberRadiiEmetrope(1)*2;

        % Compute and store axial length
        if isempty(p.Results.axialLength)
            eye.axialLength = posteriorChamberApexDepth + eye.posteriorChamber.radii(1)*2;
        else
            % If a specific axial length was passed (perhaps obtained by
            % measurement using the IOL Master apparatus), set the model
            % eye to have this length, and scale the other dimensions of
            % the posterior chamber to maintain the specified ametropia. We
            % adjust the axial length for the component of the anterior
            % chamber that contibutes to length (posteriorChamberApexDepth)
            scaleFactor = (p.Results.axialLength - posteriorChamberApexDepth) / (eye.posteriorChamber.radii(1)*2);
            eye.posteriorChamber.radii = eye.posteriorChamber.radii .* scaleFactor;
            eye.axialLength = p.Results.axialLength;
        end

        % Set the depth of the center of the posterior chamber
        eye.posteriorChamber.center = ...
            [(-posteriorChamberApexDepth - eye.posteriorChamber.radii(1)) 0 0];

        
        %% Lens
        % Although the lens does not influence the pupil tracking, we
        % include it here to support an illustration of a complete eye
        % model. The front and back surfaces of the lens are modeled as
        % hyperbolas. This simplified model does not model the gradient in
        % refractive index across the extent of the lens, and therefore
        % does not support ray tracing. All values taken from Atchison
        % 2006.
        % To convert R and Q to radii of a hyperbola:
        %   R = b^2/a
        %	Q = (a^2 / b^2) + 1
        % Therefore, given R and Q, we can obtain a and b, which correspond
        % to the radii of the ellipsoid model, with a corresponding to the
        % axial dimension, and b to the horizontal and verical dimensions.
        % Checking my algebra here:
        %{
            syms a b R Q
            eqn1 = R == a^2/b;
            eqn2 = Q == (a^2 / b^2) + 1;
            solution = solve([eqn1, eqn2]);
            solution.a
            solution.b
        %}
        eye.lens.front.R = 11.48;
        eye.lens.front.Q = -5;
        a = eye.lens.front.R * sqrt(abs( 1 / (eye.lens.front.Q - 1 ) )) * sign(eye.lens.front.Q);
        b = eye.lens.front.R / (eye.lens.front.Q - 1 );
        eye.lens.front.radii(1) = b;
        eye.lens.front.radii(2:3) = a;
        eye.lens.front.center = [eye.pupil.center(1)-eye.lens.front.radii(1) 0 0];
        
        eye.lens.back.R = -5.9;
        eye.lens.back.Q = -2;
        a = eye.lens.back.R * sqrt(abs( 1 / (eye.lens.back.Q - 1 ) )) * sign(eye.lens.back.Q);
        b = eye.lens.back.R / (eye.lens.back.Q - 1 );
        eye.lens.back.radii(1) = b;
        eye.lens.back.radii(2:3) = a;
        eye.lens.back.center = [eye.pupil.center(1)-3.6-eye.lens.back.radii(1) 0 0];
        
        % I specify the location of a single nodal point to support
        % calculation of the visual axis. The nodal point is placed at a
        % depth of 7.2 mm, which is mid point of the nodal points specified
        % in the Gullstrand-Emsley simplified schematic eye
        eye.lens.nodalPoint = [-7.2 0 0];
        
        
        %% Axes - optical
        % Eye axes are specified as rotations (in degrees) within the eye
        % world coordinate frame for azimuth, elevation, and rotation. Axes
        % are defined relative to the optical axis, which itself is set to
        % be aligned with the p1 dimension of the eye world coordinate
        % frame.
        eye.axes.optical.degRetina = [0 0 0];
        eye.axes.optical.mmRetina = [0 0 0];
        eye.axes.optical.degField = [0 0 0];


        %% Axes - visual and blind spot
        % The model establishes the position of the fovea and then sets the
        % optic disc at a constant distance from the fovea in units of
        % retinal degrees. The lines that connect these points on the fovea
        % to the posterior nodal point of the eye define the visual and
        % blind spot axes, respectively. The difference between these gives
        % the position of the blind spot relative to fixation.
        %
        % Find the azimuthal arc in retina deg that produces a blind spot
        % position in the horizontal and vertical directions that is equal
        % to specified values from the literature. Values taken from Safren
        % 1993 for their dim stimulus, under the assumption that this will
        % be most accurate given the minimization of light scatter. We
        % model the fovea as being 3x closer to the optical axis than is
        % the optic disc.
        %{
            % Position of the blind spot in degrees of visual field
            % relative to fixation 
            targetBlindSpotAngle = [-16.02 -1.84 0];
            blindSpotAngle = @(eye) eye.axes.opticDisc.degField - eye.axes.visual.degField;
            myObj = @(x) sum((blindSpotAngle(modelEyeParameters('opticDiscAxisDegRetina',[3/4*x(1),x(2)/2,0],'visualAxisDegRetina',-[1/4*x(1),x(2)/2,0])) - targetBlindSpotAngle).^2);
            options = optimoptions('fmincon','Display','off');
            retinalArcDeg = fmincon(myObj,[20 4],[],[],[],[],[],[],[],options);
            fprintf('Distance between the fovea and the center of the optic disc in retinal degrees in the right eye:\n');
            fprintf('\tazimuth = %4.4f; elevation = %4.4f \n\n', retinalArcDeg([1 2]));
        %}
        switch eyeLaterality
            case 'Right'
                opticDisc_WRT_foveaDegRetina = [-22.9384, 2.6078 ,0];
            case 'Left'
                opticDisc_WRT_foveaDegRetina = [22.9384, 2.6078 ,0];
        end        
        
        % We next require the position of the fovea with respect to the
        % optic axis in the emmetropic eye. We identify the position (in
        % retinal degrees) of the fovea that results in a visual axis that
        % has resulting alpha angles that match empirical results.  We
        % assume an azimuth alpha of 5.8 degrees for an emmetropic eye
        % (Figure 8 of Mathur 2013). We assume an elevation alpha of 2.5
        % degrees, as this value, when adjusted to account for the longer
        % axial length of the subjects in the Mathur study, best fits the
        % Mathur data. Given these angles, we then calculate the
        % corresponding position of the fovea w.r.t. the the optical axis
        % of the eye (adjusted for eye laterality).
        %{
            eye = modelEyeParameters();
            % These are the visual axis angles for an emmetropic eye
            targetAlphaAngle = [5.8  2.5  0];
            myComputedAlphaAzi = @(eye) eye.axes.visual.degField(1);
            myObj = @(x) (targetAlphaAngle(1) - myComputedAlphaAzi(modelEyeParameters('visualAxisDegRetina',[x 0 0])))^2;
            aziFoveaEmmetropic = fminsearch(myObj,9)
            myComputedAlphaEle = @(eye) eye.axes.visual.degField(2);
            myObj = @(x) (targetAlphaAngle(2) - myComputedAlphaEle(modelEyeParameters('visualAxisDegRetina',[aziFoveaEmmetropic x 0])))^2;
            eleFoveaEmmetropic = fminsearch(myObj,2)
        %}
        switch eyeLaterality
            case 'Right'
                fovea_WRT_opticAxisDegRetina_emmetrope = [8.2964 -3.5762 0];
            case 'Left'
                fovea_WRT_opticAxisDegRetina_emmetrope = [-8.2964 -3.5762 0];
        end                

        % In our model, the fovea moves towards the apex of the posterior
        % chamber as the eye becomes closer to spherical. We implement this
        % effect by calculating the ratio of the posterior chamber axes.
        %{
        format long
        probeEye = modelEyeParameters('sphericalAmetropia',0);
        eccen_p1p2 = (1-probeEye.posteriorChamber.radii(1)/probeEye.posteriorChamber.radii(2))
        eccen_p1p3 = (1-probeEye.posteriorChamber.radii(1)/probeEye.posteriorChamber.radii(3))
        format
        %}        
        foveaPostionScaler(1) = (1-eye.posteriorChamber.radii(1)/eye.posteriorChamber.radii(2))/0.111716335829885;
        foveaPostionScaler(2) = (1-eye.posteriorChamber.radii(1)/eye.posteriorChamber.radii(3))/0.105571718627770;
        foveaPostionScaler(3) = 1;
        eye.axes.visual.degRetina = fovea_WRT_opticAxisDegRetina_emmetrope.*foveaPostionScaler;
        
        % The optic disc maintains a fixed distance (in retinal degrees)
        % from the fovea
        eye.axes.opticDisc.degRetina = opticDisc_WRT_foveaDegRetina + eye.axes.visual.degRetina;

        % If a visualAxisDegRetina or opticDiscAxisDegRetina key-value pair was passed,
        % override the computed value. This is used primarily during model
        % development.
        if ~isempty(p.Results.visualAxisDegRetina)
            eye.axes.visual.degRetina = p.Results.visualAxisDegRetina;
        end
        if ~isempty(p.Results.opticDiscAxisDegRetina)
            eye.axes.opticDisc.degRetina = p.Results.opticDiscAxisDegRetina;
        end
        
        % Calculate the foveal and optic disc positions in terms of mm of
        % retina. This requires the elliptic integral. The parameter
        % "theta" has a value of zero at the apex of the ellipse along the
        % axial dimension (p1).
        ellipticIntegral_p1p2=@(theta) sqrt(1-sqrt(1-eye.posteriorChamber.radii(2).^2/eye.posteriorChamber.radii(1).^2)^2.*(sin(theta)).^2);
        ellipticIntegral_p1p3=@(theta) sqrt(1-sqrt(1-eye.posteriorChamber.radii(3).^2/eye.posteriorChamber.radii(1).^2)^2.*(sin(theta)).^2);
        arcLength_p1p2 = @(theta1,theta2) eye.posteriorChamber.radii(1).*integral(ellipticIntegral_p1p2, theta1, theta2);
        arcLength_p1p3 = @(theta1,theta2) eye.posteriorChamber.radii(1).*integral(ellipticIntegral_p1p3, theta1, theta2);

        % For the calculation, the first theta value is zero, as we are
        % calculating distance from the posterior chamber apex (i.e., the
        % intersection of the optical axis with the retina).
        eye.axes.visual.mmRetina = [arcLength_p1p2(0,deg2rad(eye.axes.visual.degRetina(1))), arcLength_p1p3(0,deg2rad(eye.axes.visual.degRetina(2))), 0];
        eye.axes.opticDisc.mmRetina = [arcLength_p1p2(0,deg2rad(eye.axes.opticDisc.degRetina(1))), arcLength_p1p3(0,deg2rad(eye.axes.opticDisc.degRetina(2))), 0];
        
        % Calculate the foveal position in eyeWorld coordinates.
        phi = -eye.axes.visual.degRetina(1);
        theta = -eye.axes.visual.degRetina(2);
        x = eye.posteriorChamber.radii(1) * cosd(theta) * cosd(phi);
        y = eye.posteriorChamber.radii(2) * cosd(theta) * sind(phi);
        z = eye.posteriorChamber.radii(3) * sind(theta);
        % Note this location in the posterior chamber field
        eye.posteriorChamber.fovea = [-x y -z] + eye.posteriorChamber.center;
        
        % Calculate the optic disc position in eyeWorld coordinates.
        phi = -eye.axes.opticDisc.degRetina(1);
        theta = -eye.axes.opticDisc.degRetina(2);
        x = eye.posteriorChamber.radii(1) * cosd(theta) * cosd(phi);
        y = eye.posteriorChamber.radii(2) * cosd(theta) * sind(phi);
        z = eye.posteriorChamber.radii(3) * sind(theta);        
        % Note this location in the posterior chamber field
        eye.posteriorChamber.opticDisc = [-x y -z] + eye.posteriorChamber.center;

        % Calcuate the optic disc and visual axes in deg of visual field,
        % using the nodal point of the eye. For the visual axis, these
        % values correspond to alpha / kappa, the angles between the visual
        % and optical /pupillary axes. The difference between the visual
        % and optic disc axes specifies the location of the physiologic
        % blind spot relative to fixation.
        eye.axes.visual.degField(1) = atand((eye.posteriorChamber.fovea(2) - eye.lens.nodalPoint(2)) / (eye.posteriorChamber.fovea(1) - eye.lens.nodalPoint(1)));
        eye.axes.visual.degField(2) = -(-atand((eye.posteriorChamber.fovea(3) - eye.lens.nodalPoint(3)) / (eye.posteriorChamber.fovea(1) - eye.lens.nodalPoint(1))));
        eye.axes.visual.degField(3) = 0;
        eye.axes.opticDisc.degField(1) = atand((eye.posteriorChamber.opticDisc(2) - eye.lens.nodalPoint(2)) / (eye.posteriorChamber.opticDisc(1) - eye.lens.nodalPoint(1)));
        eye.axes.opticDisc.degField(2) = -(-atand((eye.posteriorChamber.opticDisc(3) - eye.lens.nodalPoint(3)) / (eye.posteriorChamber.opticDisc(1) - eye.lens.nodalPoint(1))));
        eye.axes.opticDisc.degField(3) = 0;
        

        %% Rotation centers
        % The rotation center of the eye is often treated as a single,
        % fixed point. A typical assumption is that the eye center of
        % rotation in emmetropes is 13.3 mm behind the corneal apex:
        %
        %   Gunter K. vonNoorden, MD; Emilio C. Campos "Binocular Vision
        %   and Ocular Motility Theory and Management of Strabismus"
        %   American Orthoptic Journal 51.1 (2001): 161-162.
        %
        % The source of this value in the cited text is not entirely clear.
        % It appears to be some compromise between the observed centers of
        % rotation that are obtained for azimuthal and elevation rotations. 
        % Measurements by Fry & Hill in 1962 and 1963 find that the
        % center of rotation is slightly nasal to the optical axis of the
        % eye, and differs for horizontal and vertical rotations:
        %
        %   Fry, G. A., and W. W. Hill. "The center of rotation of the
        %   eye." Optometry and Vision Science 39.11 (1962): 581-595.
        %
        %   Fry, Glenn A., and W. W. Hill. "The mechanics of elevating the
        %   eye." Optometry and Vision Science 40.12 (1963): 707-716.
        %
        % This difference in the apparent horizontal and vertical radii of
        % the eye was subsequently confirmed:
        %
        %   Hayami, Takehito, Kazunori Shidoji, and Katsuya Matsunaga. "An
        %   ellipsoidal trajectory model for measuring the line of sight."
        %   Vision research 42.19 (2002): 2287-2293.
        %
        % Fry & Hill report that the average azimuthal center of rotation
        % was 14.8 mm posterior to the corneal apex (14.7 in the
        % emmetropes), and 0.79 mm nasal to visual axis; and the elevation
        % center of rotation was 12.2 mm posterior to the corneal apex
        % (12.0 in the emmetropes) and 0.33 mm superior. These measurements
        % were made relative to the visual axis of the eye. While our model
        % is in optical axis coordinates, the effect of this difference is
        % very small (less than 1/100th of a millimeter).
        % 
        % Note that the Fry & Hill measurements supersede the earlier, Park
        % & Park measurements that claimed substantial translation of the
        % eye during rotation:
        %
        %   Park, Russell Smith, and George E. Park. "The center of ocular
        %   rotation in the horizontal plane." American Journal of
        %   Physiology--Legacy Content 104.3 (1933): 545-552.
        % 
        % The Park & Park result was due to their assumption that all
        % "sight lines" (i.e., rotations of the visual axis of the eye)
        % pass through the same point in space. Fry & Hill that some
        % subjects (2 of 31) show translation of the eye with rotation.
        % Also, there is a small, transient retraction of the eye following
        % a saccade that we do not attempt to model:
        %
        %   Enright, J. T. "The aftermath of horizontal saccades: saccadic
        %   retraction and cyclotorsion." Vision research 26.11 (1986):
        %   1807-1814.
        %
        % We provide three rotation centers, corresponding to the point of
        % rotation for azimuth, elevation, and torsional eye movements. The
        % values differ by eye because of the nasal displacement of the
        % rotation center.
        switch eyeLaterality
            case 'Right'
                eye.rotationCenters.azi = [-14.7 0.79 0];
            case 'Left'
                eye.rotationCenters.azi = [-14.7 -0.79 0];
        end
        eye.rotationCenters.ele = [-12.0 0 0.33];
        eye.rotationCenters.tor = [0 0 0];
        
        % Spherical ametropia is correlated with the axial length of the
        % eye. We assume here that the center of rotation reflects this
        % change in length. Fry & Hill found that azimuthal rotation depth
        % increased by 0.167 mm for each negative diopter of spherical
        % refraction, and elevation rotation depth by 0.15 mm for each
        % negative diopter. Dick and colleagues (Figure 6) found that for
        % each mm of increase in axial length, the center of rotation
        % increased by 0.5 mm:
        %
        %   Dick, Graham L., Bryan T. Smith, and Peter L. Spanos.
        %   "Axial length and radius of rotation of the eye."
        %   Clinical and Experimental Optometry 73.2 (1990): 43-50.
        %
        % Given that in the Atchison data the axial length of the eye
        % increases by 0.27 mm for each negative diopter of spherical
        % ametropic error, this would imply a lengthening of the radius of
        % eye rotation by 0.14 mm, which is in good agreement with the Fry
        % & Hill observation of 0.15 - 0.167 mm of increase.
        %
        % We scale the azi and ele rotation centers by the ratio of the
        % posterior chamber axial and vertical radii relative to the
        % emmetropic size
        eye.rotationCenters.azi = eye.rotationCenters.azi .* (eye.posteriorChamber.radii./postChamberRadiiEmetrope);
        eye.rotationCenters.ele = eye.rotationCenters.ele .* (eye.posteriorChamber.radii./postChamberRadiiEmetrope);
        eye.rotationCenters.tor = eye.rotationCenters.tor .* (eye.posteriorChamber.radii./postChamberRadiiEmetrope);

        
        %% Refractive indices
        % Obtain refractive index values for this spectral domain.
        eye.index.cornea = returnRefractiveIndex( 'cornea', p.Results.spectralDomain );
        eye.index.aqueous = returnRefractiveIndex( 'aqueous', p.Results.spectralDomain );
        eye.index.lens = returnRefractiveIndex( 'lens', p.Results.spectralDomain );

        
    %% Dog eye
    case {'dog','Dog','canine','Canine'}
        
        % Unless othewise stated, values taken from:
        %	Coile, D. C., and L. P. O'Keefe. "Schematic eyes for domestic
        %	animals." Ophthalmic and Physiological Optics 8.2 (1988):
        %	215-219.
        %
        % and
        %   Mutti, Donald O., Karla Zadnik, and Christopher J. Murphy.
        %   "Naturally occurring vitreous chamber-based myopia in the
        %   Labrador retriever." Investigative ophthalmology & visual
        %   science 40.7 (1999): 1577-1584.
        %
        % Values are given for an emmetropic canine eye.

        %% Cornea front surface
        % I cannot find a value for the asphericity, so am using the human
        % value
        eye.cornea.front.R = 8.375;
        eye.cornea.front.Q = -0.15;        
        a = eye.cornea.front.R / ( eye.cornea.front.Q + 1 );
        b = eye.cornea.front.R * sqrt(1/(eye.cornea.front.Q+1)) ;
        eye.cornea.front.radii(1) = a;
        eye.cornea.front.radii(2:3) = b;
        
        % We set the axial apex of the corneal front surface at position
        % [0, 0, 0]
        eye.cornea.front.center = [-eye.cornea.front.radii(1) 0 0];
        
        %% Cornea back surface
        % Asphericity is the human value.
        eye.cornea.back.R = 8;
        eye.cornea.back.Q = -0.275;
        
        % Compute the radii of the ellipsoid
        a = eye.cornea.back.R / ( eye.cornea.back.Q + 1 );
        b = eye.cornea.back.R * sqrt(1/(eye.cornea.back.Q+1)) ;
        eye.cornea.back.radii(1) = a;
        eye.cornea.back.radii(2:3) = b;
        
        % The thickness of the canine cornea is given as 0.587 mm by:
        %   Alario, Anthony F., and Christopher G. Pirie. "Central corneal
        %   thickness measurements in normal dogs: a comparison between
        %   ultrasound pachymetry and optical coherence tomography."
        %   Veterinary ophthalmology 17.3 (2014): 207-211.
        %
        % The center of the cornea circle for the back surface is
        % positioned to provide this thickness  between
        % the front and back surface of the cornea at the apex. 
        eye.cornea.back.center = [-0.587-eye.cornea.back.radii(1) 0 0];
        

        %% Pupil
        % We position the pupil plane at the depth of the anterior point of
        % the lens. Table 3 of:
        %
        %   Thomasy, Sara M., et al. "Species differences in the geometry
        %   of the anterior segment differentially affect anterior chamber
        %   cell scoring systems in laboratory animals." Journal of Ocular
        %   Pharmacology and Therapeutics 32.1 (2016): 28-37.
        %
        % gives an anterior chamber depth of 4.29 mm. We must then add
        % corneal thickness to properly position the pupil plane.
        eye.pupil.center = [-4.877 0 0];
        
        % We assume that the canine actual pupil is circular
        eye.pupil.eccenParams = []; 
        eye.pupil.eccenFcnString = sprintf('@(x) 0'); 
        % The theta values of the actual pupil ellipse for eccentricities
        % less than and greater than zero.
        eye.pupil.thetas = [0  0];
        
        
        %% Iris
        % Need values for this. Apparently the iris plane is tilted
        % substantially in the dog, so some estimate of this will be
        % needed.
        eye.iris.radius = 7;
       	eye.iris.center = [-4.877 0 0];


        %% Posterior chamber
        eye.posteriorChamber.radii = [ 8.25 8.25 8.25];
        
        % This is the human value; Need to do the computation for the dog.
        posteriorChamberApexDepth = 3.25;

        if isempty(p.Results.axialLength)
            eye.axialLength = posteriorChamberApexDepth + eye.posteriorChamber.radii(1)*2;
        else
            % If a specific axial length was passed (perhaps obtained by
            % measurement using the IOL Master apparatus), set the model
            % eye to have this length, and scale the other dimensions of
            % the posterior chamber to maintain the specified ametropia. We
            % adjust the axial length for the component of the anterior
            % chamber that contibutes to length (posteriorChamberApexDepth)
            scaleFactor = (p.Results.axialLength - posteriorChamberApexDepth) / (eye.posteriorChamberRadii(1)*2);
            eye.posteriorChamber.radii = eye.posteriorChamber.radii .* scaleFactor;
            eye.axialLength = p.Results.axialLength;
        end
        
        % Set the depth of the center of the posterior chamber
        eye.posteriorChamber.center = ...
            [(-4.2 - eye.posteriorChamber.radii(1)) 0 0];
        
        eye.rotationCenters.azi = [-10 0 0];
        eye.rotationCenters.ele = [-10 0 0];
        eye.rotationCenters.tor = [0 0 0];

        
        %% Refractive indices
        % Using the human values for now
        % Obtain refractive index values for this spectral domain.
        eye.index.cornea = returnRefractiveIndex( 'cornea', p.Results.spectralDomain );
        eye.index.aqueous = returnRefractiveIndex( 'aqueous', p.Results.spectralDomain );
        eye.index.lens = returnRefractiveIndex( 'lens', p.Results.spectralDomain );

        
    otherwise
        error('Please specify a valid species for the eye model');
end

% Meta data regarding the units of the model
eye.meta.p = p.Results;
eye.meta.units = 'mm';
eye.meta.coordinates = 'eyeWorld';
eye.meta.dimensions = {'depth (axial)' 'horizontal' 'vertical'};
eye.meta.alpha = 'Degrees angle of fixation axis w.r.t. optical axis.';

end % function

