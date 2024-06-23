vec3 simpleFog(vec3 scene, float d, vec3 color) {
    float density   = d * 15e-6 * fogDensityMult * fogAirScale.x;

    float transmittance = expf(-density);

    return scene * transmittance + color * density;
}
vec3 waterFog(vec3 scene, float d, vec3 color) {
    float density   = max(0.0, d) * waterDensity;

    vec3 transmittance = expf(-waterAttenCoeff * density);

    const vec3 scatterCoeff = vec3(5e-2, 1e-1, 2e-1);

    vec3 scatter    = 1.0-exp(-density * waterScatterCoeff);
        scatter    *= max(expf(-waterAttenCoeff * density), expf(-waterAttenCoeff * pi));

    return scene * transmittance + scatter * color * rcp(pi);
}
vec3 lavaFog(vec3 scene, float d) {
    float density   = max(0.0, d);

    float transmittance = expf(-1.0 * density);

    return mix(vec3(1.0, 0.3, 0.02), scene, transmittance);
}