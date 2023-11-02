extends Node2D

var pointColor :Color
var collisionRadius :float = 8.0
var timeAccum = 0.0
var stepTime = 0.01
var maxStep = 0.1
var iterations = 15

var startPos :Vector2 = Vector2(660,650)
var targetPos = startPos

var count = 1
var spacing = 10

var bounciness = .1
var friction = 0.01

var inflateForce :float = 10000
var inflateSpeed :float = 1.0
var deflateSpeed :float = 1.0
var inflatePercentage :float = 0.0
var inflating :bool = false

var time = 0.0

var drawDebugDots :bool = false
var debugDrawPos = []
var debugDrawCol = []

func Distance(p0:Point,p1:Point):
	var dx = p1.x - p0.x
	var dy = p1.y - p0.y
	return sqrt(dx*dx+dy*dy)

func SmoothStep(edge0,edge1,x):
	x = clamp((x-edge0)/ (edge1-edge0),0.0,1.0)
	return x * x * (3.0  - 2.0 * x)
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
	
	var inflatedness :float

	func _init(x,y,mass,pinned):
		self.x = x
		self.y = y
		self.old_x = x
		self.old_y = y
		self.mass = mass
		self.pinned = pinned
		
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
	var inflatable :bool
	var clampLength :bool
	func _init(p0,p1,length,startStiffness,inflatable,clampLength):
		self.p0 = p0
		self.p1 = p1
		self.length = length
		self.startStiffness = startStiffness
		self.stiffness = startStiffness
		self.inflatable = inflatable
		self.clampLength = clampLength
		
	func Update():
		#TODO the movement of the points should be relative to their mass
		var dx = self.p1.x - self.p0.x
		var dy = self.p1.y - self.p0.y
		var dist = sqrt(dx*dx+dy*dy)
		var diff = self.length - dist
		var percent = (diff / dist) / 2
		if diff > 0 or !self.clampLength:
			percent *= stiffness
		var offset_x = dx * percent
		var offset_y = dy * percent
		
		if !self.p0.pinned:
			self.p0.x -= offset_x/p0.mass
			self.p0.y -= offset_y/p0.mass
		
		if !self.p1.pinned:
			self.p1.x += offset_x/p1.mass
			self.p1.y += offset_y/p1.mass

var points :Array[Point] = []

var sticks :Array[Stick] = []

@export var inflateStiffnessMultiplier = 1.5
func Simulate():
	var externalForce :Vector2 = Vector2(0.0,0.0)
	
	if Input.is_action_pressed("inflate_left"):
		externalForce.x -= 2500
	if Input.is_action_pressed("inflate_right"):
		externalForce.x += 2500
	
	
	
	#calculate inflatedness + add inflate force
	for i in points.size():
		var p
		if (i+1)%2==0:
			p = i-1
		else:
			p = i
		var lengthPercent = float(p)/(points.size())
		var softness = 0.8
		points[i].inflatedness = 1-SmoothStep(inflatePercentage, inflatePercentage+softness,lengthPercent+softness)
		#points[i].inflatedness = clamp(points[i].inflatedness,0.0,1.0)
		var inflate = Vector2(0.0,points[i].inflatedness * -inflateForce)
		#todo: add bool for affected by inflate to point
		#TODO: consider adding opposite and equal reaction inflate force to the base, so it's as if the inflate force comes from the base
		if i != 0 and i != 1:
			points[i].externalForce = externalForce + inflate
		points[i].Update(stepTime)
	
	#apply stick stiffness based on average connected point inflatedness
	for i in sticks.size():
		if sticks[i].inflatable:
			var averageInflatedness = (sticks[i].p0.inflatedness + sticks[i].p1.inflatedness) / 2.0
			sticks[i].stiffness = sticks[i].startStiffness
			sticks[i].stiffness = lerp(sticks[i].startStiffness,sticks[i].startStiffness*inflateStiffnessMultiplier,averageInflatedness)
			sticks[i].stiffness = clamp(sticks[i].stiffness,0.0,1.0)
		else:
			sticks[i].stiffness = sticks[i].startStiffness
		sticks[i].Update()
	queue_redraw()

func AdjustCollisions():
	#collisions
	for point in points:
		
		point.area2d.position.x = point.x
		point.area2d.position.y = point.y
		
		var pointPos :Vector2 = Vector2(point.x,point.y)
		var velocity :Vector2 = Vector2(point.x - point.old_x,point.y - point.old_y)
		var bodies = point.area2d.get_overlapping_bodies()
		
		for i in iterations:
			for body in bodies:
				if body.is_in_group("environment"):
					var collisionShape = body.shape_owner_get_shape(0,0)
					var hitPos = Vector2(0,0)
					var bounceVelocity = Vector2(0,0)
					var edgePos = Vector2(0,0)
					
					if collisionShape is CircleShape2D:
						var dist = body.global_position.distance_to(pointPos)
						var scalar :Vector2 = body.scale
						
						var collisionNormal = (pointPos - body.position).normalized()
						hitPos = body.global_position + collisionNormal * (collisionShape.radius * scalar.x + collisionRadius)
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
						
						if abs(dx) > half.x+collisionRadius or abs(dy) > half.y+collisionRadius:
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
							print("INSIDE")
							print(abs(dx)," ",half.x," ", abs(dy)," ",half.y)
							collisionNormal = -collisionNormal
						
						hitPos = boxEdgePoint + (collisionRadius) * (collisionNormal)
						
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


func GenerateRope():
	for i in count:
		var point
		if i == 0:
			point = Point.new(startPos.x,startPos.y + i*spacing,0.2,true)
		else:
			point = Point.new(startPos.x,startPos.y + i*spacing,0.2,false)
		points.append(point)
	for i in count-1:
		var stick
		stick = Stick.new(points[i],points[i+1],Distance(points[i],points[i+1]),1.0,false,false)
		sticks.append(stick)

@export var sections = 8
@export var verticalDistance = 50
@export var horizontalDistance = 50
@export var pointMass = 1.0

@export var sideStiffness = 0
@export var sideClampLength = true

@export var crossbarStiffness = 0.225
@export var crossbarClampLength = true

@export var topStiffness = 0.575
@export var topClampLength = true
func GenerateGuy():
	#first section
	points.append(Point.new(startPos.x,startPos.y,500,false))
	points.append(Point.new(startPos.x+horizontalDistance,startPos.y,500,false))
	points.append(Point.new(startPos.x,startPos.y-verticalDistance,pointMass,false))
	points.append(Point.new(startPos.x+horizontalDistance,startPos.y-verticalDistance,pointMass,false))
	
	for i in sections-1:
		points.append(Point.new(startPos.x,startPos.y-verticalDistance*(i+1)-verticalDistance,pointMass,false))
		points.append(Point.new(startPos.x+horizontalDistance,startPos.y-verticalDistance*(i+1)-verticalDistance,pointMass,false))
	for i in sections:
		if(i==0):
			#bottom _
			sticks.append(Stick.new(points[0],points[1],Distance(points[0],points[1]),1.0,false,true))
		#sides | |
		sticks.append(Stick.new(points[1+i*2],points[3+i*2],Distance(points[1+i*2],points[3+i*2]),sideStiffness,true,sideClampLength))
		sticks.append(Stick.new(points[2+i*2],points[0+i*2],Distance(points[2+i*2],points[0+i*2]),sideStiffness,true,sideClampLength))
		
		#top _
		sticks.append(Stick.new(points[3+i*2],points[2+i*2],Distance(points[3+i*2],points[2+i*2]),topStiffness,true,topClampLength))
		#X sticks
		sticks.append(Stick.new(points[0+i*2],points[3+i*2],Distance(points[0+i*2],points[3+i*2]),crossbarStiffness,false,crossbarClampLength))
		sticks.append(Stick.new(points[1+i*2],points[2+i*2],Distance(points[1+i*2],points[2+i*2]),crossbarStiffness,false,crossbarClampLength))
	

	for point in points:
		var shape :CircleShape2D = CircleShape2D.new()
		shape.radius = collisionRadius
		var collision = CollisionShape2D.new()
		collision.set_shape(shape)
		point.collisionShape = collision
		
		#TODO: get rid of area2Ds when generating new guy
		var area2d = Area2D.new()
		area2d.add_child(collision)
		point.area2d = area2d
		add_child(area2d)
		
		point.gravity = 450

func _ready():
	#points.append(Point.new(startPos.x,startPos.y,1,false))
	#GenerateRope()
	#points.append(Point.new(startPos.x,startPos.y,1,false))
	GenerateGuy()
	GenerateMesh()
	#sticks.append(Stick.new(points[0],points[1],Distance(points[0],points[1])))
	
func _physics_process(delta):
	time+= delta
	#print(sin(time*5))
	targetPos = lerp(targetPos,get_global_mouse_position(),5*delta)
	#inflate
	if inflating:
		inflatePercentage += inflateSpeed * get_process_delta_time()
		inflatePercentage = clamp(inflatePercentage,0.0,1.0)
	else:
		inflatePercentage -= deflateSpeed * get_process_delta_time()
		inflatePercentage = clamp(inflatePercentage,0.0,1.0)
	
	if(Input.is_action_just_pressed("place")):
		points.clear()
		sticks.clear()
		GenerateGuy()
		#PlacePoint(false)
		#print("Placed point at ",points[0].x, ", ",points[0].y)
	if(Input.is_action_just_pressed("shove")):
		pass
		#PlacePoint(true)
		#print("Placed point at ",points[0].x, ", ",points[0].y)
		
	
	timeAccum += delta
	timeAccum = min(timeAccum,maxStep)
	while(timeAccum >= stepTime):
		Simulate()
		
		AdjustCollisions()
		#print("adjust collision ", points[0].x, ", ",points[0].y)
		#print("simulate ", points[0].x, ", ",points[0].y)
		timeAccum = 0;

#TODO: generate mesh2D using SurfaceTool
#create meshInstance and set created mesh
#create material using verlet mesh renderer, and pass vertex indicies to the shader using SurfaceTool.SetCustom use CUSTOMX
#write a shader that takes in
#	a vector 2 array of the point positions in the same order as their coresponding vertex
#	calculates the vertex position of each vert relative to the vertex indicies provided
#	calculates UVs for the mesh
#	EXTRA:
#		shader takes in a float parameter for inflating amount, which it uses to animate a noise wobble effect on the streamers on head

func GenerateMesh():
	var mesh = ArrayMesh.new()
	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	var verts = PackedVector3Array()
	for i in points.size():
		verts.append(Vector3(points[i].x,points[i].y,0))
	var indicies = PackedInt32Array()
	for i in sections*2:
		indicies.append(i*3)
		indicies.append(i*3+1)
		indicies.append(i*3+2)
		indicies.append(i*3+1)
		indicies.append(i*3+2)
		indicies.append(i*3+3)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,surface_array)
	var meshInstance2d = MeshInstance2D.new()
	meshInstance2d.mesh = mesh
	var mat = CanvasItemMaterial.new()
	meshInstance2d.material = mat
	add_child(meshInstance2d)
	
func _draw():
	var colorA = Color(0.93000000715256, 0.23203498125076, 0.1952999830246)
	var colorB = Color(0.36000001430511, 0.05555998906493, 0.05039999634027)
	for stick in sticks:
		var col :Color
		col = lerp(Color.RED,Color.GREEN,stick.stiffness)
		draw_line(Vector2(stick.p0.x,stick.p0.y),Vector2(stick.p1.x,stick.p1.y),col,collisionRadius*0.5)
		
	for i in points.size() as float:
		var size = collisionRadius
		if i > points.size()-1:
			size = 15

		var col = lerp(Color.BLACK,Color.WHITE,points[i].inflatedness)
		draw_circle(Vector2(points[i].x,points[i].y),size,col)
	
	for i in debugDrawPos.size():
		draw_circle(debugDrawPos[i],5,debugDrawCol[i])

func _input(event):
	if Input.is_action_pressed("inflate"):
		inflating = true
		
	elif !Input.is_action_pressed("inflate"):
		inflating = false
	#if Input.is_action_just_pressed("grab"):
		#points[0].pinned = true
		
		#AdjustCollisions()
		#Simulate()
		#AdjustCollisions()
	#else:
		#points[0].pinned = false
