layout(location = 0) in vec3 a_position;

#ifdef HAS_NORMALS
layout(location = 1) in vec3 a_normal;
#endif

#ifdef HAS_UV0
layout(location = 2) in vec2 a_tex_coord;
#endif

#ifdef HAS_TANGENTS
layout(location = 3) in vec3 a_tangent;
#endif

out VS_OUT {
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
} vs_out;

uniform mat4 u_model;
uniform mat4 u_view;
uniform mat4 u_proj;

void main()
{
  vec4 world_position = u_model * vec4(a_position, 1.0);

  vs_out.world_pos = world_position.xyz;

  #ifdef HAS_NORMALS
  mat3 normal_matrix = transpose(inverse(mat3(u_model)));
  vs_out.normal = normalize(normal_matrix * a_normal);
  #endif

  #ifdef HAS_UV0
  vs_out.uv0 = a_tex_coord;
  #endif

  #ifdef HAS_TANGENTS
  vs_out.tangent = normalize(mat3(u_model) * a_tangent);
  #endif

  gl_Position = u_proj * u_view * world_position;
}
