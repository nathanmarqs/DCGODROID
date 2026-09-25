// Simplified Additive Particle shader with URP and Built-in support
Shader "Custom/Particles/AdditiveMasked" {
	Properties
	{
		_MainTex("Base (RGB)", 2D) = "white" {}
		_Mask("Culling Mask", 2D) = "white" {}
	}

	SubShader {
		Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" "PreviewType"="Plane" }
		Blend SrcAlpha One
		Cull Off
		Lighting Off
		ZWrite Off

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
			TEXTURE2D(_Mask);
			SAMPLER(sampler_Mask);

			CBUFFER_START(UnityPerMaterial)
				float4 _MainTex_ST;
				float4 _Mask_ST;
			CBUFFER_END

			Varyings vert(Attributes input) {
				Varyings output;
				output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
				output.color = input.color;
				output.uv = input.uv;
				return output;
			}

			half4 frag(Varyings input) : SV_Target {
				half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, TRANSFORM_TEX(input.uv, _MainTex));
				half4 mask = SAMPLE_TEXTURE2D(_Mask, sampler_Mask, TRANSFORM_TEX(input.uv, _Mask));
				return saturate(col * mask * input.color);
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
			TEXTURE2D(_Mask);
			SAMPLER(sampler_Mask);

			CBUFFER_START(UnityPerMaterial)
				float4 _MainTex_ST;
				float4 _Mask_ST;
			CBUFFER_END

			Varyings vert(Attributes input) {
				Varyings output;
				output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
				output.color = input.color;
				output.uv = input.uv;
				return output;
			}

			half4 frag(Varyings input) : SV_Target {
				half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, TRANSFORM_TEX(input.uv, _MainTex));
				half4 mask = SAMPLE_TEXTURE2D(_Mask, sampler_Mask, TRANSFORM_TEX(input.uv, _Mask));
				return saturate(col * mask * input.color);
			}
			ENDHLSL
		}
	}

	SubShader {
		Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" "PreviewType"="Plane" }
		Blend SrcAlpha One
		Cull Off
		Lighting Off
		ZWrite Off

		Pass {
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 2.0
			#include "UnityCG.cginc"

			struct appdata_t {
				float4 vertex : POSITION;
				fixed4 color : COLOR;
				float2 texcoord : TEXCOORD0;
			};

			struct v2f {
				float4 vertex : SV_POSITION;
				fixed4 color : COLOR;
				float2 texcoord : TEXCOORD0;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _Mask;
			float4 _Mask_ST;

			v2f vert (appdata_t v) {
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.color = v.color;
				o.texcoord = v.texcoord;
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				fixed4 col = tex2D(_MainTex, TRANSFORM_TEX(i.texcoord, _MainTex));
				fixed4 mask = tex2D(_Mask, TRANSFORM_TEX(i.texcoord, _Mask));
				return col * mask * i.color;
			}
			ENDCG
		}
	}
}