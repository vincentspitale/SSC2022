#include <metal_stdlib>
using namespace metal;

constant bool deviceSupportsNonuniformThreadgroups [[ function_constant(0) ]];

float luminance(float3 rgb) {
    return rgb.r * 0.3 + rgb.g * 0.59 + rgb.b * 0.11;
}

kernel void correlation_filter(texture2d<float, access::read> inTexture [[texture(0)]],
                       texture2d<float, access:: write> outTexture [[texture(1)]],
                            constant float& size [[ buffer(0) ]],
                            constant bool& invert [[ buffer(1) ]],
                       uint2 position [[thread_position_in_grid]]) {
    
    const auto textureSize = ushort2(outTexture.get_width(), outTexture.get_height());
    
    if (!deviceSupportsNonuniformThreadgroups) {
        if (position.x >= textureSize.x || position.y >= textureSize.y) {
               return;
        }
    }
    
    float sigma = size / 3.0;
    
    int sampleCount = 0;
    float gaussianSumBrightness = 0;
    float sampleSumBrightness = 0;
    // Compute a 2d gaussian
    for (int i = max(0, int(position.x) - int(size)); i < min(int(textureSize.x), int(position.x) + int(size)); i++) {
        for (int j = max(0, int(position.y) - int(size)); j < min(int(textureSize.y), int(position.y) + int(size)); j++) {
            sampleCount += 1;
            
            // sample brightness
            const auto sample = inTexture.read(uint2(i,j));
            float sampleBrightness = luminance(sample.rgb);
            if (invert) {
                sampleBrightness = 1 - sampleBrightness;
            }
            sampleSumBrightness += sampleBrightness;
            
            // Bivariate Gaussian Distribution:
            // e^(1/2 (-x^2/1^2 - y^2/σ^2))/(2π σ^2)
            const int x = i - position.x;
            const int y = j - position.y;
            float gaussianSample = (pow(2.718, 0.5 * (-1 * (pow(x, 2.0)/pow(sigma, 2.0)) + (-1 * (pow(y, 2.0)/pow(sigma, 2.0)))))) / (2.0 * 3.1415 * pow(sigma, 2.0));
            gaussianSumBrightness += gaussianSample;
            
        }
    }
    
    // Find average brightnesses
    float gaussianAverage = gaussianSumBrightness / float(sampleCount);
    float sampleAverage = sampleSumBrightness / float(sampleCount);
    
    
    float numeratorSum = 0;
    float denominatorSumSample = 0;
    float denominatorSumGaussian = 0;
    for (int i = max(0, int(position.x) - int(size)); i < min(int(textureSize.x), int(position.x) + int(size)); i++) {
        for (int j = max(0, int(position.y) - int(size)); j < min(int(textureSize.y), int(position.y) + int(size)); j++) {
            // sample brightness
            const auto sample = inTexture.read(uint2(i,j));
            float sampleBrightness = luminance(sample.rgb);
            if (invert) {
                sampleBrightness = 1 - sampleBrightness;
            }
            
            // Bivariate Gaussian Distribution:
            // e^(1/2 (-x^2/1^2 - y^2/σ^2))/(2π σ^2)
            const int x = i - position.x;
            const int y = j - position.y;
            float gaussianSample = (pow(2.718, 0.5 * (-1 * (pow(x, 2.0)/pow(sigma, 2.0)) + (-1 * (pow(y, 2.0)/pow(sigma, 2.0)))))) / (2.0 * 3.1415 * pow(sigma, 2.0));
            
            float numerator = (sampleBrightness - sampleAverage) * (gaussianSample - gaussianAverage);
            numeratorSum += numerator;
            
            float denominatorSample = pow(sampleBrightness - sampleAverage, 2);
            float denominatorGaussian = pow(gaussianSample - gaussianAverage, 2);
            
            denominatorSumSample += denominatorSample;
            denominatorSumGaussian += denominatorGaussian;
        }
    }
    
    // Calculate Pearson's correlation coefficient
    float correlation = numeratorSum / sqrt(denominatorSumSample * denominatorSumGaussian);

    float4 color(correlation, correlation, correlation, 1);
    outTexture.write(color, position);
}

kernel void combine_confidence(texture2d<float, access::read> inTexture [[texture(0)]],
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


kernel void threshold_filter(texture2d<float, access::read> inTexture [[texture(0)]],
                       texture2d<float, access:: write> outTexture [[texture(1)]],
                       uint2 position [[thread_position_in_grid]]) {
    
    const auto textureSize = ushort2(outTexture.get_width(), outTexture.get_height());
    
    if (!deviceSupportsNonuniformThreadgroups) {
        if (position.x >= textureSize.x || position.y >= textureSize.y) {
               return;
        }
    }
    
    const auto sample = inTexture.read(position);
    float4 white(1, 1, 1, 1);
    float4 black(0, 0, 0, 1);
    
    if (sample.r > 0.1) {
        outTexture.write(black, position);
    } else {
        outTexture.write(white, position);
    }
}
