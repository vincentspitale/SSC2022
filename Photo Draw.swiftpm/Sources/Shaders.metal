#include <metal_stdlib>
using namespace metal;

kernel void covariance_filter(texture2d<float, access::read> inTexture [[texture(0)]],
                       texture2d<float, access:: write> outTexture [[texture(1)]],
                       uint2 position [[thread_position_in_grid]]) {
    // Calculate covariance
    float covariance = 0.0;

    float4 white = float4(1.0, 1.0, 1.0, 1.0);
    float4 black = float4(0.0, 0.0, 0.0, 1.0);
    
    // Write white or black pixel to texture if covariance is high enough
    if (covariance > 0.4) {
        outTexture.write(white, position);
    } else {
        outTexture.write(black, position);
    }
}
