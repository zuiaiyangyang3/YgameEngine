extends Node

# 放置对战核心类（纯字典版）
class 放置对战 extends Node:
	# 舞台速度
	var 舞台速度 = 1.0 
	var 数据={} #可用于自定义数据存放
	# 角色数据：直接用字典（不再用自定义类）
	var 我方数据: Dictionary = {}
	var 敌方数据: Dictionary = {}
	
	# 存储回调的字典对象
	var 回调对象: Dictionary = {}
	
	# 战斗状态标记
	var 战斗已结束 = false
	
	# 暂停核心变量
	var 战斗已暂停 = false
	
	signal 恢复信号
	signal 暂停信号
	# 初始化角色数据（封装默认值，统一管理）
	func _创建角色数据(数据字典: Dictionary = {}) -> Dictionary:
		var 角色数据 = {
			"ID": 1000,
			"速度": 1.0,
			"可攻击": true,
			"生命值": 100.0,
			"攻击力": 10.0,
			"距离": 1.0
		}
		for 键 in 数据字典:
			角色数据[键] = 数据字典[键]
		return 角色数据
	
	func _init(我方初始数据: Dictionary, 敌方初始数据: Dictionary, 舞台的速度:float=1.0) -> void:
		self.我方数据 = _创建角色数据(我方初始数据)
		self.敌方数据 = _创建角色数据(敌方初始数据)
		self.舞台速度 = 舞台的速度
		引擎.调试.打印("1V1战斗舞台已启动")
	
	func 回调(封包函数: Callable):
		var 对象 = {}
		封包函数.call(self.我方数据, self.敌方数据, 对象)
		self.回调对象 = 对象
		self.开始()
	
	func 开始():
		战斗已结束 = false
		战斗已暂停 = false
		启动攻击循环("我方")
		启动攻击循环("敌方")
	
	func 启动攻击循环(阵营: String):
		_攻击循环协程(阵营)
	
	func _攻击循环协程(阵营: String):
		# 移除协程启动的0.01秒延迟（核心误差源1）
		# await 引擎.场景.等待(0.01)
		while not 战斗已结束:
			# 暂停检测
			while 战斗已暂停 and not 战斗已结束:
				await 恢复信号
			
			var 己方数据 = 我方数据 if 阵营 == "我方" else 敌方数据
			var 对方数据 = 敌方数据 if 阵营 == "我方" else 我方数据
			var 攻击回调 = 回调对象.get("我攻击回调") if 阵营 == "我方" else 回调对象.get("敌方攻击回调")
			
			if not 己方数据["可攻击"]:
				await 引擎.场景.等待(0.1)
				continue
			
			print("开始时间", Time.get_datetime_string_from_system())
			var 当前速度 = max(己方数据["速度"], 0.1)
			var 攻击间隔 = 舞台速度 / 当前速度
			print("理论攻击间隔", 攻击间隔)
			
			# 冷却回调
			var 冷却回调 = 回调对象.get("冷却时间回调")
			if 冷却回调 != null:
				冷却回调.call(阵营, 攻击间隔)
			
			# ===== 核心修复：用时间戳精准等待，替代循环累加 =====
			var 目标等待结束时间 = Time.get_unix_time_from_system() + 攻击间隔
			var 实际等待时长 = 0.0
			
			while Time.get_unix_time_from_system() < 目标等待结束时间 and not 战斗已结束:
				# 暂停时冻结目标结束时间（补偿暂停时长）
				while 战斗已暂停 and not 战斗已结束:
					var 暂停开始时间 = Time.get_unix_time_from_system()
					await 恢复信号
					var 暂停时长 = Time.get_unix_time_from_system() - 暂停开始时间
					目标等待结束时间 += 暂停时长  # 补偿暂停时间
				
				# 每帧检测，避免占用过多性能
				#await get_tree().process_frame
				await 引擎.场景.等待(0.001)
			# 计算实际等待时长（调试用）
			实际等待时长 = Time.get_unix_time_from_system() - (目标等待结束时间 - 攻击间隔)
			print("实际等待时长", 实际等待时长)
			print("结束时间", Time.get_datetime_string_from_system())
			
			if 战斗已结束:
				break
			
			if 攻击回调 != null:
				攻击回调.call()
			
			检查战斗结果()
	
	func 检查战斗结果():
		if 战斗已结束:
			return
		if 敌方数据["生命值"] <= 0:
			战斗已结束 = true
			if 回调对象.get("胜利回调") != null:
				回调对象["胜利回调"].call()
		elif 我方数据["生命值"] <= 0:
			战斗已结束 = true
			if 回调对象.get("失败回调") != null:
				回调对象["失败回调"].call()
	
	# 手动胜利/失败
	func 手动触发我方胜利():
		if 战斗已结束:
			return
		战斗已结束 = true
		if 回调对象.get("胜利回调") != null:
			回调对象["胜利回调"].call()
	
	func 手动触发我方失败():
		if 战斗已结束:
			return
		战斗已结束 = true
		if 回调对象.get("失败回调") != null:
			回调对象["失败回调"].call()
	
	# 暂停/恢复
	func 暂停():
		if 战斗已结束 or 战斗已暂停:
			return
		战斗已暂停 = true
		暂停信号.emit()
		引擎.调试.打印("战斗已暂停")
	
	func 恢复():
		if 战斗已结束 or not 战斗已暂停:
			return
		战斗已暂停 = false
		恢复信号.emit()
		引擎.调试.打印("战斗已恢复")



#extends Node
#
## 放置对战核心类（纯字典版）
#class 放置对战 extends Node:
	## 舞台速度
	#var 舞台速度 = 1.0 
	#
	## 角色数据：直接用字典（不再用自定义类）
	#var 我方数据: Dictionary = {}
	#var 敌方数据: Dictionary = {}
	#
	## 存储回调的字典对象
	#var 回调对象: Dictionary = {}
	#
	## 战斗状态标记
	#var 战斗已结束 = false
	#
	## 初始化角色数据（封装默认值，统一管理）
	#func _创建角色数据(数据字典: Dictionary = {}) -> Dictionary:
		## 基础默认值 + 数据字典覆盖 + 支持任意扩展属性
		#var 角色数据 = {
			#"ID": 1000,
			#"速度": 1.0,
			#"可攻击": true,
			#"生命值": 100.0,
			#"攻击力": 10.0,
			#"距离": 1.0
		#}
		## 遍历传入的字典，覆盖默认值（支持任意扩展属性，比如最大生命值、防御等）
		#for 键 in 数据字典:
			#角色数据[键] = 数据字典[键]
			##引擎.调试.注释打印("角色数据赋值：", 键, "=", 数据字典[键])
		#return 角色数据
	#
	#func _init(我方初始数据: Dictionary, 敌方初始数据: Dictionary, 舞台的速度:float=1.0) -> void:
		## 初始化双方角色数据（字典版）
		#self.我方数据 = _创建角色数据(我方初始数据)
		#self.敌方数据 = _创建角色数据(敌方初始数据)
		#self.舞台速度 = 舞台的速度
		#
		#引擎.调试.打印("1V1战斗舞台已启动")
	#
	## 回调注入方法（逻辑不变，仅适配字典）
	#func 回调(封包函数: Callable):
		#var 对象 = {}
		## 传递字典版的角色数据给封包函数
		#封包函数.call(self.我方数据, self.敌方数据, 对象)
		#self.回调对象 = 对象
		#self.开始()
	#
	#func 开始():
		#战斗已结束 = false
		#启动攻击循环("我方")
		#启动攻击循环("敌方")
	#
	#func 启动攻击循环(阵营: String):
		#_攻击循环协程(阵营)
	#
	#
	#
	#func _攻击循环协程(阵营: String):
		#await 引擎.场景.等待(0.01)
		#while not 战斗已结束:
			## 字典版角色数据获取
			#var 己方数据 = 我方数据 if 阵营 == "我方" else 敌方数据
			#var 对方数据 = 敌方数据 if 阵营 == "我方" else 我方数据
			#
			## 字典方式读取回调（兼容 . 语法和 [] 语法，推荐 [] 更统一）
			#var 攻击回调 = 回调对象.get("我攻击回调") if 阵营 == "我方" else 回调对象.get("敌方攻击回调")
			#
			## 字典方式访问属性（核心改动：.可攻击 → ["可攻击"]）
			#if not 己方数据["可攻击"]:
				#await 引擎.场景.等待(0.1)
				#continue
			#
			## 字典方式访问速度属性
			#var 当前速度 = max(己方数据["速度"], 0.1)
			#var 攻击间隔 = 舞台速度 / 当前速度
			###触发冷却回调
			## ===== 核心改造2：对外发送冷却时间回调,用于模拟进度条=====
			#var 冷却回调 = 回调对象.get("冷却时间回调")
			#if 冷却回调 != null:
				## 向外部传递：阵营、冷却间隔
				#冷却回调.call(
					#阵营,
					#攻击间隔
				#)#这里向外发送后,如果攻击有额外回调的话,好像会额外加大
			### 
			###
			#await 引擎.场景.等待(攻击间隔)
			#
			#if 战斗已结束:
				#break
			#
			## 执行攻击回调
			#if 攻击回调 != null:
				#攻击回调.call()
			#
			#检查战斗结果()
	#
	#func 检查战斗结果():
		#if 战斗已结束:
			#return
		#
		#
		## 字典方式访问生命值
		#if 敌方数据["生命值"] <= 0:
			#战斗已结束 = true
			## 执行胜利回调
			#if 回调对象.get("胜利回调") != null:
				#回调对象["胜利回调"].call()
		#
		#elif 我方数据["生命值"] <= 0:
			#战斗已结束 = true
			## 执行失败回调
			#if 回调对象.get("失败回调") != null:
				#回调对象["失败回调"].call()
	#
	## ===== 新增：手动触发我方胜利（核心需求）=====
	#func 手动触发我方胜利():
		#if 战斗已结束:  # 防止重复触发
			#return
		#战斗已结束 = true  # 标记战斗结束
		## 执行胜利回调（和自动检测的逻辑完全一致）
		#if 回调对象.get("胜利回调") != null:
			#回调对象["胜利回调"].call()
	#
	## ===== 新增：手动触发我方失败（核心需求）=====
	#func 手动触发我方失败():
		#if 战斗已结束:  # 防止重复触发
			#return
		#战斗已结束 = true  # 标记战斗结束
		## 执行失败回调（和自动检测的逻辑完全一致）
		#if 回调对象.get("失败回调") != null:
			#回调对象["失败回调"].call()
