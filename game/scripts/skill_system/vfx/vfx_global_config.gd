# VFXGlobalConfig — 全局 VFX 配置
# 单例配置文件，定义各层级默认效果等全局参数
class_name VFXGlobalConfig
extends Resource

## 各层级默认效果 ID
## key = 层级标识 (A/B/C), value = 效果 ID (空字符串=不调用)
## 示例: {"A": "spark_tiny", "B": "spark_phys", "C": ""}
@export var tier_defaults: Dictionary = {
	"A": "spark_tiny",
	"B": "spark_phys",
	"C": "",
}
