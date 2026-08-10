layout(location = 0) out vec4 o_color;

in VS_OUT {
  vec3 world_pos;

  #ifdef HAS_NORMALS
  vec3 normal;
  #endif

  #ifdef HAS_UV0
  vec2 uv0;
  #endif

  #ifdef HAS_TANGENTS
  vec3 tangent;
  #endif
} fs_in;

struct Light {
  vec3 position;

  vec3 ambient;
  vec3 diffuse;
  vec3 specular;

  float constant;
  float linear;
  float quadratic;
};

uniform vec3 u_camera_pos;

uniform sampler2D t_diffuse;
uniform sampler2D t_specular;
uniform float u_shininess;
uniform float u_specular_factor;

void main()
{
  Light light = Light(vec3(-1.5, 0.5, 1), vec3(0.3, 0.3, 0.3), vec3(0.6, 0.6, 0.6), vec3(1.0, 1.0, 1.0), 1.0, 0.09, 0.04);

  // ambient
  vec3 ambient = light.ambient * texture(t_diffuse, fs_in.uv0).rgb;

  // diffuse
  vec3 norm = normalize(fs_in.normal);
  vec3 lightDir = normalize(light.position - fs_in.world_pos);
  float diff = max(dot(norm, lightDir), 0.0);
  vec3 diffuse = light.diffuse * diff * texture(t_diffuse, fs_in.uv0).rgb;

  // specular
  vec3 viewDir = normalize(u_camera_pos - fs_in.world_pos);
  vec3 reflectDir = reflect(-lightDir, norm);
  float spec = pow(max(dot(viewDir, reflectDir), 0.0), u_shininess);
  vec3 specular = light.specular * spec * texture(t_specular, fs_in.uv0).rgb;

  // attenuation
  float distance = length(light.position - fs_in.world_pos);
  float attenuation = 1.0 / (light.constant + light.linear * distance + light.quadratic * (distance * distance));

  ambient *= attenuation;
  diffuse *= attenuation;
  specular *= attenuation;

  vec3 result = ambient + diffuse + specular;
  o_color = vec4(result, 1.0);
}

// layout(location = 0) out vec4 o_color;

// in VS_OUT {
//   vec3 world_pos;

//   #ifdef HAS_NORMALS
//   vec3 normal;
//   #endif

//   #ifdef HAS_UV0
//   vec2 uv0;
//   #endif

//   #ifdef HAS_TANGENTS
//   vec3 tangent;
//   #endif
// } fs_in;

// uniform vec3 u_camera_pos;

// uniform vec3 u_light_pos;
// uniform vec3 u_light_color;
// uniform vec3 u_ambient_color;

// uniform vec4 u_base_color_factor;
// uniform float u_specular_factor;
// uniform float u_shininess;

// #ifdef HAS_UV0
// #ifdef HAS_DIFFUSE
// uniform sampler2D t_diffuse;
// #endif
// #ifdef HAS_SPECULAR
// uniform sampler2D t_specular;
// #endif
// #ifdef HAS_AMBIENT
// uniform sampler2D t_ambient;
// #endif
// #ifdef HAS_EMISSIVE
// uniform sampler2D t_emissive;
// #endif
// #ifdef HAS_OPACITY
// uniform sampler2D t_opacity;
// #endif
// #if defined(HAS_NORMALS) && defined(HAS_TANGENTS) && defined(HAS_NORMAL_MAP)
// uniform sampler2D t_normals;
// #endif
// #endif

// vec3 sampleDiffuse()
// {
//   vec3 color = u_base_color_factor.rgb;

//   #if defined(HAS_UV0) && defined(HAS_DIFFUSE)
//   color *= texture(t_diffuse, fs_in.uv0).rgb;
//   #endif

//   return color;
// }

// float sampleAlpha()
// {
//   float alpha = u_base_color_factor.a;

//   #if defined(HAS_UV0) && defined(HAS_DIFFUSE)
//   alpha *= texture(t_diffuse, fs_in.uv0).a;
//   #endif

//   #if defined(HAS_UV0) && defined(HAS_OPACITY)
//   alpha *= texture(t_opacity, fs_in.uv0).r;
//   #endif

//   return alpha;
// }

// vec3 getNormal()
// {
//   #ifdef HAS_NORMALS
//   vec3 N = normalize(fs_in.normal);

//   #if defined(HAS_UV0) && defined(HAS_TANGENTS) && defined(HAS_NORMAL_MAP)
//   vec3 T = normalize(fs_in.tangent);
//   T = normalize(T - N * dot(N, T));
//   vec3 B = normalize(cross(N, T));
//   mat3 TBN = mat3(T, B, N);

//   vec3 normal_map = texture(t_normals, fs_in.uv0).rgb;
//   normal_map = normal_map * 2.0 - 1.0;

//   N = normalize(TBN * normal_map);
//   #endif

//   return N;
//   #else
//   vec3 dpdx = dFdx(fs_in.world_pos);
//   vec3 dpdy = dFdy(fs_in.world_pos);
//   return normalize(cross(dpdx, dpdy));
//   #endif
// }

// void main()
// {
//   vec3 albedo = sampleDiffuse();
//   float alpha = sampleAlpha();

//   vec3 N = getNormal();
//   vec3 L = normalize(u_light_pos - fs_in.world_pos);
//   vec3 V = normalize(u_camera_pos - fs_in.world_pos);
//   vec3 H = normalize(L + V);

//   float NdotL = max(dot(N, L), 0.0);

//   // Blinn-Phong specular
//   float specular_strength = 0.0;
//   if (NdotL > 0.0) {
//     specular_strength = pow(max(dot(N, H), 0.0), u_shininess);
//   }

//   vec3 ambient = u_ambient_color * albedo;
//   vec3 diffuse = u_light_color * NdotL * albedo;
//   vec3 specular = u_light_color * specular_strength * u_specular_factor;

//   #if defined(HAS_UV0) && defined(HAS_AMBIENT)
//   ambient *= texture(t_ambient, fs_in.uv0).rgb;
//   #endif

//   #if defined(HAS_UV0) && defined(HAS_SPECULAR)
//   specular *= texture(t_specular, fs_in.uv0).rgb;
//   #endif

//   vec3 emissive = vec3(0.0);
//   #if defined(HAS_UV0) && defined(HAS_EMISSIVE)
//   emissive = texture(t_emissive, fs_in.uv0).rgb;
//   #endif

//   vec3 final_color = ambient + diffuse + specular + emissive;

//   final_color = final_color / (final_color + vec3(1.0));
//   final_color = pow(final_color, vec3(1.0 / 2.2));

//   o_color = vec4(final_color, alpha);
// }
