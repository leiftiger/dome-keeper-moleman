extends Stage

onready  var DomeButton = find_node("DomeButton")

var keeperPhase: = 0
var keeperWait: = 0.0
var domePhase: = 0
var domeWait: = 0.0

var keeper
var dome
var pet

var gadgetId
var keeperId
var domeId
var modeId

var buttonToFocusOnChoicesClosed

func beforeReady():
	GameWorld.prepareCleanData()
	Style.setPalette("1_1")
	Style.init(find_node("Menu"))
	Style.init($CanvasLayer / ChoicePopup)

func hackyMolemanLoading():

	# Force upgrades.yaml to be re-read when playing with the moleman
	# TODO: A less hacky way of achieving this
	if not Data.ofOr("keeper59.maxSpeed", false):
		Data.gameProperties = {}
		Data.upgrades = {}
		Data.gadgets = {}
		Data.orderedUpgradeKeys = []

		Data.templates = {}
		Data._ready()

	var fs = File.new()
	var err = fs.open("res://content/keeper/keeper59/locale/" + TranslationServer.get_locale() + ".csv", File.READ)
	if err != OK:
		err = fs.open("res://content/keeper/keeper59/locale/en_US.csv", File.READ)

		if err != OK:
			return

	var translations = Translation.new()

	while not fs.eof_reached():
		var cols = fs.get_csv_line("\t")

		if cols.size() >= 2:
			translations.add_message(cols[0], cols[1])

	TranslationServer.add_translation(translations)

func beforeStart():
	hackyMolemanLoading()

	Data.applyInitial("laser")
	Data.applyInitial("sword")
	Data.apply("laser.variant", 2)
	Data.apply("laser.speed", 0.3)
	Data.apply("laser.slowdown2", 0.8)
	Data.apply("laser.dps", 20)
	
	Data.apply("lift.carrykeeper", 1)
	
	Data.apply("keeper1.acceleration", 5)
	Data.apply("keeper1.deceleration", 4)
	Data.apply("keeper1.drillStrength", 2)
	Data.apply("keeper1.speedLossPerCarry", 10.0)
	Data.apply("keeper1.slowdownRecovery", 4)
	Data.apply("keeper1.tileKnockback", 20)
	Data.apply("keeper1.tileHitCooldown", 0.35)
	Data.apply("keeper1.maxSpeed", 60)
	Data.apply("keeper1.shakeStr", 0)
	Data.apply("keeper1.shakeper", 0)
	Data.apply("keeper1.shakesec", 0)
	Data.apply("keeper.insidedome", false)
	
	Data.apply("dome.health", 1)
	Data.apply("map.tileBaseHealth", 4)
	Data.apply("map.ironbasehealth", 1)
	Data.apply("map.tileHealthBaseMultiplier", 1)
	Data.apply("map.hardnessMultiplier2", 1.5)
	Data.apply("map.tileHealthMultiplierPerLayer", 2)
	
	$CanvasLayer / ChoicePopup.backgroundHide = $CanvasLayer / ColorRect
	$CanvasLayer / ChoicePopup.visible = true
	$CanvasLayer / ChoicePopup.rect_position.y += $CanvasLayer / ChoicePopup.get_viewport_rect().size.y
	$CanvasLayer / RelichuntPopup.backgroundHide = $CanvasLayer / ColorRect
	$CanvasLayer / RelichuntPopup.visible = true
	$CanvasLayer / RelichuntPopup.rect_position.y = $CanvasLayer / RelichuntPopup.get_viewport_rect().size.y
	$CanvasLayer / PrestigePopup.backgroundHide = $CanvasLayer / ColorRect
	$CanvasLayer / PrestigePopup.visible = true
	$CanvasLayer / PrestigePopup.rect_position.y += $CanvasLayer / PrestigePopup.get_viewport_rect().size.y
	$CanvasLayer / ColonizationPopup.backgroundHide = $CanvasLayer / ColorRect
	$CanvasLayer / ColonizationPopup.visible = true
	$CanvasLayer / ColonizationPopup.rect_position.y += $CanvasLayer / ColonizationPopup.get_viewport_rect().size.y
	$CanvasLayer / ColorRect.visible = true
	$CanvasLayer / ColorRect.modulate.a = 0.0
	
	Level.map = $Map
	Level.stage = self

	GameWorld.unlockElement("keeper59")
	
	if GameWorld.unlockedElements.has(GameWorld.lastDomeId):
		setDome(GameWorld.lastDomeId)
	else :
		setDome("dome1")
	
	if GameWorld.unlockedElements.has(GameWorld.lastGameModeId):
		setMode(GameWorld.lastGameModeId)
	else :
		setMode("relichunt")
	
	if GameWorld.unlockedElements.has(GameWorld.lastKeeperId):
		setKeeper(GameWorld.lastKeeperId)
	else :
		setKeeper("keeper1")
	
	if domeId and GameWorld.unlockedElements.has(GameWorld.lastGadgetId):
		setGadget(GameWorld.lastGadgetId)
	else :
		setGadget("shield")
	
	if GameWorld.unlockedElements.has(GameWorld.lastGameModeId):
		setMode(GameWorld.lastGameModeId)
	else :
		setMode("relichunt")
	
	if GameWorld.unlockedPets.has(GameWorld.lastPetId):
		setPet(GameWorld.lastPetId)
	else :
		setPet("pet0")
	
	

	
	$Map.setTileData(preload("res://stages/loadout/LoadoutTileData.tscn").instance())
	$Map.init()
	
	
	updateMap()
	
	$Map.dig(Vector2( - 7, 3))
	$Map.dig(Vector2( - 6, 3))
	$Map.fill(Vector2( - 11, 2))
	
	InputSystem.grabFocus(find_node("ProceedToSecondStageButton"))

func updateInitialSkin(applyToKeeper: = true):
	var id = GameWorld.lastSkinIds.get(keeperId, "")
	if GameWorld.unlockedSkins.get(keeperId, {}).has(id):
		if applyToKeeper:
			setSkin(id)
		else :
			GameWorld.keeperSkinId = id
	else :
		if applyToKeeper:
			setSkin("skin0")
		else :
			GameWorld.keeperSkinId = "skin0"
	
func updateMap():
	for x in range( - 12, 0):
		for y in range( - 1, 5):
			$Map.revealTile(Vector2(x, y))
	for x in range( - 13, 10):
		for y in range( - 1, 4):
			$Map.updateBorderSprite(x, y)
	for x in range( - 11, - 5):
		for y in range(1, 3):
			$Map.dig(Vector2(x, y))

func beforeEnd():
	Data.clearListeners()

func _process(delta):
	if GameWorld.paused:
		return 
	
	match keeperId:
		"keeper1":processKeeper1(delta)
		"keeper2":processKeeper2(delta)
	
	match domeId:
		"dome1":processDome1(delta)
		"dome2":processDome2(delta)

func updateOptionalButtons():
	var hasPetChoice = GameWorld.unlockedPets.size() > 0
	var hasSkinChoice = GameWorld.unlockedSkins.get(keeperId, []).size() > 0
	
	find_node("PetPlaceholder").visible = not hasPetChoice and hasSkinChoice
	find_node("SkinPlaceholder").visible = hasPetChoice and not hasSkinChoice
	find_node("PetButton").visible = hasPetChoice
	find_node("SkinButton").visible = hasSkinChoice

func processDome1(delta):
	if domeWait > 0.0:
		domeWait -= delta
	else :
		var laser = get_tree().get_nodes_in_group("primaryWeapon").front()
		match domePhase:
			0:
				domeWait = 0.5
				domePhase += 1
			1:
				laser.start()
				domeWait = 0.5
				domePhase += 1
			2:
				laser.move(Vector2( - 1, 0), true)
				laser.action(0, 0, true)
				if laser.position.x < - 73:
					domeWait = 1.0
					domePhase += 1
					laser.move(Vector2(0, 0), true)
			3:
				laser.move(Vector2(0, 0), true)
				laser.action(1, 0, true)
				domeWait = 1.0
				domePhase += 1
			4:
				laser.move(Vector2(1, 0), true)
				if laser.position.x > - 35:
					domeWait = 0.5
					domePhase += 1
					laser.move(Vector2(1, 0), true)
			5:
				laser.move(Vector2(1, 0), true)
				laser.action(0, 0, true)
				if laser.position.x > 25:
					domePhase += 1
					laser.move(Vector2(1, 0), true)
					laser.action(1, 0, true)
			6:
				if laser.position.x > 57:
					laser.move(Vector2(0, - 1), true)
					laser.action(1, 0, true)
					domeWait = 1.0
					domePhase += 1
			7:
				laser.move(Vector2(0, 0), true)
				laser.action(0, 0, true)
				domeWait = 1.0
				domePhase = 2

func processDome2(delta):
	if domeWait > 0.0:
		domeWait -= delta
	else :
		var sword = get_tree().get_nodes_in_group("primaryWeapon").front()
		match domePhase:
			0:
				domeWait = 0.5
				domePhase += 1
			1:
				sword.start()
				domeWait = 0.5
				domePhase += 1
			2:
				sword.move(Vector2( - 1, 0), true)
				sword.action(0, 0, true)
				domeWait = 1.5
				domePhase += 1
			3:
				sword.move(Vector2(1, 0), true)
				sword.action(0, 0, true)
				domeWait = 1.5
				domePhase += 1
			4:
				sword.move(Vector2( - 1, 0), true)
				sword.action(0, 0, true)
				domeWait = 1.5
				domePhase += 1
			5:
				domeWait = 1.2
				domePhase += 1
				sword.move(Vector2(1, 0), true)
			6:
				domeWait = 1.5
				domePhase += 1
				sword.move(Vector2(0, 0), true)
				sword.action(1.0, 0.0, true)
			7:
				domePhase = 2
				sword.action(0.0, 0.0, true)


func processKeeper1(delta):
	if keeperWait > 0.0:
		keeperWait -= delta
	else :
		match keeperPhase:
			0:
				keeperWait = 1.0
				keeperPhase += 1
			1:
				if moveKeeper($KeeperPosition2):
					keeperPhase += 1
			2:
				if moveKeeper($KeeperPosition3):
					keeperWait = 1.0
					keeperPhase += 1
			3:
				keeper.pickupHit()
				keeperWait = 0.2
				keeperPhase += 1
			4:
				keeper.pickupHit()
				keeperWait = 1.0
				keeperPhase += 1
			5:
				if moveKeeper($KeeperPosition4):
					keeperWait = 1.0
					keeperPhase += 1
			6:
				keeper.dropHit()
				keeperWait = 0.2
				keeperPhase += 1
			7:
				keeper.dropHit()
				keeperWait = 1.0
				keeperPhase += 1
			8:
				resetMap()
				keeperWait = 1.0 + randf() * 1.0
				keeperPhase = 1
				$Tween.interpolate_callback(self, 1.0, "clearResources")
				$Tween.start()

func processKeeper2(delta):
	if keeperWait > 0.0:
		keeperWait -= delta
	else :
		match keeperPhase:
			0:
				keeperWait = 1.0
				keeperPhase += 1
			1:
				if moveKeeper($KeeperPosition5):
					keeperPhase += 1
					keeperWait = 1.0
					keeper.move *= 0.0
			2:
				keeper.move *= 0.0
				keeper.ballHold()
				keeperWait = 0.5
				keeperPhase += 1
			3:
				keeper.moveDirectionInput = Vector2(0, 1)
				keeperWait = 0.5
				keeperPhase += 1
			4:
				keeper.ballRelease()
				keeper.moveDirectionInput = Vector2(0, 0)
				keeperWait = 2.0
				keeperPhase += 1
			5:
				if moveKeeper($KeeperPosition6):
					keeperPhase += 1
					keeperWait = 0.5
					keeper.move *= 0.0
			6:
				keeper.collectHold()
				keeperWait = 3.0
				keeperPhase += 1
			7:
				keeper.collectRelease()
				keeperWait = 0.5
				keeperPhase += 1
			8:
				if moveKeeper($KeeperPosition5):
					keeperPhase += 1
					keeperWait = 0.5
					keeper.move *= 0.0
					$Tween.interpolate_callback(keeper, 1.0, "collectHit")
					$Tween.interpolate_callback(keeper, 1.3, "collectHit")
					$Tween.start()
			9:
				if moveKeeper($KeeperPosition7):
					keeperPhase += 1
					keeperWait = 3.0
			10:
				resetMap()
				keeperWait = 1.0 + randf() * 1.0
				keeperPhase = 1
				$Tween.interpolate_callback(self, 1.0, "clearResources")
				$Tween.start()

func resetMap():
	$Map.isFirstDrop = true
	$Map.fill(Vector2( - 11, 0))
	$Map.growTile(Vector2( - 11, 0), 10)
	$Map.fill(Vector2( - 11, 2))
	$Map.growTile(Vector2( - 11, 2), 0)
	$Map.fill(Vector2( - 11, 3))
	$Map.growTile(Vector2( - 11, 3), 10)
	$Map.fill(Vector2( - 11, 4))
	$Map.growTile(Vector2( - 11, 4), 10)

	# This is why the resource tile disappears when reset, so let's fix it while we're at it
	#updateMap()

func clearResources():
	for r in get_tree().get_nodes_in_group("drops"):
		r.shred()

func moveKeeper(posNode)->bool:
	var d = posNode.position - keeper.position
	if d.length() < 4.0:
		keeper.moveDirectionInput *= 0
		return true
	else :
		keeper.moveDirectionInput = (d * 0.1).clamped(1.0)
		return false

func setDome(domeId:String):
	self.domeId = domeId
	GameWorld.lastDomeId = domeId
	find_node("DomeButton").text = tr("upgrades." + domeId + ".title")
	domePhase = 0
	domeWait = 0
	
	if dome:
		dome.queue_free()
		pet = null
	
	Data.unlockGadget(domeId)
	dome = Data.domeScene(domeId).instance()
	Level.dome = dome
	dome.position = find_node("DomePosition").position
	dome.unlockGadget(Data.gadgets.get(gadgetId, {}))
	add_child(dome)
	dome.init()
	Data.unlockGadget(dome.primaryWeapon)
	dome.addWeapon()
	dome.uiRender()
	Level.dome = dome
	
	
	if gadgetId == "orchard":
		setGadget("orchard")
	
	if GameWorld.lastPetId:
		setPet(GameWorld.lastPetId)
	
	updateStartable()

func setKeeper(keeperId:String):
	self.keeperId = keeperId
	GameWorld.lastKeeperId = keeperId
	keeperPhase = 0
	keeperWait = 0
	
	if keeper:
		keeper.queue_free()
	
	updateInitialSkin(false)
	keeper = Data.keeperScene(keeperId).instance()
	Level.keeper = keeper
	keeper.position = find_node("KeeperPosition1").position
	Data.unlockGadget(keeperId)
	add_child(keeper)
	find_node("KeeperButton").text = tr("upgrades." + keeperId + ".title")

	updateStartable()
	updateOptionalButtons()
	if $Map.tileData:
		resetMap()
	clearResources()

func setGadget(gadgetId:String):
	if self.gadgetId:
		dome.removeGadget(Data.gadgets.get(self.gadgetId, {}))
	self.gadgetId = gadgetId
	GameWorld.lastGadgetId = gadgetId
	Data.unlockGadget(gadgetId)
	dome.unlockGadget(Data.gadgets.get(gadgetId, {}))
	find_node("GadgetButton").text = tr("upgrades." + gadgetId + ".title")

	updateStartable()

func setMode(modeId:String):
	self.modeId = modeId
	GameWorld.lastGameModeId = modeId
	find_node("ModeButton").text = tr("upgrades." + modeId + ".title")
	find_node("ModeTop").text = tr("upgrades." + modeId + ".title")
	find_node("ModeBottom").text = tr("upgrades." + modeId + ".desc")
	
	find_node("ModeTextureRect").texture = load("res://content/icons/loadout_" + modeId + ".png")
	find_node("ModeTextureRect").rect_min_size = find_node("ModeTextureRect").texture.get_size() * 4
	
	updateStartable()

func setPet(id:String):
	GameWorld.lastPetId = id
	if pet:
		pet.queue_free()
		pet = null
	
	if id == "pet0" or id == "":
		return 
	
	pet = load("res://content/pets/" + id + "/" + Data.startCaptialized(id) + ".tscn").instance()
	dome.add_child(pet)

func setSkin(id:String):
	keeper.setSkin(id)
	GameWorld.keeperSkinId = id
	GameWorld.lastSkinIds[keeperId] = id

func updateStartable():
	var startable = domeId and gadgetId and modeId and keeperId
	find_node("ProceedToSecondStageButton").disabled = not startable
	
func _on_DomeButton_pressed():
	$CanvasLayer / ChoicePopup.addOptions("dome", ["dome1", "dome2"], domeId, [])
	buttonToFocusOnChoicesClosed = find_node("DomeButton")
	openChoices()

func _on_GadgetButton_pressed():
	var gadgets
	gadgets = ["shield", "repellent", "orchard"]
	$CanvasLayer / ChoicePopup.addOptions("gadget", gadgets, gadgetId)
	buttonToFocusOnChoicesClosed = find_node("GadgetButton")
	openChoices()

func _on_KeeperButton_pressed():
	$CanvasLayer / ChoicePopup.addOptions("keeper", ["keeper1", "keeper2", "keeper59"], keeperId, [])
	buttonToFocusOnChoicesClosed = find_node("KeeperButton")
	openChoices()

func _on_ModeButton_pressed():
	$CanvasLayer / ChoicePopup.addOptions("mode", [CONST.MODE_RELICHUNT, CONST.MODE_PRESTIGE], modeId)
	buttonToFocusOnChoicesClosed = find_node("ModeButton")
	openChoices()

func openChoices():
	Audio.sound("gui_select")
	var popupInput = preload("res://gui/PopupInput.gd").new()
	popupInput.popup = $CanvasLayer / ChoicePopup
	popupInput.integrate(self)
	popupInput.connect("confirmed", popupInput.popup, "select")
	popupInput.connect("onStop", self, "closeChoices", [popupInput])
	popupInput.popup.connect("choice_made", self, "choiceMade", [popupInput])
	popupInput.popup.call_deferred("moveIn")
	buttonToFocusOnChoicesClosed.release_focus()
	GameWorld.pause()
	Audio.muteSounds()

func choiceMade(type:String, choice:String, popupInput):
	closeChoices(popupInput)
	if choice != get(type + "Id"):
		call("set" + type.capitalize(), choice)
	match type:
		"pet":Audio.sound("loadout_pet")
		"skin":Audio.sound("loadout_skin")
		_:Audio.sound("loadout_" + choice)
	popupInput.desintegrate()

func closeChoices(popupInput):
	GameWorld.unpause()
	$CanvasLayer / ChoicePopup.moveOut()
	InputSystem.grabFocus(buttonToFocusOnChoicesClosed)
	Audio.unmuteSounds()
	if popupInput.popup.is_connected("choice_made", self, "choiceMade"):
		popupInput.popup.disconnect("choice_made", self, "choiceMade")

func startRun():
	Audio.sound("gui_loadout_startrun")
	var loadout = Loadout.new(domeId, gadgetId, keeperId, modeId)
	if GameWorld.buildType == CONST.BUILD_TYPE.EXHIBITION:
		loadout.fixedMap("Exhibition")
	
	match modeId:
		CONST.MODE_RELICHUNT:
			loadout.worldModifiers = $CanvasLayer / RelichuntPopup.getWorldModifiers()
		CONST.MODE_PRESTIGE:
			if GameWorld.lastGameModeVariation == CONST.MODE_PRESTIGE_MINER:
				loadout.primaryGadgetId = "orchard"
		CONST.MODE_COLONIZATION:
			pass
	
	StageManager.startStage("stages/landing/landing", [loadout])
	find_node("StartButton").disabled = true

func closeSecondStagePopup(popup):
	GameWorld.unpause()
	popup.moveOut()
	Audio.unmuteSounds()
	InputSystem.grabFocus(find_node("ProceedToSecondStageButton"))

func _on_QuitLoadoutButton_pressed():
	StageManager.startStage("stages/title/title")
	find_node("QuitLoadoutButton").disabled = true

func _on_ProceedToSecondStageButton_pressed():
	match modeId:
		CONST.MODE_RELICHUNT:
			Audio.sound("gui_select")
			var popupInput = preload("res://gui/PopupInput.gd").new()
			popupInput.popup = $CanvasLayer / RelichuntPopup
			popupInput.connect("onStop", self, "closeSecondStagePopup", [popupInput.popup])
			popupInput.integrate(self)
			popupInput.popup.call_deferred("moveIn")
			GameWorld.pause()
			Audio.muteSounds()
		CONST.MODE_PRESTIGE:
			if GameWorld.isUnlocked(CONST.MODE_PRESTIGE_COBALT) or GameWorld.isUnlocked(CONST.MODE_PRESTIGE_COUNTDOWN) or GameWorld.isUnlocked(CONST.MODE_PRESTIGE_MINER):
				Audio.sound("gui_select")
				var popupInput = preload("res://gui/PopupInput.gd").new()
				popupInput.popup = $CanvasLayer / PrestigePopup
				popupInput.connect("onStop", self, "closeSecondStagePopup", [popupInput.popup])
				popupInput.integrate(self)
				popupInput.popup.call_deferred("moveIn")
				GameWorld.pause()
				Audio.muteSounds()
			else :
				startRun()
		CONST.MODE_COLONIZATION:
			Audio.sound("gui_select")
			var popupInput = preload("res://gui/PopupInput.gd").new()
			popupInput.popup = $CanvasLayer / ColonizationPopup
			popupInput.connect("onStop", self, "closeSecondStagePopup", [popupInput.popup])
			popupInput.integrate(self)
			popupInput.popup.call_deferred("moveIn")
			GameWorld.pause()
			Audio.muteSounds()

func _on_PetButton_pressed():
	var options = ["pet0"]
	options.append_array(GameWorld.unlockedPets)
	$CanvasLayer / ChoicePopup.addOptions("pet", options, GameWorld.lastPetId, [])
	buttonToFocusOnChoicesClosed = find_node("PetButton")
	openChoices()

func _on_SkinButton_pressed():
	var options = ["skin0"]
	var lastSkin = GameWorld.lastSkinIds.get(keeper.techId, "")
	var choice = lastSkin if lastSkin else ("skin0")
	options.append_array(GameWorld.unlockedSkins.get(keeper.techId, []))
	$CanvasLayer / ChoicePopup.addOptions("skin", options, choice, [])
	buttonToFocusOnChoicesClosed = find_node("SkinButton")
	openChoices()
