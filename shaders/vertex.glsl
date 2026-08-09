#version 330 core
#extension GL_ARB_explicit_attrib_location : require

layout(location = 0) in vec3 aPos;

uniform float t;

void main()
{
    gl_Position = vec4(aPos.x + t, aPos.y, aPos.z, 1.0);
}
