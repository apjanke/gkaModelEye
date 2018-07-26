function sceneGeometry = createSceneGeometry(varargin)
% Create and return a sceneGeometry structure
%
% Syntax:
%  sceneGeometry = createSceneGeometry()
%
% Description:
%   Using default values and passed key/value pairs, this routine creates a
%   sceneGeometry structure, with fields that describe a camera, an eye,
%   corrective lenses, and the geometric relationship between them. The
%   fields are:
%
%  'cameraIntrinsic' - A structure that defines the properties of a pinhole
%       camera. Sub-fields:
%
%      'matrix' - A 3x3 matrix of the form:
%
%               [fx  s x0; 0  fy y0; 0   0  1]
%
%           where fx and fy are the focal lengths of the camera in the x
%           and y image dimensions, s is the axis skew, and x0, y0 define
%           the principle offset point. For a camera sensor with square
%           pixels, fx = fy. Ideally, skew should be zero. The principle
%           offset point is usually in the center of the sensor. Units are
%           traditionally in pixels. These values can be empirically
%           measured for a camera using a resectioning approach
%           (https://www.mathworks.com/help/vision/ref/cameramatrix.html).
%           Note that the values in the matrix returned by the MATLAB
%           camera resectioning routine must be re-arranged to correspond
%           to the X Y image dimension specifications used here.
%
%      'radialDistortion' - A 1x2 vector that models the radial distortion
%           introduced by the lens. This is an empirically measured
%           property of the camera system.
%
%      'sensorResolution' - A 1x2 vector that provides the dimension of the
%           camera image in pixels, along the X and Y dimensions,
%           respectively.
%
%  'cameraPosition' - A structure that defines the spatial position of the
%       camera w.r.t. to world coordinates. This is used to assemble the
%       camera extrinsic matrix. Sub-fields:
%
%      'translation' - A 3x1 vector of the form [horizontal; vertical;
%           depth] in units of mm. Specifies the location of the nodal
%           point of the camera relative to the world coordinate system. We
%           define the origin of the world coordinate system to be x=0, y=0
%           along the optical axis of the eye with zero rotation, and z=0
%           to be the apex of the corneal surface.
%
%      'torsion' - Scalar in units of degrees that specifies the torsional
%           rotation of the camera relative to the origin of the world
%           coordinate space. Because eye rotations are set have a value of
%           zero when the camera axis is aligned with the pupil axis of the
%           eye, the camera rotation around the X and Y axes of the
%           coordinate system are not used. Rotation about the Z axis
%           (torsion) is meaningful, as the model eye has different
%           movement properties in the azimuthal and elevational
%           directions, and has a non circular exit pupil.
%
%      'primaryPosition' - A 1x2 vector of [eyeAzimuth, eyeElevation] at
%           which the eye is in primary position (as defined by Listing*s
%           Law) and thus has zero torsion.
%
%  'eye' - A structure that is returned by the function modelEyeParameters.
%       The parameters define the anatomical properties of the eye. These
%       parameters are adjusted for the measured spherical refractive error
%       of the subject and (optionally) measured axial length. Unmatched
%       key-value pairs passed to createSceneGeometry are passed to
%       modelEyeParameters.
%
%  'refraction' - A structure with sub-fields for ray-tracing through sets
%       of optical surfaces. Standard fields are 'retinaToPupil' and
%       'pupilToCamera'. Each 
%
%          'opticalSystem' - A 10x5 matrix. The first m rows contain
%                           information regarding the m surfaces of the
%                           cornea, and any corrective lenses, in a format
%                           needed for ray tracing. The trailing (10-m)
%                           rows contain nans. The variable must be a
%                           fixed size matrix so that the compiled
%                           virtualImageFuncMex is able to pre-allocate
%                           variables. The nan rows are later stripped by
%                           the rayTraceEllipsoids function.
%
%  'lenses' - An optional structure that describes the properties of
%       refractive lenses that are present between the eye and the camera.
%       Possible sub-fields are 'contact' and 'spectacle', each of which
%       holds the parameters that were used to add a refractive lens to the
%       optical path.
%
%  'constraintTolerance' - A scalar. This value is used by the function
%       pupilProjection_inv. The inverse projection from an ellipse on the
%       image plane to eye params (azimuth, elevation) imposes a constraint
%       on how well the solution must match the shape and area of the
%       ellipse. This constraint is expressed as a proportion of error,
%       relative to either the largest possible area in ellipse shape or an
%       error in area equal to the area of the ellipse itself (i.e.,
%       unity). If the constraint is made too stringent, then in an effort
%       to perfectly match the shape of the ellipse, error will increase in
%       matching the position of the ellipse center. It should be noted
%       that even in a noise-free simulation, it is not possible to
%       perfectly match ellipse shape and area while matching ellipse
%       center position, as the shape of the projection of the pupil upon
%       the image plane deviates from perfectly elliptical. We find that a
%       value in the range 0.01 - 0.03 provides an acceptable compromise in
%       empirical data.
%
%  'meta' - A structure that contains information regarding the creation
%       and modification of the sceneGeometry.
%
%
% Inputs:
%   none
%
% Optional key/value pairs
%  'sceneGeometryFileName' - Full path to file
%  'intrinsicCameraMatrix' - 3x3 matrix
%  'radialDistortionVector' - 1x2 vector of radial distortion parameters
%  'cameraTranslation'    - 3x1 vector
%  'cameraRotation'       - 1x3 vector
%  'constraintTolerance'  - Scalar. Range 0-1. Typical value 0.01 - 0.03
%  'contactLens'          - Scalar or 1x2 vector, with values for the lens
%                           refraction in diopters, and (optionally) the
%                           index of refraction of the lens material. If
%                           left empty, no contact lens is added to the
%                           model.
%  'spectacleLens'        - Scalar, 1x2, or 1x3 vector, with values for the
%                           lens refraction in diopters, (optionally) the
%                           index of refraction of the lens material, and
%                           (optinally) the vertex distance in mm. If left
%                           empty, no spectacle is added to the model.
%  'cameraMedium'               - String, options include:
%                           {'air','water','vacuum'}. This sets the index
%                           of refraction of the medium between the eye and
%                           the camera.
%  'spectralDomain'       - String, options include {'vis','nir'}.
%                           This is the light domain within which imaging
%                           is being performed. The refractive indices vary
%                           based upon this choice.
%  'forceMATLABVirtualImageFunc' - Logical, default false. If set to
%                           true, the native MATLAB code for the
%                           virtualImageFunc is used for refraction,
%                           instead of a compiled MEX file. This is used
%                           for debugging and demonstration purposes.
%
% Outputs
%	sceneGeometry         - A structure.
%
% Examples:
%{
    % Create a sceneGeometry file for a myopic eye wearing a contact lens.
    % The key-value sphericalAmetropia is passed to modelEyeParameters
    % within the routine
    sceneGeometry = createSceneGeometry('sphericalAmetropia',-2,'contactLens',-2);
%}
%{
    % Create a sceneGeometry file for a myopic eye wearing spectacles
    % of appropriate correction. Place the system under water, and imaged
    % in the visible range
    sceneGeometry = createSceneGeometry('sphericalAmetropia',-2,'spectacleLens',-2,'cameraMedium','water','spectralDomain','vis');
    % Plot a figure that traces a ray arising from the optical axis at the
    % pupil plane, departing at 15 degrees.
    clear figureFlag
    figureFlag.p1Lim = [-15 20]; figureFlag.p2Lim = [-10 10]; figureFlag.p3Lim = [-10 10];
    rayTraceEllipsoids([sceneGeometry.eye.pupil.center(1) 2], deg2rad(15), sceneGeometry.refraction.opticalSystem,figureFlag);
%}


%% input parser
p = inputParser; p.KeepUnmatched = true;

% Optional analysis params
p.addParameter('sceneGeometryFileName','', @(x)(isempty(x) | ischar(x)));
p.addParameter('intrinsicCameraMatrix',[2600 0 320; 0 2600 240; 0 0 1],@isnumeric);
p.addParameter('sensorResolution',[640 480],@isnumeric);
p.addParameter('radialDistortionVector',[0 0],@isnumeric);
p.addParameter('cameraTranslation',[0; 0; 120],@isnumeric);
p.addParameter('cameraTorsion',0,@isnumeric);
p.addParameter('constraintTolerance',0.02,@isscalar);
p.addParameter('surfaceSetName',{'retinaToPupil','pupilToCamera'},@ischar);
p.addParameter('contactLens',[], @(x)(isempty(x) | isnumeric(x)));
p.addParameter('spectacleLens',[], @(x)(isempty(x) | isnumeric(x)));
p.addParameter('cameraMedium','air',@ischar);
p.addParameter('spectralDomain','nir',@ischar);

% parse
p.parse(varargin{:})


%% cameraIntrinsic
sceneGeometry.cameraIntrinsic.matrix = p.Results.intrinsicCameraMatrix;
sceneGeometry.cameraIntrinsic.radialDistortion = p.Results.radialDistortionVector;
sceneGeometry.cameraIntrinsic.sensorResolution = p.Results.sensorResolution;


%% cameraExtrinsic
sceneGeometry.cameraPosition.translation = p.Results.cameraTranslation;
sceneGeometry.cameraPosition.torsion = p.Results.cameraTorsion;
sceneGeometry.cameraPosition.primaryPosition = [0,0];


%% eye
sceneGeometry.eye = modelEyeParameters('spectralDomain',p.Results.spectralDomain,varargin{:});


%% refraction
for ii = 1:length(p.Results.surfaceSetName)
    [opticalSystem, surfaceLabels, surfaceColors] = ...
        assembleOpticalSystem( sceneGeometry.eye, ...
        'surfaceSetName', p.Results.surfaceSetName{ii}, ...
        'cameraMedium', p.Results.cameraMedium, ...
        'contactLens', p.Results.contactLens, ...
        'spectacleLens', p.Results.spectacleLens );
    sceneGeometry.refraction.(p.Results.surfaceSetName{ii}).opticalSystem = opticalSystem;
    sceneGeometry.refraction.(p.Results.surfaceSetName{ii}).surfaceLabels = surfaceLabels;
    sceneGeometry.refraction.(p.Results.surfaceSetName{ii}).surfaceColors = surfaceColors;
end


%% constraintTolerance
sceneGeometry.constraintTolerance = p.Results.constraintTolerance;


%% meta
sceneGeometry.meta.createSceneGeometry = p.Results;


%% Save the sceneGeometry file
if ~isempty(p.Results.sceneGeometryFileName)
    save(p.Results.sceneGeometryFileName,'sceneGeometry');
end

end % createSceneGeometry

