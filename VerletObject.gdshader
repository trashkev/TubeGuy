shader_type canvas_item;
uniform vec2 pointPos[128];
varying vec2 texUV;
uniform int pointCount;
uniform vec2 tiling = vec2(1.0,1.0);
//get height in points
void vertex(){
	float heightInPoints = (float(pointCount)/2.0);
	VERTEX = pointPos[int(UV.x)+1];
	int maxYindex = (pointCount -2);
	
	if((int(UV.x) % 2) == 0){
		texUV.x = 0.0;
		texUV.y = 1.0-(UV.x/float(maxYindex));
	}else{
		texUV.x = 1.0/tiling.x;
		texUV.y = 1.0-(UV.x-1.0)/float(maxYindex);
	}
	texUV.y *= tiling.y;
}
void fragment() {
	vec4 texColor = texture(TEXTURE,texUV);
	COLOR = texColor;
	// Place fragment code here.
}
