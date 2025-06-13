# SRS Kubernetes 部署

这个目录包含了SRS (Simple Realtime Server) 在Kubernetes中的部署资源文件和脚本。

## 文件说明

- `Dockerfile` - SRS Docker镜像构建文件
- `configmap-srs.yaml` - SRS配置文件ConfigMap
- `deployment-srs.yaml` - SRS Deployment部署文件
- `service-srs.yaml` - SRS ClusterIP Service
- `service-nodeport-srs.yaml` - SRS NodePort Service (外部访问)
- `ingress-srs.yaml` - SRS Ingress规则
- `deploy-srs.sh` - 一键部署脚本

## 快速开始

### 1. 构建Docker镜像

```bash
# 构建SRS镜像
./deploy-srs.sh build
```

### 2. 部署到Kubernetes

```bash
# 基础部署
./deploy-srs.sh deploy

# 或者启用NodePort和Ingress
ENABLE_NODEPORT=true ENABLE_INGRESS=true ./deploy-srs.sh deploy
```

### 3. 查看状态

```bash
./deploy-srs.sh status
```

### 4. 查看日志

```bash
./deploy-srs.sh logs
```

### 5. 删除部署

```bash
./deploy-srs.sh delete
```

## 手动部署

如果不使用脚本，可以手动应用资源文件：

```bash
# 1. 创建ConfigMap
kubectl apply -f configmap-srs.yaml

# 2. 创建Deployment
kubectl apply -f deployment-srs.yaml

# 3. 创建Service
kubectl apply -f service-srs.yaml

# 4. (可选) 创建NodePort Service
kubectl apply -f service-nodeport-srs.yaml

# 5. (可选) 创建Ingress
kubectl apply -f ingress-srs.yaml
```

## 访问SRS

### 集群内访问

```bash
# 获取Service IP
kubectl get svc srs-service

# 访问地址
RTMP推流: rtmp://SERVICE_IP:1935/live/your_stream_key
HTTP API: http://SERVICE_IP:1985/api/v1/summaries
Web控制台: http://SERVICE_IP:8080
WebRTC: http://SERVICE_IP:8000
```

### 外部访问 (NodePort)

```bash
# 获取节点IP
kubectl get nodes -o wide

# 访问地址
RTMP推流: rtmp://NODE_IP:31935/live/your_stream_key
HTTP API: http://NODE_IP:31985/api/v1/summaries
Web控制台: http://NODE_IP:30080
WebRTC: http://NODE_IP:30000
GB28181: udp://NODE_IP:30060
```

### 通过Ingress访问

```bash
# 添加hosts记录
echo "INGRESS_IP srs.local" >> /etc/hosts

# 访问地址
Web控制台: http://srs.local
HTTP API: http://srs.local/api
```

## 配置说明

### 环境变量

- `NAMESPACE` - Kubernetes命名空间 (默认: default)
- `SRS_IMAGE` - SRS Docker镜像名称 (默认: srs:latest)
- `ENABLE_NODEPORT` - 是否启用NodePort Service (默认: false)
- `ENABLE_INGRESS` - 是否启用Ingress (默认: false)

### SRS配置

SRS的配置在 `configmap-srs.yaml` 中定义，主要功能包括：

- **RTMP服务** - 端口1935，支持直播推流
- **HTTP API** - 端口1985，提供REST API接口
- **HTTP服务器** - 端口8080，提供Web控制台
- **WebRTC** - 端口8000，支持WebRTC推拉流
- **GB28181** - 端口5060 UDP，支持国标协议
- **HLS** - 支持HLS切片直播
- **录制** - 支持录制功能（默认关闭）

### 资源限制

- **CPU请求**: 100m
- **CPU限制**: 500m
- **内存请求**: 256Mi
- **内存限制**: 1Gi

## 常用操作

### 推流测试

使用FFmpeg推流测试：

```bash
# RTMP推流
ffmpeg -re -i your_video.mp4 -c copy -f flv rtmp://NODE_IP:31935/live/test

# 查看流状态
curl http://NODE_IP:31985/api/v1/streams
```

### 拉流测试

```bash
# RTMP拉流
ffplay rtmp://NODE_IP:31935/live/test

# HLS拉流
ffplay http://NODE_IP:30080/live/test.m3u8

# HTTP-FLV拉流
ffplay http://NODE_IP:30080/live/test.flv
```

### 扩缩容

```bash
# 扩容到3个副本
kubectl scale deployment srs --replicas=3

# 查看副本状态
kubectl get pods -l app=srs
```

### 更新配置

```bash
# 修改configmap-srs.yaml后重新应用
kubectl apply -f configmap-srs.yaml

# 重启Pod以加载新配置
kubectl rollout restart deployment srs
```

## 故障排查

### 查看Pod状态

```bash
kubectl get pods -l app=srs
kubectl describe pod POD_NAME
```

### 查看日志

```bash
kubectl logs -f deployment/srs
```

### 查看事件

```bash
kubectl get events --sort-by=.metadata.creationTimestamp
```

### 端口测试

```bash
# 测试RTMP端口
telnet NODE_IP 31935

# 测试HTTP API
curl http://NODE_IP:31985/api/v1/summaries
```

## 注意事项

1. **镜像构建** - 确保Docker环境正常，构建时间较长
2. **端口冲突** - NodePort端口可能与其他服务冲突，请检查端口占用
3. **网络策略** - 如果集群有网络策略，需要允许相应端口
4. **存储** - 如需持久化录制文件，需要配置PVC
5. **负载均衡** - 多副本时注意RTMP推流的负载均衡配置

## 监控和日志

### 启用日志收集

如果集群有日志收集系统（如ELK），SRS日志会自动收集。

### 监控指标

SRS提供HTTP API用于监控：

```bash
# 系统统计
curl http://NODE_IP:31985/api/v1/summaries

# 流统计
curl http://NODE_IP:31985/api/v1/streams

# 客户端统计
curl http://NODE_IP:31985/api/v1/clients
```

## 生产环境建议

1. **资源限制** - 根据实际负载调整CPU和内存限制
2. **持久化存储** - 配置PVC用于录制文件存储
3. **高可用** - 部署多个副本并配置负载均衡
4. **监控告警** - 集成Prometheus监控和告警
5. **备份策略** - 定期备份配置和重要数据
6. **安全加固** - 启用HTTPS和访问控制
