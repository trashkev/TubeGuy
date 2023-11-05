shader_type canvas_item;
uniform vec2 pointPos[128];
varying vec2 texUV;

uniform int bodyVertCount;
uniform int armsVertCount;

uniform int leftArmConnectionIndex;
uniform int rightArmConnectionIndex;
uniform vec2 tiling = vec2(1.0,1.0);
//get height in points
void vertex(){
	int currentVertIndex = int(UV.x);
	if (currentVertIndex < bodyVertCount-1){
		VERTEX = pointPos[currentVertIndex+1];
		int maxYindex = (bodyVertCount -2);
		if((currentVertIndex % 2) == 0){
			texUV.x = 0.0;
			texUV.y = 1.0-(float(currentVertIndex)/float(maxYindex));
		}else{
			texUV.x = 1.0/tiling.x;
			texUV.y = 1.0-(float(currentVertIndex)-1.0)/float(maxYindex);
		}
	}else{
		//ARM
		//calculate the forward and back directions from our current point index
		VERTEX = pointPos[currentVertIndex+1];
		//calculate the "middle" direction
		//position the point relative to the current point and middle direction * up or down direction
	}
	
	texUV.y *= tiling.y;
}
void fragment() {
	vec4 texColor = texture(TEXTURE,texUV);
	COLOR = texColor;
	// Place fragment code here.
}
