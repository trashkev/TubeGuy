shader_type canvas_item;
uniform vec2 pointPos[128];
uniform int pointCount;
varying vec2 texUV;

uniform vec3 mainColor = vec3(1.0,1.0,1.0);

uniform vec2 tiling = vec2(1.0,1.0);
uniform vec2 offset = vec2(0.0,0.0);
uniform float width = 155.0;
//get height in points
void vertex(){
	int currentVertIndex = int(UV.x);
	int adjustedVertIndex = currentVertIndex;
	float side = -1.0;
	if(currentVertIndex %2 != 0){
		adjustedVertIndex -= 1;
		side = 1.0;
	}
	int currentPointIndex = (adjustedVertIndex/2)+1;
	
	vec2 currentPos = pointPos[currentPointIndex];
	vec2 nextPos = pointPos[currentPointIndex+1];
	vec2 previousPos = pointPos[currentPointIndex-1];
	
	vec2 dirToNext;
	vec2 dirToPrevious;
	vec2 dirOutFromNext;
	vec2 dirOutFromPrevious;
	vec2 dirOut;
	
	if(currentPointIndex == 1){
		dirToNext = normalize(nextPos - currentPos);
		dirOutFromNext = normalize(vec2(dirToNext.y,-dirToNext.x));
		dirOut = dirOutFromNext;
	}else if(currentPointIndex == pointCount){
		dirToPrevious = normalize(previousPos - currentPos);
		dirOutFromPrevious = -normalize(vec2(dirToPrevious.y,-dirToPrevious.x));
		dirOut = dirOutFromPrevious;
	}else{
		dirToNext = normalize(nextPos - currentPos);
		dirOutFromNext = normalize(vec2(dirToNext.y,-dirToNext.x));
		dirToPrevious = normalize(previousPos - currentPos);
		dirOutFromPrevious = -normalize(vec2(dirToPrevious.y,-dirToPrevious.x));
		dirOut = normalize(dirOutFromNext + dirOutFromPrevious);
	}
	VERTEX = pointPos[currentPointIndex] + width * side * dirOut;
	
	//calculate UVs
	if((currentVertIndex % 2) == 0){
		texUV.x = 1.0/tiling.x;
		texUV.y = 1.0-(float(currentPointIndex)/float(pointCount));
	}else{
		texUV.x = 0.0;
		texUV.y = 1.0-(float(currentPointIndex))/float(pointCount);
	}
	
	texUV.y *= tiling.y;
	texUV += offset;
}
void fragment() {
	vec4 texColor = texture(TEXTURE,texUV);
	COLOR = texColor;
	//COLOR = vec4(texUV.x,texUV.y,0.0,1.0);
	// Place fragment code here.
}
