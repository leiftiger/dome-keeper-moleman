extends Node2D

var startTileCoord:Vector2
var targetPos:Vector2

var curDmgWaitTime := 0.0
var curSoundWaitTime := 0.0

var curMiningDrops := []

var tunnels = []
var queueDepth = 0
var queuedOrders = 0
var queuedTargets = {"cur": [], "next": []}
var keeperOwner = null

var TUNNEL = preload("res://content/keeper/keeper59/tunnel/Tunnel.tscn")
var TUNNEL_OFFSET := Vector2(0, -2)

func _ready():
	Style.init(self)

func _exit_tree():

	if queueDepth == 0:
		Data.changeByInt("keeper59.curWorkingTunnelers", -1)

func setTargetPos(pos):
	targetPos = pos
	
	startTileCoord = Level.map.getTileCoord(position)
	
	var dir = (targetPos - position).normalized()
	
	rotation = atan2(dir.y, dir.x)

func getTargetPos():
	return targetPos

func getQueuedTargets():
	return self.queuedTargets["cur"]

func setQueuedTargets(queuedTargets):
	self.queuedTargets = queuedTargets
	self.queuedOrders += 1

func numQueuedOrders():
	return self.queuedOrders

func openTunnels():
	if tunnels.size() > 0:
		var lastTunnel = tunnels.back()

		if is_instance_valid(lastTunnel):
			lastTunnel.updateTunnelVisibility()

	# Tunnels may have been destroyed if they were mined
	for tunnel in tunnels:
		if is_instance_valid(tunnel):
			tunnel.open = true

func handleFinishedDrilling():
	openTunnels()

	var curCoord = Level.map.getTileCoord(global_position)

	for queueData in queuedTargets["cur"]:

		var startCoord = queueData["startCoord"]
		var targetCoord = queueData["targetCoord"]

		if curCoord == startCoord and self.keeperOwner.allowTunneling(startCoord, targetCoord):
			var nextTunneler = keeperOwner.TUNNELER.instance()

			var startPos = Level.map.getTilePos(startCoord) + Level.map.borderSpriteOffset
			var targetPos = Level.map.getTilePos(targetCoord) + Level.map.borderSpriteOffset

			nextTunneler.position = startPos
			nextTunneler.setQueuedTargets({"cur": self.queuedTargets["next"], "next": []})
			nextTunneler.queuedOrders = self.queuedOrders
			nextTunneler.queueDepth = self.queueDepth + 1
			nextTunneler.keeperOwner = self.keeperOwner

			nextTunneler.setTargetPos(targetPos)

			Level.stage.add_child(nextTunneler)

	queue_free()

func generateMiningDrops(tile, tileCoord):

	# NOTE: This function must be an exact equivalent of Map's own drops, otherwise we will impact game difficulty!

	var goalRichness = tile.richness * Data.ofOr("resourcemodifiers.richness." + tile.type, 1.0)
	var drops = floor(goalRichness - 1 + (randi() % 3))
	if tile.type == CONST.IRON:
		if Level.map.isFirstDrop:

			Level.map.isFirstDrop = false
			drops = 2
	var newDelta = Level.map.dropDeltas.get(tile.type, 0) + drops - goalRichness
	if newDelta >= 3:
		drops -= 1
		newDelta -= 1
	elif newDelta <= - 3:
		drops += 1
		newDelta += 1
	Level.map.dropDeltas[tile.type] = newDelta

	if tile.type == CONST.SAND and drops < 3 and GameWorld.gameMode == CONST.MODE_RELICHUNT and GameWorld.difficulty <= 0:

		var sandWithFloating = Data.of("inventory.sand") + Data.of("inventory.floatingsand")
		if Data.of("dome.health") < 350 - 60 * sandWithFloating:
			drops += 1
	if drops < 3 and GameWorld.difficulty * 0.1 < - randf():
		drops += 1

	for i in range(0, drops):
		curMiningDrops.append({
			"damage": ((i+1) / (drops)) * Data.of("keeper59.tunnelMiningDropHealthLossPercent") * tile.max_health,
			"type": tile.type
		})

func _physics_process(delta):

	if GameWorld.paused:
		return

	var dir = (targetPos - global_position).normalized()

	var tileCoord = Level.map.getTileCoord(global_position)

	var targetTileCoord = Level.map.getTileCoord(targetPos)

	var drillDir = (targetTileCoord - startTileCoord).normalized()

	if not Level.map.isRevealed(tileCoord):
		Level.map.revealTile(tileCoord)

	var tile = Level.map.getTile(tileCoord)

	# Reached map edge! Turn back! (hacky)
	if is_instance_valid(tile) and tile.type == CONST.BORDER:
		translate(-dir * Data.of("keeper59.tunnelerTravelSpeed") * delta * 2)

		if tunnels.size() > 0:
			var lastTunnel = tunnels.back()

			tunnels.pop_back()

			lastTunnel.queue_free()

			var lastTunnelTile = Level.map.getTile(Level.map.getTileCoord(lastTunnel.global_position))
			lastTunnelTile.remove_meta("tunnel")

		setTargetPos(Level.map.getTilePos(tileCoord - dir) + Level.map.borderSpriteOffset)

		return

	# Reached target?
	if global_position.distance_to(targetPos) <= delta*Data.of("keeper59.tunnelerTravelSpeed"):

		# Drill until completion
		if is_instance_valid(tile) and tile.has_meta("destructable") and tile.get_meta("destructable"):

			if curDmgWaitTime <= 0:
				curDmgWaitTime = Data.of("keeper59.tunnelerTargetDamageFrequency")
				tile.hit(-drillDir, Data.of("keeper59.tunnelerTargetDamage"))

				$ExcavationSound.play()
			else:
				curDmgWaitTime -= delta
		else:
			handleFinishedDrilling()
	else:
		# Moving
		var isMining = (tileCoord != targetTileCoord and Data.ofOr("keeper59.tunnelMining", false) and is_instance_valid(tile)
			and (tile.type == CONST.IRON or tile.type == CONST.WATER or tile.type == CONST.SAND))

		if tileCoord != startTileCoord:
			if is_instance_valid(tile) and tile.has_meta("destructable") and tile.get_meta("destructable"):

				if tileCoord != targetTileCoord:

					if not tile.has_meta("tunnel"):
						var tunnel = TUNNEL.instance()
						tunnel.global_position = Level.map.getTilePos(tileCoord) + Level.map.borderSpriteOffset + TUNNEL_OFFSET
						tunnel.global_rotation = atan2(dir.y, dir.x)

						tunnel.init()
						Level.map.addTileOverlay(tunnel)
						
						tunnels.append(tunnel)
						
						tile.set_meta("tunnel", tunnel)
						
						if isMining:
							self.generateMiningDrops(tile, tileCoord)

					if curSoundWaitTime <= 0 and not isMining:
						curSoundWaitTime = Data.of("keeper59.tunnelerTravelSoundFrequency")
						$TunnelDrillSound.play()
					else:
						curSoundWaitTime -= delta

					if curDmgWaitTime <= 0:
						curDmgWaitTime = Data.of("keeper59.tunnelerMiningTravelDamageFrequency") if isMining else Data.of("keeper59.tunnelerTravelDamageFrequency")

						tile.hit(-drillDir, Data.of("keeper59.tunnelerMiningTravelDamage") if isMining else Data.of("keeper59.tunnelerTravelDamage"))

						if isMining:
							$TunnelDrillSound.play()
					else:
						curDmgWaitTime -= delta

					if isMining:

						if curMiningDrops.size() > 0:
							var nextMiningDropData = curMiningDrops.front()

							if nextMiningDropData["damage"] <= (tile.max_health - tile.health):

								curMiningDrops.pop_front()

								var drop = Data.DROP_SCENES.get(nextMiningDropData["type"]).instance()
								drop.position = tile.global_position
								drop.rotation = randf() * TAU
								GameWorld.incrementRunStat("resources_mined")

								Level.map.addDrop(drop)

								var tunnel = tile.get_meta("tunnel")

								tunnel.enterTunnel(drop, -dir)
						else:
							Level.map.tileData().set_resource(tileCoord.x, tileCoord.y, Data.TILE_DIRT_START)

							Level.map.tilesByType.get(tile.type, {}).erase(tile)

							tile.type = "dirt"

							# TODO: A better way of removing the resource overlay without having to recreate the entire tile
							Level.map.tiles.erase(tileCoord)

							var oldTileHealth = tile.health
							var oldTunnel = tile.get_meta("tunnel")

							tile.queue_free()

							Level.map.growTile(tileCoord, Data.TILE_DIRT_START)

							var newTile = Level.map.getTile(tileCoord)

							newTile.set_meta("tunnel", oldTunnel)

							# TODO: Fix tile cracks not matching damage!
							newTile.hit(-drillDir, newTile.max_health - 1)
							newTile.health = oldTileHealth
							Level.map.setTileDamage(newTile.max_health, -drillDir, tileCoord)

							for x in range(-1, 1):
								for y in range(-1, 1):
									Level.map.updateBorderSprite(tileCoord.x + x, tileCoord.y + y)

							startTileCoord = tileCoord
			else:
				# Hit an indestructible tile
				handleFinishedDrilling()
				return

		translate(dir * (Data.of("keeper59.tunnelerMiningTravelSpeed") if isMining else Data.of("keeper59.tunnelerTravelSpeed")) * delta)
