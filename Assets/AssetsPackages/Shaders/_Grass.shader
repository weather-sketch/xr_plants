Shader "MyCustom/_Grass"
{
    Properties
    {
        [Header(Shape)]
        _Height             ("_Height",             Range(0, 0.5))  = 0.07
        _HeightRandom       ("_HeightRandom",       Range(0, 0.5))  = 0.05
        _Width              ("_Width",              Range(0, 0.2))  = 0.002
        _WidthRandom        ("_WidthRandom",        Range(0, 0.2))  = 0.005
        _Forward            ("_Forward",            Range(0, 1))  = 0.02
        _ForwardRandom      ("_ForwardRandom",      Range(0, 0.5))  = 0.05
        _Curl               ("_Curl",               Range(0, 5))    = 3
        _RotationRandom     ("_RotationRandom",     Range(0, 1))    = 0.5
        _BendRandom         ("_BendRandom",         Range(0, 1))    = 0.2
        [Header(Shading)]
        _TopColor           ("_TopColor",           Color)          = (1, 1, 1, 1)
        _BottomColor        ("_BottomColor",        Color)          = (1, 1, 1, 1)
        _ColorVariation     ("_ColorVariation",     Color)          = (1, 1, 1, 1)
        _ColorVariationStep ("_ColorVariationStep", Range(0, 0.05)) = 0.02
        _TranslucentGain    ("_TranslucentGain",    Range(0, 1))    = 0.5
        _SpecularGloss      ("_SpecularGloss",      Float)          = 20
        _SpecularPower      ("_SpecularPower",      Float)          = 1
        [Header(Wind)]
        _WindMap            ("_WindMap",            2D)             = "white" {}
        _WindSpeed          ("_WindSpeed",          Float)          = 1
        _WindStrength       ("_WindStrength",       Float)          = 1
        [Header(Interaction)]
        _Radius             ("_Radius",             Float)          = 1
    }
    
    CGINCLUDE
    #include "UnityCG.cginc"
    #include "AutoLight.cginc"
    #include "Lighting.cginc"
    #pragma multi_compile_fwdbase
    #define GRASS_SEGMENTS 3

    struct appdata
    {
        float4 vertex   : POSITION;
        float3 normal   : NORMAL;
        float4 tangent  : TANGENT;
        float2 uv : TEXCOORD0;
    };

    struct v2g
    {
        float4 vertex   : SV_POSITION;
        float3 normal   : NORMAL;
        float4 tangent  : TANGENT;
        float2 uv       : TEXCOORD0;
    };

    v2g vert (appdata v)
    {
        v2g o;
        o.vertex = v.vertex;
        o.normal = v.normal;
        o.tangent = v.tangent;
        o.uv = v.uv;
        return o;
    }

    struct g2f
    {
        float4 pos                          : SV_POSITION;
        float3 worldNormal                  : NORMAL;
        float2 uv                           : TEXCOORD0;
        float3 worldView                    : TEXCOORD1;
        float variation                     : TEXCOORD2;
        // 添加阴影
        unityShadowCoord4 _ShadowCoord      : TEXCOORD3;
    };

    // Shape
    float _Height;
    float _HeightRandom;

    float _Width;
    float _WidthRandom;

    float _Forward;
    float _ForwardRandom;

    float _RotationRandom;
    float _BendRandom;

    float _Curl;

    // Shading
    float4 _TopColor;
    float4 _BottomColor;
    float4 _ColorVariation;
    float _TranslucentGain;
    float _SpecularGloss;
    float _SpecularPower;
    float _ColorVariationStep;

    // Wind
    sampler2D _WindMap;
    float4 _WindMap_ST;
    float _WindStrength;
    float _WindSpeed;

    // Interaction
    float4 _Position;
    float _Radius;

    // angle: 弧度制的角度
    // axis: 旋转所绕的轴
    // 类似 c# Quaternion.AngleAxis
    float3x3 _angleAxis3x3(float angle, float3 axis)
	{
		float c, s;
		sincos(angle, s, c);

		float t = 1 - c;
		float x = axis.x;
		float y = axis.y;
		float z = axis.z;

		return float3x3(
			t * x * x + c, t * x * y - s * z, t * x * z + s * y,
			t * x * y + s * z, t * y * y + c, t * y * z - s * x,
			t * x * z - s * y, t * y * z + s * x, t * z * z + c
			);
	}

    float _randomValue(float3 pos)
    {
        return frac(sin(dot(pos, float3(12.9898, 78.233, 52.4215)))*43758.5453);
    }

    g2f _vertexOutput(float3 origPos, float3 pos, float3 normal, float2 uv, float3x3 mat)
    {
        g2f o;

        float3 p = mul(mat, pos);
        o.pos = UnityObjectToClipPos(origPos + float4(p, 1));
        o.worldNormal = mul(mat, normal);
        o.uv = uv;
        float3 worldPos = mul(unity_ObjectToWorld, pos).xyz;
        o.worldView = _WorldSpaceLightPos0 - worldPos;
        o.variation = _randomValue(origPos);

        // 解决自阴影的shadow acne问题
        o.pos = UnityApplyLinearShadowBias(o.pos);
        o._ShadowCoord = ComputeScreenPos(o.pos);
        return o;
    }

    [maxvertexcount(GRASS_SEGMENTS * 2 + 1)]
    void geo(triangle v2g IN[3], inout TriangleStream<g2f> triStream)
    {
        g2f o;

        // 每一个顶点的位置都绘制一个三角形
        float3 pos = IN[0].vertex;

        // 定义每个草的模型的切线空间
        float3 normal = IN[0].normal;
        float4 tangent = IN[0].tangent;
        // tangent.w 表示副切线的方向， OpenGL: tangent.w = -1, DX tangent.w = 1;
        float3 bitangent = cross(normal, tangent) * tangent.w;
        float3x3 tangent2World = float3x3(tangent.x, bitangent.x, normal.x,
                                            tangent.y, bitangent.y, normal.y,
                                            tangent.z, bitangent.z, normal.z);
                
        // 随机方向
        float3x3 facingRotationMat = _angleAxis3x3(_randomValue(pos) * 2 * UNITY_PI * _RotationRandom, float3(0, 0, 1));
        float3x3 facingMat = mul(tangent2World, facingRotationMat);

        // 随机弯曲
        float3x3 bendRotationMat = _angleAxis3x3(_randomValue(pos.zxy) * 0.5 * UNITY_PI * _BendRandom, float3(1, 0, 0));
        float3x3 mat = mul(facingMat, bendRotationMat);

        // 添加动画
        float2 windUV = pos.xz * (_WindMap_ST.xy) + _WindMap_ST.zw + _WindSpeed * _Time.x;
        float2 windSample = tex2Dlod(_WindMap, float4(windUV, 0, 0)).rg * _WindStrength;
        float3 wind = normalize(float3(windSample.x, windSample.y, 0));
        float3x3 windRotationMat = _angleAxis3x3(windSample.x * UNITY_PI, wind);
        mat = mul(mat, windRotationMat);

        // 增加草模型的细分
        // 计算高度和宽度
        float height = _Height + _randomValue(pos.xzy) * _HeightRandom;
        float width = _Width + _randomValue(pos.yxz);
        float forward = _Forward + _randomValue(pos.yzx) * _ForwardRandom;

        // 添加交互
        float3 worldPos = mul(unity_ObjectToWorld, pos).xyz;
        float dis = distance(_Position.xyz, worldPos);
        float radius = 1 - saturate(dis / _Radius);
        height = max(height - radius * 0.1, 0.1);
        forward = forward - radius * 3;

        for (int i = 0; i < GRASS_SEGMENTS; ++i)
        {
            float t = i / (float)GRASS_SEGMENTS;
            float h = height * t;
            float w = i == 0 ? width / 1.5 : width * (1- t);
            float f = pow(t, _Curl) * forward;

            float3x3 _mat = i == 0 ? facingMat : mat;
            triStream.Append(_vertexOutput(pos, float3(w, f, h), float3(0, -1, t), float2(0, t), _mat));
            triStream.Append(_vertexOutput(pos, float3(-w, f, h), float3(0, -1, t), float2(1, t), _mat));
        }
        triStream.Append(_vertexOutput(pos, float3(0, forward, height), float3(0, -1, forward), float2(0.5, 1),mat));
    }

    float4 frag (g2f i, float facing : VFACE) : SV_Target
    {
        float3 worldNormal = facing > 0 ? i.worldNormal : -i.worldNormal;
        float3 worldLight = normalize(_WorldSpaceLightPos0);
        float3 worldView = normalize(i.worldView);
        float3 h = normalize(worldLight + worldView);
        float specular = pow(saturate(dot(h, worldNormal)), _SpecularGloss) * _SpecularPower;
                
        float nl = saturate(dot(worldNormal, _WorldSpaceLightPos0) + _TranslucentGain);
        float4 lightColor = nl * _LightColor0 + specular;

        // 添加阴影
        float shadow = saturate(SHADOW_ATTENUATION(i) + 0.2);
        lightColor *= shadow;

        float4 col = lerp(_BottomColor, _TopColor, i.uv.y) * lightColor;
                
        // 添加杂色
        col = lerp(col, _ColorVariation * lightColor, step(i.variation, _ColorVariationStep));
        
        return col;
    }
    ENDCG

    SubShader
    {
        Cull Off

        Pass
        {
            Tags { "RenderType"="Opaque" }

            CGPROGRAM
            #pragma vertex vert
            #pragma geometry geo
            #pragma fragment frag
            ENDCG
        }
        // 添加阴影
        Pass
        {
            Tags {"LightMode"="ShadowCaster"}
            CGPROGRAM
            #pragma vertex vert
            #pragma geometry geo
            #pragma fragment _frag

            float4 _frag (g2f i) : SV_Target
            {
                SHADOW_CASTER_FRAGMENT(i);
            }
            ENDCG
        }
    }
}
