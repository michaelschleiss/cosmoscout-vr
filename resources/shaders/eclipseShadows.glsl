#ifndef CS_ECLIPSE_SHADOWS_GLSL
#define CS_ECLIPSE_SHADOWS_GLSL

const float ECLIPSE_TEX_SHADOW_EXPONENT = 1.0;
const int   ECLIPSE_MAX_BODIES          = 8;
const float ECLIPSE_PI                  = 3.14159265358979323846;
const float ECLIPSE_TWO_PI              = 2.0 * ECLIPSE_PI;

uniform int       uEclipseMode;
uniform vec4      uEclipseSun;
uniform int       uEclipseNumOccluders;
uniform vec4      uEclipseOccluders[ECLIPSE_MAX_BODIES];
uniform sampler2D uEclipseShadowMaps[ECLIPSE_MAX_BODIES];

// Returns the surface area of a circle.
float _eclipseGetCircleArea(float r) {
  return ECLIPSE_PI * r * r;
}

// Returns the surface area of a spherical cap on a unit sphere.
float _eclipseGetCapArea(float r) {
  return 2.0 * ECLIPSE_PI * (1.0 - cos(r));
}

float _eclipseGetCircleIntersection(float radiusA, float radiusB, float centerDistance) {

  // No intersection
  if (centerDistance >= radiusA + radiusB) {
    return 0.0;
  }

  // One circle fully in the other (total eclipse)
  if (min(radiusA, radiusB) <= max(radiusA, radiusB) - centerDistance) {
    return _eclipseGetCircleArea(min(radiusA, radiusB));
  }

  float d = centerDistance;

  float rrA = radiusA * radiusA;
  float rrB = radiusB * radiusB;
  float dd  = d * d;

  float d1 = fma(radiusA, radiusA, fma(-radiusB, radiusB, dd)) / (2 * d);
  float d2 = d - d1;

  float fourth = -d2 * sqrt(fma(-d2, d2, rrB));
  float third  = fma(rrB, acos(d2 / radiusB), fourth);
  float second = fma(-d1, sqrt(fma(-d1, d1, rrA)), third);

  return fma(rrA, acos(d1 / radiusA), second);
}

// Returns the intersection area of two spherical caps with radii radiusA and radiusB whose center
// points are centerDistance away from each other. All values are given as angles on the unit
// sphere.
float _eclipseGetCapIntersection(float radiusA, float radiusB, float centerDistance) {

  // No intersection
  if (centerDistance >= radiusA + radiusB) {
    return 0.0;
  }

  // One circle fully in the other
  if (min(radiusA, radiusB) <= max(radiusA, radiusB) - centerDistance) {
    return _eclipseGetCapArea(min(radiusA, radiusB));
  }

  float sinD  = sin(centerDistance);
  float cosD  = cos(centerDistance);
  float sinRA = sin(radiusA);
  float sinRB = sin(radiusB);
  float cosRA = cos(radiusA);
  float cosRB = cos(radiusB);

  return 2.0 * (ECLIPSE_PI - acos(cosD / (sinRA * sinRB) - (cosRA * cosRB) / (sinRA * sinRB)) -
                   acos(cosRB / (sinD * sinRA) - (cosD * cosRA) / (sinD * sinRA)) * cosRA -
                   acos(cosRA / (sinD * sinRB) - (cosD * cosRB) / (sinD * sinRB)) * cosRB);
}

float _eclipseGetCapIntersectionApprox(float radiusA, float radiusB, float centerDistance) {

  // No intersection
  if (centerDistance >= radiusA + radiusB) {
    return 0.0;
  }

  // One circle fully in the other
  if (min(radiusA, radiusB) <= max(radiusA, radiusB) - centerDistance) {
    return _eclipseGetCapArea(min(radiusA, radiusB));
  }

  float diff   = abs(radiusA - radiusB);
  float interp = smoothstep(
      0.0, 1.0, 1.0 - clamp((centerDistance - diff) / (radiusA + radiusB - diff), 0.0, 1.0));

  return interp * _eclipseGetCapArea(min(radiusA, radiusB));
}

// This returns basically acos(dot(v1, v2)), but seems to have less floating point errors.
float _eclipseGetAngle(vec3 v1, vec3 v2) {
  float c = dot(v1 - v2, v1 - v2);
  return 2.0 * atan(sqrt(c), sqrt(4 - c));
}

vec4 _eclipseGetBodyDirAngle(vec4 body, vec3 position) {
  vec3  bodyPos   = body.xyz - position;
  float bodyDist  = length(bodyPos);
  vec3  bodyDir   = bodyPos / bodyDist;
  float bodyAngle = asin(body.w / bodyDist);

  return vec4(bodyDir, bodyAngle);
}

vec3 getEclipseShadow(vec3 position) {

  // None.
  if (uEclipseMode == 0) {
    return vec3(1.0);
  }

  // -----------------------------------------------------------------------------------------------
  // ------------------------------------- Debug Mode ----------------------------------------------
  // -----------------------------------------------------------------------------------------------

  if (uEclipseMode == 1) {
    vec3 light = vec3(1.0);

    vec4 sunDirAngle = _eclipseGetBodyDirAngle(uEclipseSun, position);

    for (int i = 0; i < uEclipseNumOccluders; ++i) {

      vec4  bodyDirAngle = _eclipseGetBodyDirAngle(uEclipseOccluders[i], position);
      float sunBodyDist  = _eclipseGetAngle(sunDirAngle.xyz, bodyDirAngle.xyz);

      if (sunDirAngle.w < bodyDirAngle.w - sunBodyDist) {
        light *= vec3(1.0, 0.5, 0.5); // Total eclipse.
      } else if (sunBodyDist < sunDirAngle.w - bodyDirAngle.w) {
        light *= vec3(0.5, 1.0, 0.5); // Annular eclipse.
      } else if (sunBodyDist < sunDirAngle.w + bodyDirAngle.w) {
        light *= vec3(0.5, 0.5, 1.0); // Partial eclipse.
      }
    }

    return light;
  }

  // -----------------------------------------------------------------------------------------------
  // -------------------------------------- Celestia -----------------------------------------------
  // -----------------------------------------------------------------------------------------------

  // Quaoting a source code comment from Celestia: "All of the eclipse related code assumes that
  // both the caster and receiver are spherical. Irregular receivers will work more or less
  // correctly, but casters that are sufficiently non-spherical will produce obviously incorrect
  // shadows. Another assumption we make is that the distance between the caster and receiver is
  // much less than the distance between the sun and the receiver. This approximation works
  // everywhere in the solar system, and is likely valid for any orbitally stable pair of objects
  // orbiting a star."

  // Also from the source code: "The shadow shadow consists of a circular region of constant depth
  // (maxDepth), surrounded by a ring of linear falloff from maxDepth to zero. For a total eclipse,
  // maxDepth is zero. In reality, the falloff function is much more complex: to calculate the exact
  // amount of sunlight blocked, we need to calculate the a circle-circle intersection area."

  // There seem to be some geometric simplifications in this code - the apparent radii of the bodies
  // are computed by dividing their actual radius by the distance. This is actually not valid for
  // spheres but only for circles. However, the introduced error seems to be very small. There's no
  // noticeable difference to the more complete implementation in the Cosmographia version further
  // below.

  // Based on this code:
  // https://github.com/CelestiaProject/Celestia/blob/master/src/celengine/shadermanager.cpp#L1344
  // https://github.com/CelestiaProject/Celestia/blob/master/src/celengine/shadermanager.cpp#L3811
  // https://github.com/CelestiaProject/Celestia/blob/master/src/celengine/render.cpp#L2969

  if (uEclipseMode == 2) {
    vec3 light = vec3(1.0);
    for (int i = 0; i < uEclipseNumOccluders; ++i) {
      float sunDistance  = length(uEclipseOccluders[i].xyz - uEclipseSun.xyz);
      float appSunRadius = uEclipseSun.w / sunDistance;

      float distToCaster      = length(uEclipseOccluders[i].xyz - position);
      float appOccluderRadius = uEclipseOccluders[i].w / distToCaster;

      float penumbraRadius = (1 + appSunRadius / appOccluderRadius) * uEclipseOccluders[i].w;

      float umbraRadius =
          uEclipseOccluders[i].w * (appOccluderRadius - appSunRadius) / appOccluderRadius;
      float maxDepth = min(1.0, pow(appOccluderRadius / appSunRadius, 2.0));

      float umbra   = umbraRadius / penumbraRadius;
      float falloff = maxDepth / max(0.001, 1.0 - abs(umbra));

      // Project the vector from fragment to occluder on the Sun-Occluder ray.
      vec3 toOcc        = uEclipseOccluders[i].xyz - position;
      vec3 sunToOccNorm = (uEclipseOccluders[i].xyz - uEclipseSun.xyz) / sunDistance;
      vec3 toOccProj    = dot(toOcc, sunToOccNorm) * sunToOccNorm;

      // Get vertical position in shadow space.
      float posY = length(toOcc - toOccProj);

      // This r is computed quite differently in Celestia. This is due to the fact that eclipse
      // shadows are not computed in worldspace in Celestia but rather in a shadow-local coordinate
      // system.
      float r = 1 - posY / penumbraRadius;

      if (r > 0.0) {
        float shadowR = clamp(r * falloff, 0.0, maxDepth);
        light *= 1 - shadowR;
      }
    }

    return light;
  }

  // -----------------------------------------------------------------------------------------------
  // ----------------------------------- Cosmographia ----------------------------------------------
  // -----------------------------------------------------------------------------------------------

  // Cosmographia (or rather the VESTA library which is used by Cosmographia) performs a very
  // involved computation of the umbra and penumbra cones. In fact, it claims to support ellipsoidal
  // shadow caster by asymmetrical scaling of the shadow matrix. For now, this is difficult to
  // replicate here, however, when compared to the other evaluated solutions, it seems to be the
  // only one which computes the correct apex angles of the cones. To replicate the behavior here,
  // we use out own code to compute the penumbra and umbra radius and use the Cosmosgraphia approach
  // to map this to a shadow value.

  // Yet, it seems to use a linear falloff from the umbra to the penumbra and I do not see a proper
  // falloff handling beyond the end of the umbra.

  // Based on this code:
  // https://github.com/claurel/cosmographia/blob/171462736a30c06594dfc45ad2daf85d024b20e2/thirdparty/vesta/internal/EclipseShadowVolumeSet.cpp
  // https://github.com/claurel/cosmographia/blob/171462736a30c06594dfc45ad2daf85d024b20e2/thirdparty/vesta/ShaderBuilder.cpp#L222
  // https://github.com/claurel/cosmographia/blob/171462736a30c06594dfc45ad2daf85d024b20e2/thirdparty/vesta/UniverseRenderer.cpp#L1980

  if (uEclipseMode == 3) {
    vec3 light = vec3(1.0);
    for (int i = 0; i < uEclipseNumOccluders; ++i) {
      float sunDistance = length(uEclipseSun.xyz - uEclipseOccluders[i].xyz);

      float rOcc   = uEclipseOccluders[i].w;
      float dOcc   = sunDistance / (uEclipseSun.w / rOcc + 1);
      float yP     = rOcc / dOcc * sqrt(dOcc * dOcc - rOcc * rOcc);
      float xOcc   = sqrt(rOcc * rOcc - yP * yP);
      float xUmbra = (sunDistance * rOcc) / (uEclipseSun.w - rOcc) + xOcc;
      float xF     = xOcc - dOcc;

      float xUmbraRimDist = sqrt(pow(xUmbra - xOcc, 2.0) - rOcc * rOcc);
      float yU            = rOcc * xUmbraRimDist / (xUmbra - xOcc);
      float a             = rOcc * rOcc / (xUmbra - xOcc);

      float penumbraSlope = yP / -xF;
      float umbraSlope    = -yU / (xUmbra - xOcc - a);

      // Project the vector from fragment to occluder on the Sun-Occluder ray.
      vec3 toOcc        = uEclipseOccluders[i].xyz - position;
      vec3 sunToOccNorm = (uEclipseOccluders[i].xyz - uEclipseSun.xyz) / sunDistance;
      vec3 toOccProj    = dot(toOcc, sunToOccNorm) * sunToOccNorm;

      // Get position in shadow space.
      float posX = length(toOccProj) + xOcc;
      float posY = length(toOcc - toOccProj);

      float penumbra = penumbraSlope * posX + yP;
      float umbra    = umbraSlope * (posX + a + xOcc) + yU;

      // As umbra becomes negative beyond the end of the umbra, the results of this code are wrong
      // from this point on.
      light *= clamp((posY - umbra) / (penumbra - umbra), 0.0, 1.0);
    }

    return light;
  }

  // -----------------------------------------------------------------------------------------------
  // ------------------------------------- OpenSpace -----------------------------------------------
  // -----------------------------------------------------------------------------------------------

  // At the moment, the eclipse shadows in OpenSpace seem to be quite basic. They assume a spherical
  // light source as well as spherical shadow casters. There are some geometric simplifications in
  // computing the umbra and penumbra cones - effectively the Sun and the shadow caster are modelled
  // as circles oriented perpendicular to the Sun-Occluder axis. Furthermore, there seems to be no
  // shadow falloff beyond the end of the umbra. The penumbra keeps getting wider and wider, but the
  // center of the shadow volume will always stay black.

  // Based on this code:
  // https://github.com/OpenSpace/OpenSpace/blob/d7d279ea168f5eaa6a0109593360774246699c4e/modules/globebrowsing/shaders/renderer_fs.glsl#L93
  // https://github.com/OpenSpace/OpenSpace/blob/d7d279ea168f5eaa6a0109593360774246699c4e/modules/globebrowsing/src/renderableglobe.cpp#L2086

  if (uEclipseMode == 4) {

    vec3 light = vec3(1.0);

    for (int i = 0; i < uEclipseNumOccluders; ++i) {
      float sunDistance = length(uEclipseSun.xyz - uEclipseOccluders[i].xyz);

      // Project the vector from fragment to occluder on the Sun-Occluder ray.
      vec3  pc             = uEclipseOccluders[i].xyz - position;
      vec3  sc_norm        = (uEclipseOccluders[i].xyz - uEclipseSun.xyz) / sunDistance;
      vec3  pc_proj        = dot(pc, sc_norm) * sc_norm;
      float length_pc_proj = length(pc_proj);

      // Compute distance from fragment to Sun-Occluder ray.
      vec3  d        = pc - pc_proj;
      float length_d = length(d);

      // Compute focus point of the penumbra cone. Somewhere in front of the occluder.
      float xp = uEclipseOccluders[i].w * sunDistance / (uEclipseSun.w + uEclipseOccluders[i].w);

      // Compute focus point of the umbra cone. Somewhere behind occluder.
      float xu = uEclipseOccluders[i].w * sunDistance / (uEclipseSun.w - uEclipseOccluders[i].w);

      // The radius of the penumbra cone, computed with the intercept theorem. This is not really
      // correct, as the tangents at the occluder do not really touch the poles.
      float r_p_pi = uEclipseOccluders[i].w * (length_pc_proj + xp) / xp;
      float r_u_pi = uEclipseOccluders[i].w * (xu - length_pc_proj) / xu;

      if (length_d < r_u_pi) { // umbra

        // The original code uses this:
        // light *= sqrt(r_u_pi / (r_u_pi + pow(length_d, 2.0)));

        // In open space, this is close to zero in most cases, however as we are in the umbra, using
        // exaclty zero seems more correct...
        light *= 0.0;

      } else if (length_d < r_p_pi) { // penumbra

        // This returns a linear falloff from the center of the shadow to the penumbra's edge. Using
        // light *= (length_d - max(0, r_u_pi)) / (r_p_pi - max(0, r_u_pi));
        // would have been better as this decays to zero towards the umbra. Nevertheless, this code
        // still returns a completely black shadow center even behind the end of the umbra...?

        light *= length_d / r_p_pi;
      }
    }

    return light;
  }

  // -----------------------------------------------------------------------------------------------
  // ---------------------------- Various Analytical Approaches ------------------------------------
  // -----------------------------------------------------------------------------------------------

  // 6: Circle Intersection
  // 7: Approximated Spherical Cap Intersection
  // 8: Spherical Cap Intersection
  if (uEclipseMode == 5 || uEclipseMode == 6 || uEclipseMode == 7) {

    vec3 light = vec3(1.0);

    vec4  sunDirAngle   = _eclipseGetBodyDirAngle(uEclipseSun, position);
    float sunSolidAngle = ECLIPSE_PI * sunDirAngle.w * sunDirAngle.w;

    for (int i = 0; i < uEclipseNumOccluders; ++i) {

      vec4  bodyDirAngle = _eclipseGetBodyDirAngle(uEclipseOccluders[i], position);
      float sunBodyDist  = _eclipseGetAngle(sunDirAngle.xyz, bodyDirAngle.xyz);

      float intersect = 0;

      if (uEclipseMode == 5) {
        intersect = _eclipseGetCircleIntersection(sunDirAngle.w, bodyDirAngle.w, sunBodyDist);
      } else if (uEclipseMode == 6) {
        intersect = _eclipseGetCapIntersectionApprox(sunDirAngle.w, bodyDirAngle.w, sunBodyDist);
      } else {
        intersect = _eclipseGetCapIntersection(sunDirAngle.w, bodyDirAngle.w, sunBodyDist);
      }

      light *= (sunSolidAngle - clamp(intersect, 0.0, sunSolidAngle)) / sunSolidAngle;
    }

    return light;
  }

  // -----------------------------------------------------------------------------------------------
  // --------------------- Get Eclipse Shadow by Texture Lookups -----------------------------------
  // -----------------------------------------------------------------------------------------------

  vec3  light         = vec3(1.0);
  vec4  sunDirAngle   = _eclipseGetBodyDirAngle(uEclipseSun, position);
  float sunSolidAngle = ECLIPSE_PI * sunDirAngle.w * sunDirAngle.w;

  for (int i = 0; i < uEclipseNumOccluders; ++i) {

    vec4  bodyDirAngle = _eclipseGetBodyDirAngle(uEclipseOccluders[i], position);
    float sunBodyDist  = _eclipseGetAngle(sunDirAngle.xyz, bodyDirAngle.xyz);

    float x = 1.0 / (bodyDirAngle.w / sunDirAngle.w + 1.0);
    float y = sunBodyDist / (bodyDirAngle.w + sunDirAngle.w);

    if (x > 0.0 && x < 1.0 && y > 0.0 && y < 1.0) {
      light *= texture(uEclipseShadowMaps[i], vec2(x, 1 - y)).rgb;
    }
  }

  return light;
}

#endif // CS_ECLIPSE_SHADOWS_GLSL