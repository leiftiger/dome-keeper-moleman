extends Node2D

var open = false
var friction := 0.0
var travellers = []
var travellersInTunnel = {}

var vacuumMode := false
var vacuumReverse := false
var vacuumCarryablesLeft := []
var vacuumCarryablesRight := []
var vacuumPatience := {}

var isDetonating := false
var hasDetonated := false
var detonationCountdown := 0.0

const MAX_TUNNEL_LENGTH_CHECK := 10

func _ready():
	Style.init(self)

func tunnelDir():
	var dir := Vector2(cos(rotation), sin(rotation))
	
	# Clamp to int values
	if dir.x > 0.1:
		dir.x = 1
	elif dir.x < -0.1:
		dir.x = -1
	else:
		dir.x = 0

	if dir.y > 0.1:
		dir.y = 1
	elif dir.y < -0.1:
		dir.y = -1
	else:
		dir.y = 0
	
	return dir

func init():
	var tileCoord = Level.map.getTileCoord(position)
	var tunnelDir = self.tunnelDir()

	Level.map.addTileDestroyedListener(self, tileCoord)
	Level.map.addTileDestroyedListener(self, tileCoord - tunnelDir)
	Level.map.addTileDestroyedListener(self, tileCoord + tunnelDir)
	Level.map.addTileRevealedListener(self, tileCoord - tunnelDir)
	Level.map.addTileRevealedListener(self, tileCoord + tunnelDir)
	
	updateTunnelVisibility()
	
	# Tile reveal slightly lags behind for some reason, thus we hide the exit hole pre-emptively
	$RightEntrance.hide()

func tileDestroyed(tileCoord):
	
	var thisTileCoord = Level.map.getTileCoord(global_position)
	
	# Destroyed while in tunnel!
	if thisTileCoord == tileCoord:
		for data in travellers:
			var traveller = data["traveller"]

			if is_instance_valid(traveller):
				if data["keeper"]:
					traveller.setTunnelMode(false)
				else:
					if "mode" in traveller:
						traveller.mode = data["physicsMode"]
					traveller.popPhysicsOverride()

				traveller.collision_layer = data["collision_layer"]
				traveller.collision_mask = data["collision_mask"]

		travellers.clear()

		var tile = Level.map.getTile(thisTileCoord)

		if is_instance_valid(tile):
			tile.clear_meta("tunnel");

		queue_free()
	else:
		updateTunnelVisibility()

func tileRevealed(tileCoord):
	updateTunnelVisibility()
	
func _exit_tree():

	if not Level.map:
		return

	var tileCoord = Level.map.getTileCoord(global_position)
	var tunnelDir = self.tunnelDir()

	Level.map.removeTileDestroyedListener(self, tileCoord)
	Level.map.removeTileDestroyedListener(self, tileCoord - tunnelDir)
	Level.map.removeTileDestroyedListener(self, tileCoord + tunnelDir)
	Level.map.removeTileRevealedListener(self, tileCoord - tunnelDir)
	Level.map.removeTileRevealedListener(self, tileCoord + tunnelDir)
	
func updateTunnelVisibility():
	
	var tileCoord = Level.map.getTileCoord(position)
	var tunnelDir = self.tunnelDir()
	
	var leftTile = Level.map.getTile(tileCoord - tunnelDir)
	var rightTile = Level.map.getTile(tileCoord + tunnelDir)

	if is_instance_valid(leftTile) or Level.map.isRevealed(tileCoord - tunnelDir):
		$LeftEntrance.hide()
	else:
		$LeftEntrance.show()

	if is_instance_valid(rightTile) or Level.map.isRevealed(tileCoord + tunnelDir):
		$RightEntrance.hide()
	else:
		$RightEntrance.show()

func canEnterTunnel(traveller):
	
	if not open:
		return false

	var travellerCoord = Level.map.getTileCoord(traveller.global_position)
	var tileCoord = Level.map.getTileCoord(global_position)
	
	var dir = (tileCoord - travellerCoord).normalized()
	
	return abs(dir.dot(Vector2(cos(global_rotation), sin(global_rotation)))) > 0.9

func enterTunnel(traveller, dir = null):

	if dir == null:
		var travellerCoord = Level.map.getTileCoord(traveller.global_position)
		var tileCoord = Level.map.getTileCoord(global_position)

		dir = (tileCoord - travellerCoord).normalized()

	travellersInTunnel[traveller.get_instance_id()] = true

	var travellerData = {
		"reverse": dir.dot(Vector2(cos(global_rotation), sin(global_rotation))) < 0,
		"traveller": traveller,
		"physicsMode": traveller.mode if "mode" in traveller else null,
		"collision_layer": traveller.collision_layer,
		"collision_mask": traveller.collision_mask,
		"entered": false,
		"keeper": (traveller is Keeper),
	}

	# Disable all collisions to prevent resources from
	# being carried until they've been released from the tunnel
	traveller.collision_layer = 0
	traveller.collision_mask = 0
	traveller.set_collision_layer_bit(CONST.LAYER_BACK_LAYER_COLLISIONS, true)
	traveller.set_collision_mask_bit(CONST.LAYER_BACK_LAYER_COLLISIONS, true)

	if traveller is Keeper:
		traveller.setTunnelMode(true)
	else:
		# We use a physics override and change the physics mode
		# to prevent issues when the game is paused
		var po = CarryablePhysicsOverride.new()
		po.linear_damp = 1000
		po.angular_damp = 1000
		po.gravity_scale = 0

		traveller.addPhysicsOverride(po)

		if "mode" in traveller:
			traveller.mode = RigidBody2D.MODE_STATIC

	travellers.append(travellerData)

func continueTunneling(traveller, fromCoord, prevData):

	var tileCoord = Level.map.getTileCoord(global_position)

	var dir = (tileCoord - fromCoord).normalized()

	travellersInTunnel[traveller.get_instance_id()] = true

	var travellerData = {
		"reverse": dir.dot(Vector2(cos(global_rotation), sin(global_rotation))) < 0,
		"traveller": traveller,
		"physicsMode": prevData["physicsMode"],
		"collision_layer": prevData["collision_layer"],
		"collision_mask": prevData["collision_mask"],
		"entered": true,
		"keeper": (traveller is Keeper),
	}

	if traveller is Keeper:
		traveller.setTunnelMode(true)
	
	travellers.append(travellerData)

func allowObjectToVacuum(carryable):
	if carryable.carryableType == "resource" and (carryable.type == "iron" or carryable.type == "water" or carryable.type == "sand"):
		return true

	return false

func reverseVacuumDirection(propagate = true):
	vacuumMode = !vacuumMode

	if vacuumMode:
		vacuumReverse = !vacuumReverse

		for data in travellers:
			if not data["keeper"]:
				data["reverse"] = !data["reverse"]

	if not propagate:
		return

	var tileCoord = Level.map.getTileCoord(global_position)
	var dir = tunnelDir()

	for i in range(1, MAX_TUNNEL_LENGTH_CHECK):
		var tunnelTile = Level.map.getTile(tileCoord + (dir * i))

		if not is_instance_valid(tunnelTile) or not tunnelTile.has_meta("tunnel"):
			break

		tunnelTile.get_meta("tunnel").reverseVacuumDirection(false)

	for i in range(1, MAX_TUNNEL_LENGTH_CHECK):

		var tunnelTile = Level.map.getTile(tileCoord - (dir * i))

		if not is_instance_valid(tunnelTile) or not tunnelTile.has_meta("tunnel"):
			break

		tunnelTile.get_meta("tunnel").reverseVacuumDirection(false)

func detonate(delay = 0, propagate = true):
	if isDetonating:
		return

	detonationCountdown = delay
	isDetonating = true

	if not propagate:
		return

	var tileCoord = Level.map.getTileCoord(global_position)
	var dir = tunnelDir()

	for i in range(1, MAX_TUNNEL_LENGTH_CHECK):
		var tunnelTile = Level.map.getTile(tileCoord + (dir * i))

		if not is_instance_valid(tunnelTile) or not tunnelTile.has_meta("tunnel"):
			break

		tunnelTile.get_meta("tunnel").detonate(Data.of("keeper59.tunnelDetonationDelay") * i, false)

	for i in range(1, MAX_TUNNEL_LENGTH_CHECK):

		var tunnelTile = Level.map.getTile(tileCoord - (dir * i))

		if not is_instance_valid(tunnelTile) or not tunnelTile.has_meta("tunnel"):
			break

		tunnelTile.get_meta("tunnel").detonate(Data.of("keeper59.tunnelDetonationDelay") * i, false)

func _on_LeftCarryArea_body_entered(carryable):
	if vacuumCarryablesLeft.has(carryable) or not allowObjectToVacuum(carryable):
		return

	vacuumCarryablesLeft.append(carryable)

	vacuumPatience[carryable.get_instance_id()] = 0

func _on_LeftCarryArea_body_exited(carryable):
	vacuumCarryablesLeft.erase(carryable)

	if carryable.get_instance_id() in vacuumPatience:
		vacuumPatience.erase(carryable.get_instance_id())

func _on_RightCarryArea_body_entered(carryable):
	if vacuumCarryablesRight.has(carryable) or not allowObjectToVacuum(carryable):
		return

	vacuumCarryablesRight.append(carryable)

	vacuumPatience[carryable.get_instance_id()] = 0

func _on_RightCarryArea_body_exited(carryable):
	vacuumCarryablesRight.erase(carryable)

	if carryable.get_instance_id() in vacuumPatience:
		vacuumPatience.erase(carryable.get_instance_id())

func _physics_process(delta):

	if GameWorld.paused:

		for data in travellers:
			var traveller = data["traveller"]

			if is_instance_valid(traveller) and not data["keeper"]:
				traveller.set_physics_process(false)

				data["pausePosition"] = traveller.global_position
		return

	if isDetonating and not hasDetonated:

		if detonationCountdown <= 0:
			hasDetonated = true

			var tileCoord = Level.map.getTileCoord(global_position)

			var tile = Level.map.getTile(tileCoord)

			tile.hit(Vector2.ZERO, tile.health)
		else:
			detonationCountdown -= delta

	if open and vacuumMode and Data.ofOr("keeper59.tunnelVacuum", false):

		var entrancePosition = $LeftEntrance/LeftCarryArea.global_position
		var carryables = vacuumCarryablesLeft

		if vacuumReverse:
			entrancePosition = $RightEntrance/RightCarryArea.global_position
			carryables = vacuumCarryablesRight

		for carryObj in carryables:

			var id = carryObj.get_instance_id()

			# Avoid vacuuming objects that are in our tunnel, or carried by the keeper
			if id in travellersInTunnel or carryObj.physicsOverrides.size() > 1:
				continue

			var diffVec = (entrancePosition - carryObj.global_position)

			var sprite = carryObj.find_node("Sprite")
			var size = (max(sprite.get_rect().size.x, sprite.get_rect().size.y)*0.85) + vacuumPatience[id]

			vacuumPatience[id] += Data.of("keeper59.tunnelVacuumPatienceLossPerSec") * delta

			if diffVec.length() < size:
				self.enterTunnel(carryObj)
			else:
				carryObj.apply_central_impulse(diffVec.normalized() * Data.of("keeper59.tunnelVacuumStrength"))

	var travellersToRemove = []

	var tileCoord = Level.map.getTileCoord(global_position)

	friction -= Data.of("keeper59.tunnelFrictionLossPerSec") * delta

	if friction < Data.of("keeper59.tunnelMinFriction"):
		friction = Data.of("keeper59.tunnelMinFriction")

	for i in range(0, travellers.size()):

		var data = travellers[i]

		var traveller = data["traveller"]

		if not is_instance_valid(traveller):
			travellersToRemove.push_front(i)
			continue
		elif not data["keeper"] and traveller.mode != RigidBody2D.MODE_STATIC:
			traveller.mode = RigidBody2D.MODE_STATIC
			traveller.set_physics_process(true)

			if "pausePosition" in data:
				traveller.global_position = data["pausePosition"]
				data.erase("pausePosition")

		var travellerDir = tunnelDir()

		if data["reverse"]:
			travellerDir *= -1

		var travellerCoord = Level.map.getTileCoord(traveller.global_position)

		var travellerSpeed = 0.0
		var centeringSpeed = 0.0
		var travellerDamage = 0.0

		if data["keeper"]:
			travellerSpeed = Data.of("keeper59.tunnelKeeperTravelSpeed")
			centeringSpeed = Data.of("keeper59.tunnelKeeperTravelCenteringSpeed")
			travellerDamage = Data.of("keeper59.tunnelKeeperTravelDamage") * (1.0 - Data.of("keeper59.tunnelKeeperTravelDamageReduction"))
		else:
			travellerSpeed = Data.of("keeper59.tunnelObjectTravelSpeed")
			centeringSpeed = Data.of("keeper59.tunnelObjectTravelCenteringSpeed")
			travellerDamage = Data.of("keeper59.tunnelObjectTravelDamage") * (1.0 - Data.of("keeper59.tunnelObjectTravelDamageReduction"))

		if travellerCoord == tileCoord:
			data["entered"] = true
		elif data["entered"]:

			var tile = Level.map.getTile(tileCoord)

			var otherTile = Level.map.getTile(travellerCoord)

			if is_instance_valid(otherTile) and otherTile.has_meta("tunnel"):
				travellersInTunnel.erase(traveller.get_instance_id())

				otherTile.get_meta("tunnel").continueTunneling(traveller, tileCoord, data)
			else:
				travellersInTunnel.erase(traveller.get_instance_id())

				if data["keeper"]:
					traveller.setTunnelMode(false)
				else:
					if "mode" in traveller:
						traveller.mode = data["physicsMode"]

					traveller.popPhysicsOverride()
					traveller.apply_central_impulse(travellerDir * travellerSpeed)

				traveller.collision_layer = data["collision_layer"]
				traveller.collision_mask = data["collision_mask"]

			travellersToRemove.push_front(i)

			if data["keeper"]:
				travellerDamage *= friction

				# Friction increase is done afterwards so that we always begin from the minimum
				friction += Data.of("keeper59.tunnelKeeperTravelFriction")

				if friction > Data.of("keeper59.tunnelMaxFriction"):
					friction = Data.of("keeper59.tunnelMaxFriction")

			if travellerDamage > 0.01:
				$TunnelDrillSound.play()
				tile.hit(-travellerDir, travellerDamage)
			continue

		traveller.translate(travellerDir * travellerSpeed * delta)

		# Center the traveller to avoid going out-of-bounds
		if abs(travellerDir.x) > 0.9:
			var diffLerp = (self.global_position.y - traveller.global_position.y) * centeringSpeed * delta
			traveller.translate(Vector2(0, diffLerp))
		else:
			var diffLerp = (self.global_position.x - traveller.global_position.x) * centeringSpeed * delta
			traveller.translate(Vector2(diffLerp, 0))

	for i in travellersToRemove:
		travellers.remove(i)
