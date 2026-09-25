// This Shader is based on Unity built-in shader source.
// Modified for URP and GPU Instancing.
Shader "taimiso/particle-additive" {
    Properties {
        [HDR] _Color ("Color", Color) = (0.5,0.5,0.5,0.5)
        _MainTex ("Particle Texture", 2D) = "white" {}
        _InvFade ("Soft Particles Factor", Range(0.01,3.0)) = 3.0
        _Glow ("Intensity", Range(0, 127)) = 1
    }
    
    Category {
        Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" "PreviewType"="Plane" }
        Blend SrcAlpha One
        ColorMask RGB
        Cull Off Lighting Off ZWrite Off
        
        SubShader {
            Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" "PreviewType"="Plane" }
            Blend SrcAlpha One
            ColorMask RGB
            Cull Off Lighting Off ZWrite Off

            Pass {
                Name "UniversalForward"
                Tags { "LightMode"="UniversalForward" }

                HLSLPROGRAM
                #pragma vertex vert
                #pragma fragment frag
                #pragma target 2.0
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

                struct Attributes {
                    float4 positionOS : POSITION;
                    half4 color : COLOR;
                    float2 uv : TEXCOORD0;
                };

                struct Varyings {
                    float4 positionCS : SV_POSITION;
                    half4 color : COLOR;
                    float2 uv : TEXCOORD0;
                };

                TEXTURE2D(_MainTex);
                SAMPLER(sampler_MainTex);

                CBUFFER_START(UnityPerMaterial)
                    float4 _MainTex_ST;
                    half4 _Color;
                    float _Glow;
                CBUFFER_END

                Varyings vert(Attributes input) {
                    Varyings output;
                    output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                    output.color = input.color;
                    output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                    return output;
                }

                half4 frag(Varyings input) : SV_Target {
                    half4 tex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                    half glow = max(1.0h, (half)_Glow);
                    half4 col = 2.0h * input.color * _Color * tex * glow;
                    return saturate(col);
                }
                ENDHLSL
            }

            Pass {
                Name "SRPDefaultUnlit"
                Tags { "LightMode"="SRPDefaultUnlit" }

                HLSLPROGRAM
                #pragma vertex vert
                #pragma fragment frag
                #pragma target 2.0
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

                struct Attributes {
                    float4 positionOS : POSITION;
                    half4 color : COLOR;
                    float2 uv : TEXCOORD0;
                };

                struct Varyings {
                    float4 positionCS : SV_POSITION;
                    half4 color : COLOR;
                    float2 uv : TEXCOORD0;
                };

                TEXTURE2D(_MainTex);
                SAMPLER(sampler_MainTex);

                CBUFFER_START(UnityPerMaterial)
                    float4 _MainTex_ST;
                    half4 _Color;
                    float _Glow;
                CBUFFER_END

                Varyings vert(Attributes input) {
                    Varyings output;
                    output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                    output.color = input.color;
                    output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                    return output;
                }

                half4 frag(Varyings input) : SV_Target {
                    half4 tex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                    half glow = max(1.0h, (half)_Glow);
                    half4 col = 2.0h * input.color * _Color * tex * glow;
                    return saturate(col);
                }
                ENDHLSL
            }
        }

        SubShader {
            Pass {
                CGPROGRAM
                #pragma vertex vert
                #pragma fragment frag
                #pragma target 2.0
                #pragma multi_compile_particles
                #pragma multi_compile_fog
                
                #include "UnityCG.cginc"
                #pragma multi_compile_instancing
                
                struct appdata_t {
                    float4 vertex : POSITION;
                    UNITY_VERTEX_INPUT_INSTANCE_ID
                    fixed4 color : COLOR;
                    float2 texcoord : TEXCOORD0;
                };
                
                struct v2f {
                    float4 vertex : SV_POSITION;
                    fixed4 color : COLOR;
                    float2 texcoord : TEXCOORD0;
                    UNITY_FOG_COORDS(1)
                    #ifdef SOFTPARTICLES_ON
                        float4 projPos : TEXCOORD2;
                    #endif
                    UNITY_VERTEX_OUTPUT_STEREO
                };
                
                uniform sampler2D _MainTex; float4 _MainTex_ST;
                UNITY_INSTANCING_BUFFER_START(DI_ParticleIntensify)
                UNITY_DEFINE_INSTANCED_PROP(float4, _Color)
                #define _Color_arr DI_ParticleIntensify
                UNITY_DEFINE_INSTANCED_PROP(float, _InvFade)
                #define _InvFade_arr DI_ParticleIntensify
                UNITY_DEFINE_INSTANCED_PROP(float, _Glow)
                #define _Glow_arr DI_ParticleIntensify
                UNITY_INSTANCING_BUFFER_END(DI_ParticleIntensify)
                
                v2f vert (appdata_t v)
                {
                    v2f o;
                    UNITY_SETUP_INSTANCE_ID(v);
                    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                    o.vertex = UnityObjectToClipPos(v.vertex);
                    #ifdef SOFTPARTICLES_ON
                        o.projPos = ComputeScreenPos (o.vertex);
                        COMPUTE_EYEDEPTH(o.projPos.z);
                    #endif
                    o.color = v.color;
                    o.texcoord = TRANSFORM_TEX(v.texcoord,_MainTex);
                    UNITY_TRANSFER_FOG(o,o.vertex);
                    return o;
                }
                
                sampler2D_float _CameraDepthTexture;
                
                fixed4 frag (v2f i) : SV_Target
                {
                    #ifdef SOFTPARTICLES_ON
                        float sceneZ = LinearEyeDepth (SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.projPos)));
                        float partZ = i.projPos.z;
                        float fade = saturate (_InvFade * (sceneZ-partZ));
                        i.color.a *= fade;
                    #endif
                    
                    half4 col = 2.0f * i.color * UNITY_ACCESS_INSTANCED_PROP(_Color_arr, _Color) * tex2D(_MainTex, i.texcoord);
                    UNITY_APPLY_FOG_COLOR(i.fogCoord, col, fixed4(0,0,0,0));
                    col.rgb *= UNITY_ACCESS_INSTANCED_PROP(_Glow_arr, _Glow);
                    return col;
                }
                ENDCG
            }
        }
    }
}