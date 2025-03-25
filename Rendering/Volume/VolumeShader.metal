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

float4 transferFunction(float value, float windowCenter, float windowWidth) {
    // Mappa i valori HU (Hounsfield Units) a colori
    // Questa è una semplice funzione di trasferimento; nell'applicazione reale
    // potresti usare una LUT (Look-Up Table) o una funzione più complessa
    
    float normalizedValue = (value - (windowCenter - windowWidth/2)) / windowWidth;
    normalizedValue = clamp(normalizedValue, 0.0, 1.0);
    
    // Per ora, mappa semplicemente a una scala di grigi
    return float4(normalizedValue, normalizedValue, normalizedValue, normalizedValue);
}

fragment float4 fragmentShader(VertexOut in [[stage_in]],
                                texture3d<uint, access::sample> volumeTexture [[texture(0)]],
                                constant float4& viewParams [[buffer(0)]],
                                constant uint3& dimensions [[buffer(1)]],
                                constant float3& spacing [[buffer(2)]]) {
      // Definisci un sampler esplicito
      constexpr sampler volumeSampler(filter::linear, address::clamp_to_edge);
      
      float windowCenter = viewParams.x;
      float windowWidth = viewParams.y;
      
      // Calcola l'origine e la direzione del raggio in modo più preciso
      float3 rayOrigin = float3(0, 0, -1.5);
      float3 rayDirection = normalize(float3(in.texCoord * 2.0 - 1.0, 1.0));
      
      // Imposta i parametri per il ray casting
      const int maxSteps = 200; // Aumenta per migliorare la qualità
      float stepSize = 2.0 / float(maxSteps);
      
      // Accumula colore e opacità lungo il raggio
      float4 color = float4(0);
      
      for (int i = 0; i < maxSteps; i++) {
          float t = float(i) * stepSize;
          float3 pos = rayOrigin + rayDirection * t;
          
          // Mappa la posizione dello spazio del raggio allo spazio della texture (0-1)
          float3 texCoord = pos * 0.5 + 0.5;
          
          // Verifica se siamo dentro il volume
          if (texCoord.x < 0.0 || texCoord.x > 1.0 ||
              texCoord.y < 0.0 || texCoord.y > 1.0 ||
              texCoord.z < 0.0 || texCoord.z > 1.0) {
              continue; // Salta i campioni fuori dal volume
          }
          
          // Campiona il volume
          uint value = volumeTexture.sample(volumeSampler, texCoord).r;
          
          // Applica la funzione di trasferimento
          float4 sampleColor = transferFunction(float(value), windowCenter, windowWidth);
          
          // Applica composizione front-to-back
          color.rgb += (1.0 - color.a) * sampleColor.a * sampleColor.rgb;
          color.a += (1.0 - color.a) * sampleColor.a;
          
          // Termina anticipatamente se l'opacità è quasi completa
          if (color.a >= 0.95) {
              break;
          }
      }
      
      return color;
  }
