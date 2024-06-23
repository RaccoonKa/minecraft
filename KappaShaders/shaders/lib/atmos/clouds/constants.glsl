#define RSKY_SI_CloudV_Samples 70       //[20 30 40 50 60 70 80 90 100]
#define cloudTransmittanceThreshold 0.05
#define cloudVolumeClip 10e4
#define cloudCumulusAlt 800.0       //[300.0 400.0 500.0 600.0 800.0 1000.0 1200.0 1400.0]
#define cloudCumulusDepth 2000.0    //[1000.0 1200.0 1400.0 1600.0 1800.0 2000.0 2200.0 2400.0 2600.0 2800.0 3000.0]
#define cloudCumulusScaleMult 1.0   //[0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.2 2.4 2.6]
#define cloudCumulusCoverageBias 0.0    //[-0.5 -0.45 -0.4 -0.35 -0.3 -0.25 -0.2 -0.15 -0.1 -0.05 0.0 0.02 0.04 0.06 0.08 0.1 0.12 0.14 0.16 0.18 0.2]

const float cloudCumulusMaxY    = cloudCumulusAlt + cloudCumulusDepth;
const float cloudCumulusMidY    = cloudCumulusAlt + cloudCumulusDepth * 0.5;
const float cloudCumulusScale   = 15e-5 * cloudCumulusScaleMult * (cloudCumulusAlt / 800.0);

#define CloudAltocumulusElevation 3000.0
#define CloudAltocumulusDepth 1000.0

const float CloudAltocumulusMaxY    = CloudAltocumulusElevation + CloudAltocumulusDepth;

const float cloudRaymarchMaxY   = CloudAltocumulusMaxY;
const float cloudRaymarchMidY   = cloudCumulusMidY;
const float cloudRaymarchMinY   = cloudCumulusAlt;

const float AnvilDepth          = CloudAltocumulusMaxY - cloudCumulusAlt;

#ifndef NOANIM
#ifdef freezeAtmosAnim
    const float cloudTime   = float(atmosAnimOffset) * 0.003;
#else
    #ifdef volumeWorldTimeAnim
        float cloudTime     = worldAnimTime * 1.8;
    #else
        float cloudTime     = frameTimeCounter * 0.003;
    #endif
#endif
#endif

#define CLOUDMAP0_DISTANCE 10e4

#define cloudCirrusClip 2e5
#define cloudCirrusAlt 8000.0   //[5000.0 6000.0 7000.0 8000.0 9000.0 10000.0 12000.0]
#define cloudCirrusDepth 3000.0 //[2000.0 3000.0 4000.0 5000.0 6000.0]
#define cloudCirrusScale 3e-5
#define cloudCirrusCoverageBias 0.0 //[-0.5 -0.4 -0.3 -0.2 -0.1 0.0 0.1 0.2 0.3 0.4 0.5]

const float cloudCirrusMaxY     = cloudCirrusAlt + cloudCirrusDepth;
const float cloudCirrusPlaneY   = cloudCirrusAlt + cloudCirrusDepth * 0.2;


#define CLOUD_PLANE0_ALT    9000.0 
#define CLOUD_PLANE0_DEPTH  4000.0  //[500.0 1000.0 1500.0 2000.0 2500.0 3000.0 3500.0 4000.0 4500.0 5000.0]
#define CLOUD_PLANE0_CLIP   26e4
#define CLOUD_PLANE0_COVERAGE 0.0   //[-0.5 -0.4 -0.3 -0.2 -0.1 0.0 0.1 0.2 0.3 0.4 0.5]
#define CLOUD_PLANE0_SIGMA 0.008

#define CLOUD_PLANE0_DITHERED_LIGHT

const vec2 CLOUD_PLANE0_BOUNDS = vec2(
    -CLOUD_PLANE0_DEPTH * 0.4 + CLOUD_PLANE0_ALT,
     CLOUD_PLANE0_DEPTH * 0.6 + CLOUD_PLANE0_ALT
);


#define CLOUD_PLANE1_ALT    7000.0
#define CLOUD_PLANE1_DEPTH  1000.0  //[500.0 1000.0 1500.0 2000.0 2500.0 3000.0 3500.0 4000.0 4500.0 5000.0]
#define CLOUD_PLANE1_CLIP   24e4
#define CLOUD_PLANE1_COVERAGE 0.0   //[-0.5 -0.4 -0.3 -0.2 -0.1 0.0 0.1 0.2 0.3 0.4 0.5]
#define CLOUD_PLANE1_DITHERED_LIGHT
#define CLOUD_PLANE1_SIGMA 0.01

const vec2 CLOUD_PLANE1_BOUNDS = vec2(
    -CLOUD_PLANE1_DEPTH * 0.4 + CLOUD_PLANE1_ALT,
     CLOUD_PLANE1_DEPTH * 0.6 + CLOUD_PLANE1_ALT
);

#define CLOUD_NL_ALT    80000.0
#define CLOUD_NL_DEPTH  10000.0  //[500.0 1000.0 1500.0 2000.0 2500.0 3000.0 3500.0 4000.0 4500.0 5000.0]
#define CLOUD_NL_CLIP   10e5
#define CLOUD_NL_COVERAGE 0.0   //[-0.5 -0.4 -0.3 -0.2 -0.1 0.0 0.1 0.2 0.3 0.4 0.5]
#define CLOUD_NL_SIGMA 4e-7

const vec2 CLOUD_NL_BOUNDS = vec2(
    -CLOUD_NL_DEPTH * 0.4 + CLOUD_NL_ALT,
     CLOUD_NL_DEPTH * 0.6 + CLOUD_NL_ALT
);