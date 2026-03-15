
extends Node
class_name 文本引擎
##以下是后期内置的封装函数,可更改
var 对话界面:Control
var 对话面板:Panel
var 文本控件:RichTextLabel
var 角色名称控件:RichTextLabel
var 菜单控件: VBoxContainer
var 背景控件:Control
const 对齐={
	居中=Control.PRESET_CENTER,
	全屏=Control.PRESET_FULL_RECT,
	左上=Control.PRESET_TOP_LEFT,
	右上=Control.PRESET_TOP_RIGHT,
	左下=Control.PRESET_BOTTOM_LEFT,
	右下=Control.PRESET_BOTTOM_RIGHT,
	左中=Control.PRESET_CENTER_LEFT,
	上中=Control.PRESET_CENTER_TOP,
	右中=Control.PRESET_CENTER_RIGHT,
	下中=Control.PRESET_CENTER_BOTTOM,
	}

#颜色

func c_红色(文本: String) -> String:
	return "[color=#FF0000]"+文本+"[/color]"

#@onready var 文本控件:RichTextLabel=$"文本内容"
#@onready var 角色名称控件:RichTextLabel=$"角色名称2"
#@onready var 菜单控件: VBoxContainer = $菜单
func 初始化(_对话界面:Control,_对话面板:Panel,_文本控件:RichTextLabel,_角色名称控件:RichTextLabel,_菜单控件: VBoxContainer,_背景控件:Control):
	对话界面=_对话界面
	对话面板=_对话面板
	文本控件=_文本控件
	角色名称控件=_角色名称控件
	菜单控件=_菜单控件
	背景控件=_背景控件
	##按钮 选项0 ,选项项1..到6 一共7个 最大支持
	_对话界面.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton:
			if event.pressed:
				self.更新文本.emit()
				引擎.调试.打印("触发")
		pass
		)
	pass

signal 菜单选择

signal 更新文本
func 文本(名称,...文本:Array):
	隐藏菜单()
	显示对话()
	角色名称控件.text=名称
	var _文本=""
	for i in 文本:
		_文本+=i
	文本控件.text=_文本
	await 更新文本
	pass

##按钮 选项0 ,选项项1..到6 一共7个 最大支持

	
func 隐藏对话():
	文本控件.hide()
	角色名称控件.hide()
	对话面板.hide()
	pass
func 显示对话():
	文本控件.show()
	角色名称控件.show()
	对话面板.show()
	pass


func 隐藏菜单():
	for 按钮 in 菜单控件.get_children():
		if 按钮 is Button:
			按钮.hide()
var 菜单目录=[]
func 菜单(...菜单选项:Array):
	#if 信号连接==false:
		#信号连接=true
		#
	#菜单标签=菜单选项[0]
	隐藏菜单()
	var u=0
	var s=菜单选项.size()
	for 按钮 in 菜单控件.get_children():
		if 按钮 is Button:
			if u<s:
				按钮.show()
				按钮.text=菜单选项[u]
				
				u+=1
				
				var 菜单按钮=菜单控件.get_node("选项"+str(u-1))
				菜单按钮.connect("pressed",触发.bind(菜单选项[u-1]))
				
		
	pass
	
func 触发(选项):
	#print(选项)
	if 选项 in self:
		call(选项)

#默认可使用res://images 图片
func 画(标签:String,图片:String,位置:int=对齐.全屏):
	
	if 图片.find("res://images/")==-1:
		图片="res://images/"+图片
	
	var 预图片=图片
	#当没有格式时,自动填充
	if not 图片.ends_with(".png") or  not 图片.ends_with(".jpg") or not 图片.ends_with(".dds") :
		if FileAccess.file_exists(预图片 + ".png"):
			图片 += ".png"
		elif FileAccess.file_exists(预图片 + ".jpg"):
			图片 += ".jpg"
		elif FileAccess.file_exists(预图片 + ".dds"):
			图片 += ".dds"
	print(背景控件.get_node(标签),is_instance_valid(背景控件.get_node(标签)),图片)
	var 标签节点=背景控件.get_node(标签)
	if is_instance_valid(标签节点):
		标签节点.free()
	#if is_instance_valid(标签节点)==false:
		#if has_node()
	var _图片:=TextureRect.new()
	
	_图片.name=标签
	_图片.texture=load(图片)
	
	
	#_图片.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	#_图片.stretch_mode=TextureRect.STRETCH_SCALE
	if 位置==对齐.全屏:
		_图片.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		_图片.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		_图片.set("layout_mode",1)
		_图片.set_anchors_and_offsets_preset(位置)

	背景控件.add_child(_图片)
	#else:
		#
		#标签节点.texture=load(图片)
	#pass
#signal 清理信号
func 清():
	for b in 背景控件.get_children():
		b.free()
	#await 清理信号
func 结束对话():
	var 面板=引擎.对象.获取父对象(对话界面)
	面板.queue_free()
	pass
