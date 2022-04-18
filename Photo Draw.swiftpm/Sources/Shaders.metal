#include <metal_stdlib>
using namespace metal;

constant bool deviceSupportsNonuniformThreadgroups [[ function_constant(0) ]];

kernel void covariance_filter(texture2d<float, access::read> inTexture [[texture(0)]],
                       texture2d<float, access:: write> outTexture [[texture(1)]],
                            constant float& size [[ buffer(0) ]],
                       uint2 position [[thread_position_in_grid]]) {
    
    const auto textureSize = ushort2(outTexture.get_width(), outTexture.get_height());
    
    if (!deviceSupportsNonuniformThreadgroups) {
        if (position.x >= textureSize.x || position.y >= textureSize.y) {
               return;
        }
    }
    
    // compute x and y axis gaussian
    
    
    float4 accumColor(0, 0, 0, 0);
    
    // Calculate covariance
    float covariance = 0.0;

    float4 white(1, 1, 1, 1);
    float4 black(0, 0, 0, 1);
    
    // Write white or black pixel to texture if covariance is high enough
    if (covariance > 0.4) {
        outTexture.write(white, position);
    } else {
        outTexture.write(black, position);
    }
}

kernel void combine_covariance(texture2d<float, access::read> inTexture [[texture(0)]],
                               texture2d<float, access::read> inTextureTwo [[texture(1)]],
                               texture2d<float, access:: write> outTexture [[texture(2)]],
                               uint2 position [[thread_position_in_grid]]) {
    
    const auto textureSize = ushort2(outTexture.get_width(), outTexture.get_height());
    
    if (!deviceSupportsNonuniformThreadgroups) {
        if (position.x >= textureSize.x || position.y >= textureSize.y) {
               return;
        }
    }
    
    const auto sampleOne = inTexture.read(position);
    const auto sampleTwo = inTextureTwo.read(position);
    
    float confidenceOne = sampleOne.r;
    float confidenceTwo = sampleTwo.r;
    
    if (abs(confidenceOne) > abs(confidenceTwo)) {
        outTexture.write(sampleOne, position);
    } else {
        outTexture.write(sampleTwo, position);
    }
 
    
}
