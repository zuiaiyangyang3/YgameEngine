extends Node
#基于 简单数据库 制作的单一已学习情况
class 基础技能:
	var 技能数据库:=引擎.数据库.技能数据库.new().获取数据库()
	var 已学习技能=[]
	
	# 学习技能
	func 学习技能(技能ID:String) -> bool:
		if not 获取是否已学习(技能ID):
			已学习技能.append(技能ID)
			return true
		else:
			return false
	# 忘记技能
	func 忘记技能(技能ID:String) -> bool:
		if 获取是否已学习(技能ID):
			已学习技能.erase(技能ID)
			引擎.调试.打印("已忘记技能: " + 技能ID + " - " + 技能数据库.获取名称(技能ID))
			return true
		else:
			return false
	# 获取已学习技能列表
	func 获取已学习技能列表() -> Array:
		return 已学习技能.duplicate(true)
	
	# 获取是否已学习
	func 获取是否已学习(技能ID:String) -> bool:
		
		return 已学习技能.has(技能ID)
	
	# 计算被动技能总加成
	func 计算被动技能总加成() -> Dictionary:
		var 加成列表 = {}
		for 技能ID in 已学习技能:
			var 技能类型 = 技能数据库.获取类型(技能ID)
			if 技能类型 == "被动":
				var 技能效果 = 技能数据库.获取效果(技能ID)
				for 属性名 in 技能效果:
					var 当前加成 = 技能效果[属性名]
					if 加成列表.has(属性名):
						加成列表[属性名] += 当前加成
					else:
						加成列表[属性名] = 当前加成
		return 加成列表
	
	# 清空已学习技能
	func 清空已学习技能() -> bool:
		已学习技能.clear()
		return true

# 带等级系统的技能管理类
class 等级技能:
	var 技能数据库:=引擎.数据库.技能数据库.new().获取数据库()
	
	var 等级配置库:Dictionary = {}  #储存配置项
	var 已学习技能:Dictionary = {}  # 存储技能实例
	
	# 内部存储检查器和处理器
	var _条件检查器:Dictionary = {}
	var _消耗处理器:Dictionary = {}
	
	func _init() -> void:
		# 加载等级配置
		if 引擎.文件.是否存在("res://系统/skill_levels.json"):
			等级配置库 = 引擎.文件.读取文件到变量("res://系统/skill_levels.json")
		else:
			引擎.调试.打印("技能等级配置文件不存在！")
		
	
	# ==================== 声明式配置方法 ====================
	func 配置检查器(配置函数:Callable) -> void:
		var 虚拟技能实例 = 技能实例.new("__dummy__", self)
		# 执行配置函数获取检查器对象
		var 检查器对象 = {}
		配置函数.call(虚拟技能实例, {}, 检查器对象)
		
		# 遍历检查器对象中的资源配置
		for 资源名 in 检查器对象:
			var 资源配置 = 检查器对象[资源名]
			if typeof(资源配置) == TYPE_DICTIONARY:
				# 注册检查器（修复：调用时传递3个参数）
				if 资源配置.has("检查") and typeof(资源配置["检查"]) == TYPE_CALLABLE:
					self._条件检查器[资源名 + "检查"] = func(技能实例, 升级需求):
						# 创建新的临时对象来接收配置
						var 最新检查器对象 = {}
						# 传递完整的3个参数！
						配置函数.call(技能实例, 升级需求, 最新检查器对象)
						if 最新检查器对象.has(资源名) and 最新检查器对象[资源名].has("检查"):
							return 最新检查器对象[资源名]["检查"].call()
						return false
				
				# 注册处理器（同样修复参数问题）
				if 资源配置.has("扣除") and typeof(资源配置["扣除"]) == TYPE_CALLABLE:
					self._消耗处理器[资源名 + "扣除"] = func(技能实例, 升级需求):
						var 最新检查器对象 = {}
						# 传递完整的3个参数！
						配置函数.call(技能实例, 升级需求, 最新检查器对象)
						if 最新检查器对象.has(资源名) and 最新检查器对象[资源名].has("扣除"):
							最新检查器对象[资源名]["扣除"].call()
	# ==================== 技能管理 ====================
	
	func 学习技能(技能ID:String) -> bool:
		if not 获取是否已学习(技能ID):
			# 1. 检查技能是否存在且有等级配置
			if not 技能数据库.获取数据(技能ID) or not 等级配置库.has(技能ID):
				引擎.调试.打印("技能不存在或无等级配置: " + 技能ID)
				return false
			
			# 2. 获取学习技能的需求（使用1级升级需求）
			var 等级配置 = 等级配置库.get(技能ID, {})
			var 一级配置 = 等级配置.get("等级属性", {}).get("1", {})
			var 学习需求 = 一级配置.get("升级需求", {})
			
			# 3. 获取升级配置（简化版数组）
			var 升级配置数组 = 等级配置.get("升级配置", [])
			
			# 4. 检查学习条件
			var 满足学习条件 = true
			
			for 资源名 in 升级配置数组:
				var 检查器名称 = 资源名 + "检查"
				if self._条件检查器.has(检查器名称):
					# 创建临时的技能实例用于检查
					var 临时技能实例 = 技能实例.new(技能ID, self)
					if not self._条件检查器[检查器名称].call(临时技能实例, 学习需求):
						满足学习条件 = false
						break
				else:
					引擎.调试.打印错误("未注册的检查器: " + 检查器名称)
					满足学习条件 = false
					break
			
			if not 满足学习条件:
				#引擎.调试.打印("不满足学习技能的条件: " + 技能ID)
				return false
			
			# 5. 处理学习消耗
			for 资源名 in 升级配置数组:
				var 处理器名称 = 资源名 + "扣除"
				if self._消耗处理器.has(处理器名称):
					var 临时技能实例 = 技能实例.new(技能ID, self)
					self._消耗处理器[处理器名称].call(临时技能实例, 学习需求)
			
			# 6. 学习技能
			已学习技能[技能ID] = 技能实例.new(技能ID, self)
			#引擎.调试.打印("已学习技能: " + 技能ID + " - " + 技能数据库.获取名称(技能ID))
			return true
		
		return false
	func 忘记技能(技能ID:String) -> bool:
		if 获取是否已学习(技能ID):
			已学习技能.erase(技能ID)
			引擎.调试.打印("已忘记技能: " + 技能ID + " - " + 技能数据库.获取名称(技能ID))
			return true
		return false
	
	func 获取是否已学习(技能ID:String) -> bool:
		return 获取已学习技能列表().has(技能ID)
	
	

	func 获取存档数据() -> Dictionary:
		var 存档数据 = {
			"已学习技能": [],
			"技能状态": {}
		}
		
		for 技能ID in 已学习技能:
			var 技能实例 = 已学习技能[技能ID]
			存档数据["已学习技能"].append(技能ID)
			存档数据["技能状态"][技能ID] = {
				"当前等级": 技能实例.当前等级,
				"熟练度": 技能实例.熟练度
			}
		
		return 存档数据

	func 从存档恢复(存档数据: Dictionary) -> void:
		# 清空现有数据
		已学习技能.clear()
		
		# 恢复已学习技能
		for 技能ID in 存档数据.get("已学习技能", []):
			# 重新创建技能实例
			if 技能数据库.获取数据(技能ID) and 等级配置库.has(技能ID):
				var 技能实例 = 技能实例.new(技能ID, self)
				已学习技能[技能ID] = 技能实例
				
				# 恢复技能状态
				var 技能状态 = 存档数据.get("技能状态", {}).get(技能ID, {})
				技能实例.当前等级 = 技能状态.get("当前等级", 1)
				技能实例.熟练度 = 技能状态.get("熟练度", 0.0)

	func 获取已学习技能列表() -> Array:
		return 已学习技能.keys()

	func 获取已学习技能详情() -> Dictionary:
		var 技能等级字典 = {}
		for 技能ID in 已学习技能:
			var 技能实例 = 已学习技能[技能ID]
			技能等级字典[技能ID] = {
				"当前等级": 技能实例.当前等级,
				"最大等级": 获取最大等级(技能ID),
				"熟练度": 技能实例.熟练度,
				"技能名称": 技能数据库.获取名称(技能ID)
			}
		return 技能等级字典
	
	func 获取技能实例(技能ID:String) -> 技能实例:
		return 已学习技能.get(技能ID, null)
	
	func 清空已学习技能() -> void:
		已学习技能.clear()
	
	# ==================== 加成计算 ====================
	func 计算被动技能总加成() -> Dictionary:
		var 总加成:Dictionary = {}
		
		for 技能ID in 已学习技能:
			var 技能实例 = 已学习技能[技能ID]
			if 技能数据库.获取类型(技能ID) == "被动":
				var 技能加成 = 技能实例.获取当前属性加成()
				for 属性名 in 技能加成:
					var 当前值 = 技能加成[属性名]
					if 总加成.has(属性名):
						总加成[属性名] += 当前值
					else:
						总加成[属性名] = 当前值
		
		return 总加成
	func 获取最大等级(技能ID:String) -> int:
		return 等级配置库.get(技能ID, {}).get("最大等级", 1)
		#	return 等级技能系统.等级配置库.get(技能ID, {}).get("升级配置", {})
	func 获取等级配置(技能ID:String,等级:int) -> Dictionary:
			var 等级属性 = 等级配置库.get(技能ID, {}).get("等级属性", {})
			return 等级属性.get(str(等级), {})
	# ==================== 内部类：技能实例 ====================
	class 技能实例:
		var 技能ID:String
		var 等级技能系统:等级技能
		var 当前等级:int = 1
		var 熟练度:float = 0.0
		
		func _init(技能ID:String, 等级技能系统:等级技能) -> void:
			self.技能ID = 技能ID
			self.等级技能系统 = 等级技能系统
		
		# 属性加成获取
		func 获取当前属性加成() -> Dictionary:
			var 等级配置 =等级技能系统.获取等级配置(技能ID,当前等级)
			return 等级配置.get("属性加成", {})
		
		func 获取等级属性加成(等级:int) -> Dictionary:
			var 等级配置 =等级技能系统.获取等级配置(技能ID,等级)
			return 等级配置.get("属性加成", {})
		
		# 升级需求获取
		func 获取当前升级需求() -> Dictionary:
			if 当前等级 >= 等级技能系统.获取最大等级(技能ID):
				return {}
			var 下一级配置 = 等级技能系统.获取等级配置(技能ID,当前等级 + 1)
			return 下一级配置.get("升级需求", {})
		
		# 熟练度管理
		func 增加熟练度(数值:float, 自动升级:bool=false) -> void:
			if 当前等级 >= 等级技能系统.获取最大等级(技能ID):
				return
			熟练度 += 数值
			if 自动升级:
				self.尝试升级()
		
		# 核心升级逻辑
		func 尝试升级() -> bool:
			if 当前等级 >=等级技能系统.获取最大等级(技能ID):
				return false
			
			var 升级配置数组 = 等级技能系统.等级配置库.get(技能ID, {}).get("升级配置", [])
			var 升级需求 = self.获取当前升级需求()
			
			# 1. 检查所有升级条件
			var 所有条件满足 = true
			
			for 资源名 in 升级配置数组:
				var 检查器名称 = 资源名 + "检查"
				if 等级技能系统._条件检查器.has(检查器名称):
					if not 等级技能系统._条件检查器[检查器名称].call(self, 升级需求):
						所有条件满足 = false
						break
				else:
					引擎.调试.打印错误("未注册的检查器: " + 检查器名称)
					所有条件满足 = false
					break
			
			if not 所有条件满足:
				return false
			
			# 2. 处理所有消耗
			for 资源名 in 升级配置数组:
				var 处理器名称 = 资源名 + "扣除"
				if 等级技能系统._消耗处理器.has(处理器名称):
					等级技能系统._消耗处理器[处理器名称].call(self, 升级需求)
			
			# 3. 升级成功（只升一级）
			当前等级 += 1
			引擎.调试.打印("技能【" + 等级技能系统.技能数据库.获取名称(技能ID) + "】升级到" + str(当前等级) + "级！")
			
			return true
		
		# 获取技能完整信息
		func 获取技能信息() -> Dictionary:
			return {
				"ID": 技能ID,
				"名称": 等级技能系统.技能数据库.获取名称(技能ID),
				"类型": 等级技能系统.技能数据库.获取类型(技能ID),
				"当前等级": 当前等级,
				"最大等级": 等级技能系统.获取最大等级(技能ID),
				"熟练度": 熟练度,
				"当前加成": self.获取当前属性加成(),
				"升级需求": self.获取当前升级需求(),
			}
		
		# 获取显示用的描述
		func 获取技能描述() -> String:
			var 技能数据=等级技能系统.技能数据库.获取数据(技能ID)
			var 基础描述 = 技能数据.描述
			var 当前加成 = self.获取当前属性加成()
			
			var 描述文本 = 基础描述
			描述文本 += "\n等级: " + str(当前等级) + "/" + str(等级技能系统.获取最大等级(技能ID))
			描述文本 += "\n熟练度: " + str(熟练度)
			
			
			描述文本 += "\n当前效果："
			引擎.调试.注释打印("内部",技能数据)
			
			for 属性名 in 当前加成:
				描述文本 += "\n- " + 属性名 + ": " + str(当前加成[属性名])
			
			if 当前等级 < 等级技能系统.获取最大等级(技能ID):
				var 升级需求 = self.获取当前升级需求()
				描述文本 += "\n升级需求："
				for 需求名 in 升级需求:
					描述文本 += "\n- " + 需求名 + ": " + str(升级需求[需求名])
			
			return 描述文本
