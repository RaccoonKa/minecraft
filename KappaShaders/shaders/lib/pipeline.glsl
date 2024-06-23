/*
const int colortex0Format   = RGBA16F;
const int colortex1Format   = RGBA16;
const int colortex2Format   = RGBA16;
const int colortex3Format   = RGBA16F;
const int colortex4Format   = RGBA16;
const int colortex5Format   = RGBA16F;
const int colortex6Format   = RGBA16F;
const int colortex7Format   = RGBA16;
const int colortex8Format   = RGBA16F;
const int colortex9Format   = RGBA16F;
const int colortex10Format  = RGBA16;
const int colortex11Format  = RGBA16F;
const int colortex12Format  = RGBA16F;
const int colortex13Format  = RGBA16F;
const int colortex14Format  = RGBA16;
const int colortex15Format  = RG8;

const int shadowcolor0Format   = RGBA16;
const int shadowcolor1Format   = RGBA16;

const vec4 colortex0ClearColor = vec4(0.0, 0.0, 0.0, 1.0);
const vec4 colortex3ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const vec4 colortex15ClearColor = vec4(0.0, 1.0, 0.0, 0.0);

const bool colortex6Clear   = false;
const bool colortex7Clear   = false;
const bool colortex8Clear   = false;
const bool colortex9Clear   = false;
const bool colortex10Clear  = false;
const bool colortex11Clear  = false;
const bool colortex12Clear  = false;
const bool colortex13Clear  = false;

const int noiseTextureResolution = 256;

C0:     SCENE COLOR
    3x16 sceneColor     (full)
    1x16 VAO            (gbuffer -> deferred)

C1:     GDATA 01
    2x16 sceneNormals   (gbuffer -> composite)
    2x8  Lightmaps      (gbuffer -> composite)
    2x8  specularTextureAux  (gbuffer -> composite)

C2:     GDATA 02
    2x8  specularTextureMain  (gbuffer -> composite)
    1x16 matID          (gbuffer -> composite)
    1x8  POM Shadows    (gbuffer -> deferred)
    1x8  Wetness        (gbuffer -> composite)

C3:     COLOR FLOAT TEMP
    4x16 cloudReconstruction (deferred -> deferred),
         indirectLight  (deferred -> deferred),
         translucentColor (water -> composite),
         fogScatterReconstruction (composite -> composite),
         bloomTiles     (composite -> composite)
         
C4:     GDATA FILTER, LIGHTING DATA
    3x16 decodedNormals (deferred -> deferred)
    1x16 linearDepth    (deferred -> deferred),
    4x16 shadows+albedo (deferred -> composite)

C5:     SKYBOX
    4x16 skyboxCapture  (prepare -> composite)

C6:     TAA
    3x16 temporalColor  (full)
    1x16 temporalExposure (full)

C7:     GDATA HISTORY
    2x16 Variance History
    1x16 Adaption History
    1x16 historyDepth   (full)

C8:     CLOUD TEMPORAL
    4x16 cloudReconstruct   (full)

C9:     FOG TEMPORAL
    3x16 fogScatterReconstruct (full)
    1x16 previousDistance (full)

C10:    FOG TEMPORAL + CHECKERBOARD
    3x16 fogTransmittanceReconstruct (full)
    2x8  checkerboardData   (full)

C11:    INDIRECT ACCUMULATION
    3x16 indirectLightHistory (full)
    1x16 pixelAge       (full)

C12:    REFLECTION CAPTURE
    3x16 reflectionCapture  (full)
    1x16 reflectionCaptureDepth (full)

C13:    GDATA CAPTURE
    3x16 reflectionCaptureAux   (full)

C14:    COLOR NORM TEMP
    3x16 directSunlight (deferred -> deferred),
         fogTransmittanceReconstruction (composite -> composite)

C15:    AUX
    1x8 weather particles (gbuffers -> composite)
    1x8 vanillaAO (deferred -> deferred)
*/