extends Node2D

signal on_show

var center:Vector2
var sound
var tileCoord:Vector2

func _ready():
	hide()
	
	Style.init($Sprite)
