Shader "MyCustom/_Wobble"
{
    Properties
    {
        _FillAmount                     ("_FillAmount",                     Range(0, 1))    = 0.5
        _WobbleX                        ("_WobbleX",                        Range(-45, 45)) = 0           
        _WobbleZ                        ("_WobbleZ",                        Range(-45, 45)) = 0           
        _LiquidColor                    ("_LiquidColor",                    Color)          = (1, 1, 1, 1)
        _LiquidTopColor                 ("_LiquidTopColor",                 Color)          = (1, 1, 1, 1)
        _LiquidFoamHeight               ("_LiquidFoamHeight",               Range(0, 0.1))  = 0.02
        _LiquidFoamColor                ("_LiquidFoamColor",                Color)          = (1, 1, 1, 1)
        _LiquidRimPower                 ("_LiquidRimPower",                 Range(0, 100))  = 10
        _LiquidRimIntensity             ("_LiquidRimIntensity",             Range(0, 100))  = 10
        _LiquidSpecularPower            ("_LiquidSpecularPower",            Range(0, 100))  = 10
        _LiquidSpecularIntensity        ("_LiquidSpecularIntensity",        Range(0, 100))  = 10
        
        _BottleColor                    ("_BottleColor",                    Color)          = (1, 1, 1, 1)
        _BottleThickness                ("_BottleThickness",                Range(0, 0.1))    = 0.05
        _BottleRimPower                 ("_BottleRimPower",                 Range(0, 100))  = 10
        _BottleRimIntensity             ("_BottleRimIntensity",             Range(0, 100))  = 10
        _BottleSpecularPower            ("_BottleSpecularPower",            Range(0, 500))  = 10
        _BottleSpecularIntensity        ("_BottleSpecularIntensity",        Range(0, 100))  = 10
    

    }
    SubShader
    {
        CGINCLUDE
        float _rim(float3 viewDir, float3 normal, float power, float intensity)
        {
            float3 _viewDir = normalize(viewDir);
            float3 _normal = normalize(normal);

            float ndotv = max(0, dot(_normal, _viewDir));
            float rim = pow(ndotv, power) * intensity;
            rim = smoothstep(0.5, 0, rim);
            return rim;
        }

        float _specular(float3 viewDir, float3 lightDir, float3 normal, float power, float intensity)
        {
            float3 _viewDir = normalize(viewDir);
            float3 _lightDir = normalize(lightDir);
            float3 _normal = normalize(normal);

            float3 halfVector = normalize(_lightDir + _viewDir);
            float hdotn = max(0, dot(halfVector, _normal));
            float specular = pow(hdotn, power) * intensity;
            return specular;
        }
        ENDCG

        // 渲染液体
        Pass
        {
            Tags { "RenderType"="Opaque" }

            Blend SrcAlpha OneMinusSrcAlpha
            Cull Off
            AlphaToMask On

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex       : POSITION;
                float2 uv           : TEXCOORD0;
                float3 normal       : NORMAL;
            };

            struct v2f
            {
                float2 uv           : TEXCOORD0;
                float4 vertex       : SV_POSITION;
                float fill          : TEXCOORD1;
                float3 worldViewDir : TEXCOORD2;
                float3 worldNormal  : TEXCOORD3;
            };

            float _FillAmount;

            float _WobbleX;
            float _WobbleZ;

            float _BottleThickness;

            float4 _LiquidColor;
            float4 _LiquidTopColor;

            float _LiquidFoamHeight;
            float4 _LiquidFoamColor;

            float _LiquidRimPower;
            float _LiquidRimIntensity;

            float _LiquidSpecularPower;
            float _LiquidSpecularIntensity;
 
            float2 _rotateAroundAxis(float2 vertex, float degree)
            {
                float sina, cosa;
                float radian = degree * UNITY_PI / 180;
                sincos(radian, sina, cosa);

                float2x2 m = float2x2(cosa, sina, -sina, cosa);
                return mul(m, vertex);
            }

            v2f vert (appdata v)
            {
                v2f o;

                v.vertex.xyz -= _BottleThickness * v.normal;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;

                float4 vertex = v.vertex;
                // 对模型空间内顶点做旋转变换
                // 1. 绕x轴旋转
                vertex.yz = _rotateAroundAxis(vertex.yz, _WobbleX);
                // 2. 绕z轴旋转
                vertex.xy = _rotateAroundAxis(vertex.xy, _WobbleZ);

                //float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz - float3(unity_ObjectToWorld[0][3], unity_ObjectToWorld[1][3], unity_ObjectToWorld[2][3]);
                float3 rWorldPos = mul((float3x3)unity_ObjectToWorld, vertex.xyz);
                o.fill = rWorldPos.y;

                float3 aWorldPos = mul(unity_ObjectToWorld, vertex).xyz;
                o.worldViewDir = UnityWorldSpaceViewDir(aWorldPos);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);

                return o;
            }

            fixed4 frag (v2f i, float facing: VFACE) : SV_Target
            {
                // 1. 液体
                float liquidPart = step(i.fill, _FillAmount);
                float3 liquidColor = liquidPart * _LiquidColor.rgb;

                // 2. 液体和平面的交界处
                float foamPart = liquidPart - step(i.fill, _FillAmount - _LiquidFoamHeight);
                float3 liquidFoamColor = foamPart * _LiquidFoamColor.rgb;

                // 3. rim 边缘光
                float3 rim = _LiquidColor.rgb * _rim(i.worldViewDir, i.worldNormal, _LiquidRimPower, _LiquidRimIntensity);

                // 4. specular 高光
                float3 lightDir = _WorldSpaceLightPos0.xyz;
                float3 worldNormal = lerp(i.worldNormal, -i.worldNormal, facing < 0);
                float3 spec = _LiquidColor.rgb * _specular(i.worldViewDir, lightDir, worldNormal, _LiquidSpecularPower, _LiquidSpecularIntensity);
                //spec = step(0.9, spec);

                float4 finalColor = 1;
                finalColor.rgb = liquidColor + liquidFoamColor + rim;

                // 5. 液体平面
                finalColor.rgb = lerp(finalColor.rgb, _LiquidTopColor.rgb, facing < 0);
                finalColor.rgb += spec;

                finalColor.a = liquidPart;

                return finalColor;
            }
            ENDCG
        }

        // 渲染容器
        Pass
        {
            Tags {"RenderType"="Transparent" "Queue"="Transparent"}
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex       : POSITION;
                float2 uv           : TEXCOORD0;
                float3 normal       : NORMAL;
            };

            struct v2f
            {
                float2 uv           : TEXCOORD0;
                float4 vertex       : SV_POSITION;
                float3 worldViewDir : TEXCOORD1;
                float3 worldNormal  : TEXCOORD2;
            };

            float4 _BottleColor;
            float _BottleRimPower;
            float _BottleRimIntensity;

            float _BottleSpecularPower;
            float _BottleSpecularIntensity;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;

                float3 aWorldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.worldViewDir = UnityWorldSpaceViewDir(aWorldPos);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);

                return o;
            }

            fixed4 frag (v2f i, float facing: VFACE) : SV_Target
            {
                // 1. rim 边缘光
                float3 rim = _BottleColor.rgb * _rim(i.worldViewDir, i.worldNormal, _BottleRimPower, _BottleRimIntensity);

                // 2. specular 高光
                float3 lightDir = _WorldSpaceLightPos0.xyz;
                float3 spec = _BottleColor.rgb * _specular(i.worldViewDir, lightDir, i.worldNormal, _BottleSpecularPower, _BottleSpecularIntensity);
                //spec = step(0.9, spec);

                float4 finalColor = 1;
                finalColor.rgb = _BottleColor.rgb + rim + spec;
                finalColor.a = _BottleColor.a;

                return finalColor;
            }
            ENDCG
        }
    }
}
