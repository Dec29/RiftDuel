class_name BagpipeVisual
extends RefCounted

## 风笛专用入口：保留已验收切片对外的常数与调用签名，实际行为由共享适配器
## OperatorSpineVisual 按 OperatorSpineMap 登记的素材执行。
##
## 保留本类是为了让既有验收脚本 tools/test_bagpipe_visual.gd 不改判据即可继续
## 验证风笛这条已验证路线，而不是把风笛另开一套渲染实现。

const SOURCES = [preload("res://assets/operators/bagpipe/front/bagpipe.res"), preload("res://assets/operators/bagpipe/back/bagpipe.res")]
const BODY_HEIGHT = 340.0
const ATTACK_DURATION = 7.0 / 6.0

var visual := OperatorSpineVisual.new()
var mesh: ArrayMesh:
	get:
		return visual.mesh
var texture: Texture2D:
	get:
		return visual.texture
var last_error: String:
	get:
		return visual.last_error
var clip: String:
	get:
		return visual.clip
var view_index: int:
	get:
		return visual.view_index
var pose_seconds: float:
	get:
		return visual.pose_seconds
# 暴露底层实例句柄，供既有验收脚本直接核对原生动画事件队列已排空。
var _instances: Array[int]:
	get:
		return visual._instances


func initialize() -> bool:
	return visual.initialize("bagpipe")


func prepare(unit: UnitState, visual_tick: float, attack_interval_ticks: int) -> bool:
	return visual.prepare(unit, visual_tick, attack_interval_ticks)
