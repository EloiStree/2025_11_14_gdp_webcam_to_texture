shader_type canvas_item;

uniform sampler2D albedo_tex : source_color;

void fragment() {
    vec4 col = texture(albedo_tex, UV);

    if (col.b < 0.5) {
        float gray = dot(col.rgb, vec3(0.299, 0.587, 0.114));
        col.rgb = vec3(gray);
    }

    COLOR = col;
}
