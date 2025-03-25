#include <metal_stdlib>
using namespace metal;

// Struttura per i parametri di rendering
struct RenderParameters {
    int orientation;      // 0 = axial, 1 = coronal, 2 = sagittal
    int sliceIndex;
    float windowCenter;
    float windowWidth;
    int outputWidth;
    int outputHeight;
};

// Kernel per il rendering MPR
kernel void mprKernel(texture3d<short, access::sample> volumeTexture [[texture(0)]],
                      texture2d<float, access::write> outputTexture [[texture(1)]],
                      constant RenderParameters& params [[buffer(0)]],
                      uint2 position [[thread_position_in_grid]]) {

    // Verifica che la posizione sia all'interno della texture di output
    if (position.x >= params.outputWidth || position.y >= params.outputHeight) {
        return;
    }

    // Ottieni le dimensioni del volume
    float3 volumeSize = float3(volumeTexture.get_width(),
                              volumeTexture.get_height(),
                              volumeTexture.get_depth());

    // Coordinate volumetriche
    float3 volumeCoord;

    // Calcola la coordinata nel volume in base all'orientamento
    switch (params.orientation) {
        case 0: // Axial (XY plane, fixed Z)
            volumeCoord = float3(float(position.x),
                                float(position.y),
                                float(params.sliceIndex));
            break;

        case 1: // Coronal (XZ plane, fixed Y)
            volumeCoord = float3(float(position.x),
                                float(params.sliceIndex),
                                float(position.y));
            break;

        case 2: // Sagittal (YZ plane, fixed X)
            volumeCoord = float3(float(params.sliceIndex),
                                float(position.x),
                                float(position.y));
            break;

        default:
            volumeCoord = float3(0, 0, 0);
            break;
    }

    // Normalizza le coordinate per il campionamento
    float3 normalizedCoord = volumeCoord / volumeSize;

    // Verifica che le coordinate siano nel volume
    if (normalizedCoord.x < 0.0 || normalizedCoord.x > 1.0 ||
        normalizedCoord.y < 0.0 || normalizedCoord.y > 1.0 ||
        normalizedCoord.z < 0.0 || normalizedCoord.z > 1.0) {
        // Fuori dal volume, imposta pixel nero
        outputTexture.write(float4(0.0, 0.0, 0.0, 1.0), position);
        return;
    }

    // Configura il sampler
    constexpr sampler volumeSampler(coord::normalized,
                                  filter::linear,
                                  address::clamp_to_edge);

    // Campiona il valore dal volume
    short voxelValue = volumeTexture.sample(volumeSampler, normalizedCoord).r;
    float value = float(voxelValue);

    // Applica il windowing
    float lowerBound = params.windowCenter - (params.windowWidth / 2.0);
    float upperBound = params.windowCenter + (params.windowWidth / 2.0);

    // Trasforma il valore utilizzando la finestra specificata
    float windowedValue = (value - lowerBound) / params.windowWidth;
    windowedValue = clamp(windowedValue, 0.0f, 1.0f);

    // Scrivi il risultato nella texture di output
    outputTexture.write(float4(windowedValue, windowedValue, windowedValue, 1.0), position);
}
