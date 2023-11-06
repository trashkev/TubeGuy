extends Node2D

var pointColor :Color

@export_group("Simulation Settings")
@export var timeAccum = 0.0
@export var stepTime = 0.01
@export var maxStep = 0.1
@export var constraintIterations = 20
@export var collisionIterations = 5
@export var bounciness = .1
@export var friction = 0.0
var time = 0.0

@export_group("Object Generation")
@export var startPos :Vector2 = Vector2(500,650)

@export_subgroup("Body")
@export var bodyTexture: Texture2D
@export var bodyMaterial :Material
@export_range(3,30) var bodyPointCount :int = 8
@export_range(10.0,300.0) var bodySpacing :float = 120.0
@export_range(0.0,1.0) var bodyStiffness :float = 1.0
@export_range(0.0,180.0) var bodyMinAngle :float = 50.0
@export_range(0.001,10.0) var bodyPointMass = 1.0
@export var bodyCollisionRadius :float = 8.0


@export_subgroup("Arms")
@export var armsTexture: Texture2D
@export var armsMaterial :Material
@export var armsMaterial2 :Material
@export var armsConnectionPointFromTop = 1
@export_range(3,15) var armsPointCount :int = 4
@export_range(10.0,300.0) var armsSpacing = 50.0
@export_range(0.0,1.0) var armsStiffness = 1.0
@export_range(0.0,180.0) var armsMinAngle = 15.0
@export_range(0.001,10.0) var armsPointMass :float = 1.0
@export var armsCollisionRadius :float = 8.0
@export_range(10.0,600.0) var shoulderDistance :float = 50.0

var quadStripMeshes :Array[QuadStripMesh] = []
var bodyPoints :Array[Point] = []
var arms :Array[Arm] = []
var points :Array[Point] = []
var sticks :Array[Stick] = []

@export_group("Control Settings")
@export var inflateForce :float = 2000
@export var inflateSpeed :float = 1.0
@export var deflateSpeed :float = 1.0
@export var softness = 0.8
var inflatePercentage :float = 0.0
var inflating :bool = false

@export_group("Debug Settings")
@export var drawPointsAndSticks :bool = false
@export var drawAngleConstraintSticks :bool = false
var drawDebugDots :bool = false
var debugDrawPos = []
var debugDrawCol = []

########## UTILITY FUNCTIONS ###########
func Distance(p0:Point,p1:Point):
	var dx = p1.x - p0.x
	var dy = p1.y - p0.y
	return sqrt(dx*dx+dy*dy)

func SmoothStep(edge0,edge1,x):
	x = clamp((x-edge0)/ (edge1-edge0),0.0,1.0)
	return x * x * (3.0  - 2.0 * x)

func PlacePoint(shove :bool):
	var velocity = Vector2(randf_range(-50.0,50.0),randf_range(-50.0,50.0))
	debugDrawPos.clear()
	debugDrawCol.clear()
	for i in points.size():
		points[i].x = get_local_mouse_position().x
		points[i].y = get_local_mouse_position().y
		points[i].old_x = get_local_mouse_position().x
		points[i].old_y = get_local_mouse_position().y
		points[i].area2d.position.x = points[i].x
		points[i].area2d.position.y = points[i].y
		if shove:
			points[i].old_x = points[0].x + velocity.x
			points[i].old_y = points[0].y + velocity.y

########## CLASSES ###########
class Point:
	var x :float
	var y :float
	var old_x :float
	var old_y :float
	var mass :float
	var pinned :bool
	var color :Color
	var gravity :float
	var externalForce :Vector2
	var area2d : Area2D
	var collisionShape :CollisionShape2D
	var collisionRadius :float = 8.0
	
	var inflatedness :float

	func _init(p_x,p_y,p_mass,p_pinned):
		self.x = p_x
		self.y = p_y
		self.old_x = x
		self.old_y = y
		self.mass = p_mass
		self.pinned = p_pinned
		
	func Update(stepTime):

		if(!self.pinned):
			var vel_x = (self.x - self.old_x)
			var vel_y = (self.y - self.old_y)
			
			self.old_x = self.x
			self.old_y = self.y
			
			var acc_x = externalForce.x / self.mass
			var acc_y = externalForce.y / self.mass
			acc_y += gravity
			
			self.x += vel_x + acc_x * stepTime * stepTime
			self.y += vel_y + acc_y * stepTime * stepTime
			
		else:
			self.old_x = self.x
			self.old_y = self.y
		
		#update Area2D position
		self.area2d.position.x = self.x
		self.area2d.position.y = self.y

class Stick:
	
	var p0 :Point
	var p1 :Point
	var length :float
	var startStiffness :float
	var stiffness :float
	var minLength :float
	var maxLength :float
	
	var draw :bool = true
	
	var color :Color = Color.DEEP_PINK
	func _init(p_p0,p_p1,p_length,p_startStiffness,p_minLength,p_maxLength):
		self.p0 = p_p0
		self.p1 = p_p1
		self.length = p_length
		self.startStiffness = p_startStiffness
		self.stiffness = p_startStiffness
		self.minLength = p_minLength
		self.maxLength = p_maxLength
	func Update(iterations:int):
		var dx = self.p1.x - self.p0.x
		var dy = self.p1.y - self.p0.y
		var dist = sqrt(dx*dx+dy*dy)
		
		if dist > maxLength:
			self.length = maxLength
		if dist < minLength:
			self.length = minLength
		
		var diff = self.length - dist
		var percent = (diff / dist) / 2
		
		var useMass :bool
		
		if (dist < maxLength and dist > minLength):
			percent *= stiffness / iterations
			useMass = true
		else:
			useMass = false
		
		var offset_x = dx * percent
		var offset_y = dy * percent
		
		if !self.p0.pinned:
			if useMass:
				self.p0.x -= offset_x / p0.mass
				self.p0.y -= offset_y / p0.mass
			else:
				self.p0.x -= offset_x
				self.p0.y -= offset_y
		if !self.p1.pinned:
			if useMass:
				self.p1.x += offset_x / p1.mass
				self.p1.y += offset_y / p1.mass
			else:
				self.p1.x += offset_x
				self.p1.y += offset_y

class Arm:
	var points :Array[Point] = []
	var bodyConnectionIndex :int
	var startIndex :int

class QuadStripMesh:
	var points : Array[Point]
	var mesh :Mesh
	var material :ShaderMaterial
	var texture :Texture2D
	var meshInstance2d
	func _init(p_points :Array[Point],p_mesh :Mesh,p_material :Material,p_texture :Texture2D):
		self.points = p_points
		self.mesh = p_mesh
		self.material = p_material
		self.texture = p_texture
	func Update():
		var pointPos = [128]
		for i in self.points.size():
			pointPos.append(Vector2(self.points[i].x,self.points[i].y))
		self.material.set_shader_parameter("pointPos",pointPos)
		self.material.set_shader_parameter("pointCount",self.points.size())
	
########### MAIN FUNCTIONS #############
func Simulate():
	var externalForce :Vector2 = Vector2(0.0,0.0)
	
	if Input.is_action_pressed("inflate_left"):
		externalForce.x -= 2500
	if Input.is_action_pressed("inflate_right"):
		externalForce.x += 2500
	#if Input.is_action_pressed("inflate"):
		#externalForce.y -= 2500
	#calculate inflatedness
	for i in bodyPoints.size():
		var p
		#if (i+1)%2==0:
		#	p = i-1
		#else:
		p = i
		var lengthPercent = float(p)/bodyPoints.size()
		
		bodyPoints[i].inflatedness = 1-SmoothStep(inflatePercentage, inflatePercentage+softness,lengthPercent+softness)
	
	#set arm inflatedness by body connection
	for arm in arms:
		for i in arm.points.size():
			arm.points[i].inflatedness = bodyPoints[arm.bodyConnectionIndex].inflatedness
	
	#add inflate force to each point's external force
	for i in points.size():
		var inflate = Vector2(0.0,points[i].inflatedness * -inflateForce)
		#todo: add bool for affected by inflate to point
		#TODO: consider adding opposite and equal reaction inflate force to the base, so it's as if the inflate force comes from the base
		if i != 0 and i != 1:
			points[i].externalForce = externalForce + inflate
		points[i].Update(stepTime)
	
	#update sticks
	for constraintIteration in constraintIterations:
		for i in sticks.size():
			sticks[i].Update(constraintIterations)
	queue_redraw()

func AdjustCollisions():
	#collisions
	for point in points:
		
		point.area2d.position.x = point.x
		point.area2d.position.y = point.y
		
		var pointPos :Vector2 = Vector2(point.x,point.y)
		var velocity :Vector2 = Vector2(point.x - point.old_x,point.y - point.old_y)
		var bodies = point.area2d.get_overlapping_bodies()
		
		for i in collisionIterations:
			for body in bodies:
				if body.is_in_group("environment"):
					var collisionShape = body.shape_owner_get_shape(0,0)
					var hitPos = Vector2(0,0)
					var bounceVelocity = Vector2(0,0)
					var edgePos = Vector2(0,0)
					
					if collisionShape is CircleShape2D:
						var scalar :Vector2 = body.scale
						
						var collisionNormal = (pointPos - body.position).normalized()
						hitPos = body.global_position + collisionNormal * (collisionShape.radius * scalar.x + point.collisionRadius)
						edgePos = body.global_position + collisionNormal * (collisionShape.radius * scalar.x)
						
						var u = velocity.dot(collisionNormal)*collisionNormal
						var w = velocity-u
						bounceVelocity = (1.0 - friction) * w - bounciness * u

					elif collisionShape is RectangleShape2D:
						var localPoint = body.to_local(Vector2(point.x,point.y))
						
						var half :Vector2 = collisionShape.get_size() * 0.5

						var scalar :Vector2 = body.scale
						
						var dx = localPoint.x
						var px = half.x - abs(dx)
						
						var dy = localPoint.y
						var py = half.y - abs(dy)
						
						if abs(dx) > half.x + point.collisionRadius or abs(dy) > half.y + point.collisionRadius:
							return
							
						var boxEdgePoint = Vector2(0,0)
						if px * scalar.x < py * scalar.y:
							var sx = sign(dx)
							boxEdgePoint.x = half.x * sx
							boxEdgePoint.y = dy
						else:
							var sy = sign(dy)
							boxEdgePoint.x = dx
							boxEdgePoint.y = half.y * sy
						
							
						var globalPoint = body.to_global(Vector2(localPoint.x,localPoint.y))
						
						boxEdgePoint = body.to_global(boxEdgePoint)
						
						var collisionNormal = (globalPoint - boxEdgePoint).normalized()
						#if the point is inside the box, flip the collision normal
						if abs(dx) < half.x and abs(dy) < half.y:
							#print("INSIDE")
							#print(abs(dx)," ",half.x," ", abs(dy)," ",half.y)
							collisionNormal = -collisionNormal
						
						hitPos = boxEdgePoint + (point.collisionRadius) * (collisionNormal)
						
						var u = velocity.dot(collisionNormal)*collisionNormal
						var w = velocity-u
						bounceVelocity = (1.0 - friction) * w - bounciness * u
					
					if drawDebugDots:
						debugDrawPos.append(pointPos)
						debugDrawCol.append(Color.RED)
						
					point.x = hitPos.x
					point.y = hitPos.y
					point.old_x = point.x - bounceVelocity.x
					point.old_y = point.y - bounceVelocity.y
						
					if drawDebugDots:
						debugDrawPos.append(edgePos)
						debugDrawCol.append(Color.GREEN)
						debugDrawPos.append(hitPos)
						debugDrawCol.append(Color.BLUE)
						debugDrawPos.append(Vector2(point.old_x,point.old_y))
						debugDrawCol.append(Color.BLUE_VIOLET)	
	queue_redraw()

func SetUpCollisions():
	for n in get_children():
		if n is Area2D:
			remove_child(n)
			n.queue_free()
	for point in points:
		var shape :CircleShape2D = CircleShape2D.new()
		shape.radius = point.collisionRadius
		var collision = CollisionShape2D.new()
		collision.set_shape(shape)
		point.collisionShape = collision
		
		#TODO: get rid of area2Ds when generating new guy
		var area2d = Area2D.new()
		area2d.add_child(collision)
		point.area2d = area2d
		add_child(area2d)
		
		point.gravity = 500

func GenerateRope():
	points.clear()
	sticks.clear()
	for i in bodyPointCount:
		var point
		if i == 0:
			point = Point.new(startPos.x,startPos.y + i*bodySpacing,1.0,true)
		else:
			point = Point.new(startPos.x+ i*bodySpacing,startPos.y ,1.0,false)
		points.append(point)
	for i in bodyPointCount-1:
		var stick
		var a = points[i]
		var b = points[i+1]
		var dist = Distance(a,b)
		stick = Stick.new(a,b,dist,1.0,dist,dist)
		sticks.append(stick)
	
	
	for i in points.size():
		if !(i == 0 or i == points.size()-1):
			CreateAngleConstraint(points[i-1],points[i+1],points[i],bodyMinAngle)

func CreateAngleConstraint(a:Point,b:Point,c:Point,angle:float = 45.0):
	var distBC = Distance(b,c)
	var distAC = Distance(a,c)
	var distAB = Distance(a,b)
	#use law of cosines to find distAB given angle limit
	var distLimit = sqrt(distBC*distBC+distAC*distAC-(2*distBC*distAC*cos(deg_to_rad(angle)))) 
	var angleConstraintStick = Stick.new(a,b,distAB,0.0,distLimit,INF)
	angleConstraintStick.draw = drawAngleConstraintSticks
	angleConstraintStick.color = Color.AQUA
	sticks.append(angleConstraintStick)

func GenerateGuy():
	
	#CLEAR POINTS ARRAYS
	points.clear()
	sticks.clear()
	bodyPoints.clear()
	arms.clear()
	
	#generate body line
	for i in bodyPointCount:
		var point :Point
		if i == 0:
			point = Point.new(startPos.x,startPos.y + i*bodySpacing,1.0,true)
		else:
			point = Point.new(startPos.x+ i*bodySpacing,startPos.y ,1.0,false)
		point.collisionRadius = bodyCollisionRadius
		points.append(point)
		bodyPoints.append(point)
	
	for i in bodyPointCount-1:
		var stick :Stick
		var a = points[i]
		var b = points[i+1]
		var dist = Distance(a,b)
		stick = Stick.new(a,b,dist,bodyStiffness,dist,dist)
		sticks.append(stick)

	for i in points.size():
		if !(i == 0 or i == points.size()-1):
			CreateAngleConstraint(points[i-1],points[i+1],points[i],bodyMinAngle)
	
	#ARMS
	var leftArm = GenerateArm(Vector2(1.0,-1.0))
	var rightArm = GenerateArm(Vector2(1.0,1.0))
	arms.append(leftArm)
	arms.append(rightArm)
	var a = arms[0].points[0]
	var b = arms[1].points[0]
	var dist = Distance(a,b)
	var stick = Stick.new(a,b,dist,1.0,0.0,INF)
	stick.color = Color.PURPLE
	sticks.append(stick)

func GenerateArm(dir :Vector2 = Vector2(1.0,0.0)):
	var arm = Arm.new()
	arm.bodyConnectionIndex = (bodyPointCount - armsConnectionPointFromTop-1)
	arm.startIndex = points.size()
	
	for i in armsPointCount:
		var pointToAdd :Point
		var xPos = points[arm.bodyConnectionIndex].x  + (bodySpacing/2.0)
		var yPos = points[arm.bodyConnectionIndex].y + armsSpacing * i * dir.y + shoulderDistance * dir.y
		pointToAdd = Point.new(xPos,yPos,armsPointMass,false)
		pointToAdd.collisionRadius = armsCollisionRadius
		points.append(pointToAdd)
		arm.points.append(pointToAdd)
	
	#shoulder sticks
	var a = points[arm.bodyConnectionIndex]
	var b = points[arm.bodyConnectionIndex-1]
	var c = arm.points[0]
	
	var ad = bodySpacing/2
	var dc = shoulderDistance
	var shoulderStickLength = sqrt(ad*ad + dc*dc)
	var stick = Stick.new(a,c,shoulderStickLength,1.0,shoulderStickLength,shoulderStickLength)
	stick.color = Color.PURPLE
	sticks.append(stick)
	stick = Stick.new(b,c,shoulderStickLength,1.0,shoulderStickLength,shoulderStickLength)
	stick.color = Color.PURPLE
	sticks.append(stick)
	
	#arm sticks
	for i in armsPointCount-1:
		var dist = Distance(arm.points[i],arm.points[(i+1)])
		stick = Stick.new(arm.points[i],arm.points[(i+1)],dist,armsStiffness,0.0,dist)
		stick.color = Color.YELLOW
		sticks.append(stick)
		
	#arm angle constraints
	for i in arm.points.size():
		if !(i == 0 or i == arm.points.size()-1):
			CreateAngleConstraint(arm.points[i-1],arm.points[i+1],arm.points[i],armsMinAngle)
	return arm

func CreateMeshFromPoints(p_points :Array[Point]):
	var mesh = ArrayMesh.new()
	
	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	
	var verts = PackedVector3Array()
	for i in (p_points.size()*2):
		verts.append(Vector3(0,0,0))
	
	var indicies = PackedInt32Array()
	for i in p_points.size()-1:
		indicies.append(i*2+1)
		indicies.append(i*2)
		indicies.append(i*2+3)

		indicies.append(i*2)
		indicies.append(i*2+2)
		indicies.append(i*2+3)

	surface_array[Mesh.ARRAY_VERTEX] = verts
	surface_array[Mesh.ARRAY_INDEX] = indicies
	
	#STORE EACH VERT'S CORESPONDING POINT IN UV.x
	var vertIndexIndicies :PackedVector2Array = []
	for i in p_points.size()*2:
		vertIndexIndicies.append(Vector2(i,0))
	surface_array[Mesh.ARRAY_TEX_UV] = vertIndexIndicies
	
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,surface_array)
	
	return mesh

func GenerateMeshes():
	#remove all child MeshInstance2Ds
	for n in get_children():
		if n is MeshInstance2D:
			remove_child(n)
			n.queue_free()
	
	#clear quadstripmeshes array
	quadStripMeshes.clear()
	
	#create body mesh
	var bodyMesh = CreateMeshFromPoints(bodyPoints)
	var bodyQuadStripMesh = QuadStripMesh.new(bodyPoints,bodyMesh,bodyMaterial,bodyTexture)
	quadStripMeshes.append(bodyQuadStripMesh)
	
	#create arms Meshes
	for i in arms.size():
		var armMesh = CreateMeshFromPoints(arms[i].points)
		var mat
		if i == 0:
			mat = armsMaterial
		else:
			mat = armsMaterial2
		var armQuadStripMesh = QuadStripMesh.new(arms[i].points,armMesh,mat,armsTexture)
		quadStripMeshes.append(armQuadStripMesh)
		
	#create, setup, and add as child each quadstripmesh's meshInstance2D
	for quadStripMesh in quadStripMeshes:
		quadStripMesh.meshInstance2d = MeshInstance2D.new()
		quadStripMesh.meshInstance2d.texture = quadStripMesh.texture
		quadStripMesh.meshInstance2d.mesh = quadStripMesh.mesh
		quadStripMesh.meshInstance2d.material = quadStripMesh.material
		quadStripMesh.meshInstance2d.z_index = -1
		add_child(quadStripMesh.meshInstance2d)

func UpdateMeshes():
	for quadStripMesh in quadStripMeshes:
		quadStripMesh.Update()

func DrawPointsAndSticks():
	for stick in sticks:
		#var col :Color
		#col = lerp(Color.RED,Color.GREEN,stick.stiffness)
		if stick.draw:
			draw_line(Vector2(stick.p0.x,stick.p0.y),Vector2(stick.p1.x,stick.p1.y),stick.color,5)
	
	for i in points.size() as float:
		var size = points[i].collisionRadius
		if i > points.size()-1:
			size = 15

		var col = lerp(Color.BLACK,Color.WHITE,points[i].inflatedness)
		draw_circle(Vector2(points[i].x,points[i].y),size,col)
	
	for i in points.size():
		if !(i == 0 or i == points.size()-1):
			var dirToNext
			var dirToPrevious
			var currentPos = Vector2(points[i].x,points[i].y)
			var nextPos = Vector2(points[i+1].x,points[i+1].y)
			var previousPos = Vector2(points[i-1].x,points[i-1].y)

			dirToNext = (nextPos - currentPos).normalized()
			dirToPrevious = (previousPos - currentPos).normalized()

			var dirOutFromNext = (Vector2(dirToNext.y,-dirToNext.x)).normalized()
			var dirOutFromPrevious = -(Vector2(dirToPrevious.y,-dirToPrevious.x)).normalized()
			var dirOut = (dirOutFromNext+dirOutFromPrevious).normalized()
			if dirOut == Vector2(0.0,0.0):
				dirOut = dirOutFromNext

			#draw_line(currentPos,currentPos + 15*dirOut,Color.BLUE,5.0)
			#draw_line(currentPos,currentPos + 15*-dirOut,Color.RED,5.0)
				
	for i in debugDrawPos.size():
		draw_circle(debugDrawPos[i],5,debugDrawCol[i])

########### GODOT CALLBACKS ##############
func _ready():
	pass

	GenerateGuy()
	SetUpCollisions()
	GenerateMeshes()

func _physics_process(delta):
	
	time+= delta
	
	if inflating:
		inflatePercentage += inflateSpeed * get_process_delta_time()
		inflatePercentage = clamp(inflatePercentage,0.0,1.0)
	else:
		inflatePercentage -= deflateSpeed * get_process_delta_time()
		inflatePercentage = clamp(inflatePercentage,0.0,1.0)
	
	if(Input.is_action_just_pressed("place")):
		startPos = get_global_mouse_position()
		GenerateGuy()
		SetUpCollisions()
		GenerateMeshes()
	if(Input.is_action_just_pressed("shove")):
		pass
		
	
	timeAccum += delta
	timeAccum = min(timeAccum,maxStep)
	while(timeAccum >= stepTime):
		Simulate()
		
		AdjustCollisions()
		#print("adjust collision ", points[0].x, ", ",points[0].y)
		#print("simulate ", points[0].x, ", ",points[0].y)
		timeAccum = 0;

func _draw():
	UpdateMeshes()
	if(drawPointsAndSticks):
		DrawPointsAndSticks()

func _input(event):
	if Input.is_action_pressed("inflate"):
		inflating = true
		
	elif !Input.is_action_pressed("inflate"):
		inflating = false
	if event:
		pass
	#if Input.is_action_just_pressed("grab"):
		#points[0].pinned = true
		
		#AdjustCollisions()
		#Simulate()
		#AdjustCollisions()
	#else:
		#points[0].pinned = false
