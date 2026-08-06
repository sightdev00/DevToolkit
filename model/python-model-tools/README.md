# Python model tools

面向视觉模型文件检查、转换、优化、推理、精度比较和芯片部署的 Python 工具索引。

这里不是包名收藏夹。每个条目必须说明权威来源、职责、适用格式、平台边界、维护状态和验证要求。结构化信息统一维护在 [`catalog.yaml`](catalog.yaml)，README 只维护选择方法和共同规则。

## 选择路径

| 任务 | 首选工具 | 说明 |
|---|---|---|
| 读取、保存、检查 ONNX | `onnx` | 处理 protobuf、checker、shape inference 和 opset 信息 |
| 建立 CPU/GPU 基准输出 | `onnxruntime` | 用作转换前基准，但不能自动代表训练框架输出 |
| 查看模型图 | `netron` | 只读检查输入输出、节点、initializer 和 graph 结构 |
| 简化 ONNX | `onnxsim` | 简化后必须重新检查并进行输出对齐 |
| 多后端输出比较 | `polygraphy` | 适合 ONNX Runtime、TensorRT 等后端间定位差异 |
| 程序化修改 graph | `onnx-graphsurgeon` | 属于高风险修改，必须保留修改前后验证 |
| NVIDIA 部署 | `tensorrt` | 受 CUDA、GPU 架构和 TensorRT 版本约束 |
| Intel 部署 | `openvino` | 面向 Intel CPU、GPU、NPU 等运行后端 |
| RKNPU2 转换 | `rknn-toolkit2` | 与芯片、SDK、runtime 版本绑定 |
| RKNPU2 板端 Python 推理 | `rknn-toolkit-lite2` | 不能代替 C/C++ 最终部署验收 |
| 旧 RKNPU1 工具链 | `rknn-toolkit` / `rknn-toolkit-lite` | 不得与 Toolkit2 视为兼容升级关系 |

TensorFlow、PaddlePaddle 等源框架转换器只在真实存在对应输入格式时使用，不作为默认工具链安装。

## 推荐的最小 ONNX 检查链

```text
source model
    ↓
export to ONNX
    ↓
onnx.load + onnx.checker
    ↓
shape inference / Netron inspection
    ↓
ONNX Runtime baseline
    ↓
optional simplify or graph edit
    ↓
checker + same-input output comparison
    ↓
vendor converter / target runtime
```

任何图简化、常量折叠、opset conversion、节点替换、量化或格式转换，都可能改变数值和动态 shape 行为。工具运行成功不是语义等价证明。

## 最小验证合同

修改或转换模型后，至少记录：

1. 原模型和目标模型的 SHA-256；
2. Python、工具包、runtime、驱动和 SDK 版本；
3. 输入名称、dtype、shape、layout、颜色格式和预处理；
4. 固定测试输入或可复现的数据 manifest；
5. 输出名称、shape、dtype 和数值误差；
6. 检测、分割或关键点任务的最终后处理结果差异；
7. 不支持算子、fallback、自动混合精度和图优化警告；
8. 失败样本与允许误差的来源。

模型级与任务级精度诊断放在 `vision-workbench`，这里仅维护工具选择和共同验证边界。

## 环境隔离

不要维护一个试图同时安装全部工具的统一 `requirements.txt`。以下约束经常互相冲突：

- Python 和 protobuf 版本；
- CUDA、cuDNN、TensorRT 与 GPU 架构；
- OpenVINO 运行后端；
- Rockchip toolkit、runtime、芯片和系统镜像；
- vendor wheel 的操作系统与 Python ABI。

建议按后端建立独立环境，例如：

```text
env-onnx-cpu
env-onnx-cuda
env-tensorrt
env-openvino
env-rknn1
env-rknn2
```

具体项目应保存自己的锁定版本和环境清单，本索引不替代项目依赖管理。

## Catalog 状态

| 状态 | 含义 |
|---|---|
| `active` | 当前通用核心工具 |
| `conditional` | 只在特定源框架、硬件或后端下使用 |
| `legacy` | 为旧平台保留，不建议用于新平台 |
| `reference` | 官方示例或模型仓库，不是 Python 包 |
| `deprecated` | 已停止推荐，应迁移到替代路径 |

`verified_release` 只表示本仓库核查过的官方 release，不表示所有本地项目都应该立即升级。实际转换和部署必须服从项目兼容矩阵。

## 更新规则

更新目录时应：

- 优先核查官方仓库、正式 release 和官方文档；
- 修改 `last_verified`，不使用“最新”作为永久描述；
- 明确仓库迁移、包名变化、弃用和替代关系；
- 不根据 GitHub 星标或单次成功案例确定推荐等级；
- 不提交第三方 wheel、SDK、模型权重和许可证不明的二进制文件。
