extends Node2D

var pointColor :Color
var collisionRadius :float = 8.0
var timeAccum = 0.0
var stepTime = 0.01
var maxStep = 0.1
var iterations = 15

var startPos :Vector2 = Vector2(660,622)
var targetPos = startPos

var count = 1
var spacing = 10

var bounciness = .6
var friction = 0.01

var inflateForce :float = 500
var inflateSpeed :float = 2
var deflateSpeed :float = 2
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

class Point:
	var x :float
	var y :float
	var old_x :float
	var old_y :float
	var mass :float
	var pinned :bool
	var color :Color

	var externalForce :Vector2
	var area2d : Area2D
	var collisionShape :CollisionShape2D

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
			#var acc_x = 0
			#var acc_y = 0
			#estimate new position using verlet integration
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
	var stiffness :float = 1.0
	var inflatable :bool
	func _init(p0,p1,length,stiffness,inflatable):
		self.p0 = p0
		self.p1 = p1
		self.length = length
		self.stiffness = stiffness
		self.inflatable = inflatable
		
	func Update():
		var dx = self.p1.x - self.p0.x
		var dy = self.p1.y - self.p0.y
		var dist = sqrt(dx*dx+dy*dy)
		var diff = self.length - dist
		var percent = (diff / dist) / 2
		percent *= stiffness
		var offset_x = dx * percent
		var offset_y = dy * percent
		
		if !self.p0.pinned:
			self.p0.x -= offset_x
			self.p0.y -= offset_y
		
		if !self.p1.pinned:
			self.p1.x += offset_x
			self.p1.y += offset_y

var points :Array[Point] = [
	#Point.new(577,200,1.0,true),
	#Point.new(577,250,1.0,false),
	#Point.new(577,300,1.0,false),
	#Point.new(577,350,1.0,false),
	#Point.new(577,400,1.0,false)
]

var sticks :Array[Stick] = [
	#Stick.new(points[0],points[1],Distance(points[0],points[1])),
	#Stick.new(points[1],points[2],Distance(points[1],points[2])),
	#Stick.new(points[2],points[3],Distance(points[2],points[3])),
	#Stick.new(points[3],points[4],Distance(points[3],points[4]))
]
	

func Simulate():
	#update all points
	var externalForce :Vector2 = Vector2(0.0,0.0)
	externalForce.y += 300 #gravity
	#externalForce.x += -1
	
	if Input.is_action_pressed("inflate_left"):
		externalForce.x -= 200
	if Input.is_action_pressed("inflate_right"):
		externalForce.x += 200
		
	for i in points.size():
		#TODO: add gradual filling per point, then continue filling rest. (uhh use modulo? floor? idk)
		var pointPercentage = i/float(points.size())
		#print(pointPercentage)
		if pointPercentage < inflatePercentage * clamp(0.2+abs(sin(time*1.5)),0.0,1.0):
			#points[i].color = Color.RED
			points[i].externalForce = externalForce #- Vector2(0,inflateForce)
		else:
			#points[i].color = Color.DARK_RED
			points[i].externalForce = externalForce
		points[i].Update(stepTime)
	
	#update all sticks
	
	for i in sticks.size():
		if sticks[i].inflatable:
			var clampedInflate :float = clamp(inflatePercentage,0.18,1.0)
			if ((i-1)/4.0) as float / (7) > clampedInflate:
				sticks[i].stiffness = 0.05
			else:
				sticks[i].stiffness = .8
		else:
			sticks[i].stiffness = 1.0
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
		stick = Stick.new(points[i],points[i+1],Distance(points[i],points[i+1]),1.0,false)
		sticks.append(stick)

func GenerateGuy():
	var sections = 6
	var distance = 50
	#first section
	points.append(Point.new(startPos.x,startPos.y,1,true))
	points.append(Point.new(startPos.x+distance,startPos.y,1,true))
	points.append(Point.new(startPos.x,startPos.y-distance,1,false))
	points.append(Point.new(startPos.x+distance,startPos.y-distance,1,false))
	
	for i in sections-1:
		points.append(Point.new(startPos.x,startPos.y-distance*(i+1)-distance,1,false))
		points.append(Point.new(startPos.x+distance,startPos.y-distance*(i+1)-distance,1,false))
	for i in sections:
		if(i==0):
			#bottom _
			sticks.append(Stick.new(points[0],points[1],Distance(points[0],points[1]),1.0,false))
		#sides | |
		sticks.append(Stick.new(points[1+i*2],points[3+i*2],Distance(points[1+i*2],points[3+i*2]),0.01,true))
		sticks.append(Stick.new(points[2+i*2],points[0+i*2],Distance(points[2+i*2],points[0+i*2]),0.01,true))
		
		#top _
		sticks.append(Stick.new(points[3+i*2],points[2+i*2],Distance(points[3+i*2],points[2+i*2]),1.0,false))
		#X sticks
		sticks.append(Stick.new(points[0+i*2],points[3+i*2],Distance(points[0+i*2],points[3+i*2]),1.0,true))
		sticks.append(Stick.new(points[1+i*2],points[2+i*2],Distance(points[1+i*2],points[2+i*2]),1.0,true))
	
func _ready():
	#points.append(Point.new(startPos.x,startPos.y,1,false))
	#GenerateRope()
	#points.append(Point.new(startPos.x,startPos.y,1,false))
	GenerateGuy()

	#sticks.append(Stick.new(points[0],points[1],Distance(points[0],points[1])))
	
	for point in points:
		var shape :CircleShape2D = CircleShape2D.new()
		shape.radius = collisionRadius
		var collision = CollisionShape2D.new()
		collision.set_shape(shape)
		point.collisionShape = collision
		
		var area2d = Area2D.new()
		area2d.add_child(collision)
		point.area2d = area2d
		add_child(area2d)

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
		PlacePoint(false)
		print("Placed point at ",points[0].x, ", ",points[0].y)
	if(Input.is_action_just_pressed("shove")):
		PlacePoint(true)
		print("Placed point at ",points[0].x, ", ",points[0].y)
		
	
	timeAccum += delta
	timeAccum = min(timeAccum,maxStep)
	while(timeAccum >= stepTime):
		
		AdjustCollisions()
		print("adjust collision ", points[0].x, ", ",points[0].y)
		Simulate()
		print("simulate ", points[0].x, ", ",points[0].y)
		timeAccum = 0;
	
	
func _draw():
	var colorA = Color(0.93000000715256, 0.23203498125076, 0.1952999830246)
	var colorB = Color(0.36000001430511, 0.05555998906493, 0.05039999634027)
	for stick in sticks:
		var col :Color
		if !stick.inflatable:
			col = Color.PURPLE
		else:
			col = lerp(Color.RED,Color.GREEN,stick.stiffness)
		draw_line(Vector2(stick.p0.x,stick.p0.y),Vector2(stick.p1.x,stick.p1.y),col,collisionRadius*0.5)
		
	for i in points.size() as float:
		var size = collisionRadius
		if i > points.size()-1:
			size = 15
		var colorPercent :float
		colorPercent = i/points.size()
		#print(colorPercent)
		draw_circle(Vector2(points[i].x,points[i].y),size,points[i].color)
	
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
	
	
	
	
	
