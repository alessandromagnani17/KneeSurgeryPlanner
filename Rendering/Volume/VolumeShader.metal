/*
 Shader Metal per il rendering volumetrico tramite ray casting.

 Componenti principali:
 - vertexShader: Genera un quad che copre l'intera viewport per eseguire il ray casting.
 - fragmentShader: Esegue il ray marching nel volume DICOM per creare l'immagine 3D.
 - transferFunction: Mappa i valori DICOM (HU) a colori utilizzando una scala di grigi.

 Funzionalità:
 - Implementa il ray casting per attraversare il volume 3D.
 - Esegue la composizione front-to-back per accumulare colore e opacità.
 - Supporta parametri personalizzati come il window center e il window width.
 - Campiona il volume 3D con un filtro lineare per una resa fluida.

 Scopo:
 Realizzare la visualizzazione volumetrica interattiva di dati DICOM in un contesto 3D.
 */

#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut vertexShader(uint vertexID [[vertex_id]]) {
    // Crea un quad che copre l'intera viewport
    float2 positions[6] = {
        float2(-1, -1), float2(1, -1), float2(-1, 1),
        float2(1, -1), float2(1, 1), float2(-1, 1)
    };
    
    float2 texCoords[6] = {
        float2(0, 0), float2(1, 0), float2(0, 1),
        float2(1, 0), float2(1, 1), float2(0, 1)
    };
    
    VertexOut out;
    out.position = float4(positions[vertexID], 0, 1);
    out.texCoord = texCoords[vertexID];
    
    return out;
}

// OTTIMIZZAZIONE: Funzione di trasferimento migliorata con supporto per modalità preview
float4 transferFunction(float value, float windowCenter, float windowWidth, bool isPreview = false) {
    // Mappa i valori HU a colori
    float normalizedValue = (value - (windowCenter - windowWidth/2)) / windowWidth;
    normalizedValue = clamp(normalizedValue, 0.0, 1.0);
    
    // In modalità preview, usa mappatura più semplice con colori più contrastati
    if (isPreview) {
        // Binning values for better contrast in preview mode
        if (normalizedValue < 0.1) {
            return float4(0.0, 0.0, 0.0, 0.0); // transparent
        } else if (normalizedValue < 0.4) {
            return float4(0.2, 0.4, 0.8, 0.7); // blue-ish for low values
        } else if (normalizedValue < 0.7) {
            return float4(0.7, 0.7, 0.7, 0.8); // gray for mid values
        } else {
            return float4(1.0, 1.0, 1.0, 0.9); // white for high values
        }
    } else {
        // Scala di grigi standard
        return float4(normalizedValue, normalizedValue, normalizedValue, normalizedValue);
    }
}

// OTTIMIZZAZIONE: Fragment shader con supporto per modalità preview e impostazioni di qualità
fragment float4 fragmentShader(VertexOut in [[stage_in]],
                              texture3d<uint, access::sample> volumeTexture [[texture(0)]],
                              constant float4& viewParams [[buffer(0)]],
                              constant uint3& dimensions [[buffer(1)]],
                              constant float3& spacing [[buffer(2)]]) {
    // Definisci un sampler esplicito
    constexpr sampler volumeSampler(filter::linear, address::clamp_to_edge);
    
    float windowCenter = viewParams.x;
    float windowWidth = viewParams.y;
    
    // OTTIMIZZAZIONE: Parametri configurabili
    float maxSteps = viewParams.z > 0 ? viewParams.z : 200.0;     // Passi configurabili
    bool isPreview = viewParams.w > 0.5;                          // Flag per modalità preview
    
    // OTTIMIZZAZIONE: Parametri di rendering adattivi
    float stepSize = isPreview ? 3.0 / maxSteps : 2.0 / maxSteps; // Step più grandi per preview
    float earlyTerminationThreshold = isPreview ? 0.8 : 0.95;     // Termina prima in preview
    
    // OTTIMIZZAZIONE: Origine e direzione del raggio ottimizzati per diverse modalità
    float3 rayOrigin = float3(0, 0, -1.5);
    float3 rayDirection = normalize(float3(in.texCoord * 2.0 - 1.0, 1.0));
    
    // OTTIMIZZAZIONE: Velocizza il preview riducendo la qualità
    if (isPreview) {
        // Usa meno passi e sampling più grossolano nella modalità preview
        maxSteps = min(maxSteps, 100.0);
    }
    
    // Accumula colore e opacità lungo il raggio
    float4 color = float4(0);
    
    // OTTIMIZZAZIONE: Aggiungi offset casuale per evitare banding in modalità preview
    float offset = isPreview ? fract(sin(in.texCoord.x * 1234.5 + in.texCoord.y * 5678.9) * 43758.5453) * stepSize : 0.0;
    
    for (int i = 0; i < maxSteps; i++) {
        float t = offset + float(i) * stepSize;
        float3 pos = rayOrigin + rayDirection * t;
        
        // Mappa la posizione dello spazio del raggio allo spazio della texture (0-1)
        float3 texCoord = pos * 0.5 + 0.5;
        
        // Verifica se siamo dentro il volume
        if (texCoord.x < 0.0 || texCoord.x > 1.0 ||
            texCoord.y < 0.0 || texCoord.y > 1.0 ||
            texCoord.z < 0.0 || texCoord.z > 1.0) {
            continue; // Salta i campioni fuori dal volume
        }
        
        // OTTIMIZZAZIONE: In modalità preview, campiona con un passo più grande
        // Questo simula un downsampling della texture
        if (isPreview && (i % 2 == 0)) {
            continue;
        }
        
        // Campiona il volume
        uint value = volumeTexture.sample(volumeSampler, texCoord).r;
        
        // Applica la funzione di trasferimento
        float4 sampleColor = transferFunction(float(value), windowCenter, windowWidth, isPreview);
        
        // OTTIMIZZAZIONE: In modalità preview, rafforza il contrasto
        if (isPreview) {
            sampleColor.a *= 1.5; // Aumenta l'opacità per una visualizzazione più chiara
            sampleColor.a = min(sampleColor.a, 1.0); // Clamp al massimo 1.0
        }
        
        // Applica composizione front-to-back
        color.rgb += (1.0 - color.a) * sampleColor.a * sampleColor.rgb;
        color.a += (1.0 - color.a) * sampleColor.a;
        
        // Termina anticipatamente se l'opacità è quasi completa
        // Usiamo una soglia diversa in base alla modalità
        if (color.a >= earlyTerminationThreshold) {
            break;
        }
    }
    
    // OTTIMIZZAZIONE: Migliora il contrasto in modalità preview
    if (isPreview) {
        color.rgb = pow(color.rgb, float3(0.8)); // Aumento gamma per maggiore contrasto
    }
    
    return color;
}

// OTTIMIZZAZIONE: Nuovo vertex shader per il rendering di mesh
vertex VertexOut meshVertexShader(uint vertexID [[vertex_id]],
                                 const device float3* positions [[buffer(0)]],
                                 const device float3* normals [[buffer(1)]],
                                 constant float4x4& modelViewProjectionMatrix [[buffer(2)]]) {
    VertexOut out;
    
    // Trasforma la posizione usando la matrice MVP
    out.position = modelViewProjectionMatrix * float4(positions[vertexID], 1.0);
    
    // Passa le coordinate di texture
    // In questo caso semplice, non usiamo realmente le coordinate di texture
    out.texCoord = float2(0.0, 0.0);
    
    return out;
}

// OTTIMIZZAZIONE: Nuovo fragment shader per il rendering di mesh
fragment float4 meshFragmentShader(VertexOut in [[stage_in]],
                                  constant float4& color [[buffer(0)]]) {
    // Rendering base della mesh con colore uniforme
    return color;
}
