#!/bin/bash

# SRS Kubernetes 部署脚本
# 使用方法: ./deploy-srs.sh [build|deploy|delete|status]

set -e

NAMESPACE=${NAMESPACE:-default}
SRS_IMAGE=${SRS_IMAGE:-srs:latest}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

function print_usage() {
    echo "使用方法: $0 [build|deploy|delete|status|logs]"
    echo ""
    echo "命令:"
    echo "  build   - 构建SRS Docker镜像"
    echo "  deploy  - 部署SRS到Kubernetes"
    echo "  delete  - 删除SRS部署"
    echo "  status  - 查看SRS状态"
    echo "  logs    - 查看SRS日志"
    echo ""
    echo "环境变量:"
    echo "  NAMESPACE - Kubernetes命名空间 (默认: default)"
    echo "  SRS_IMAGE - SRS Docker镜像名称 (默认: srs:latest)"
}

function build_image() {
    echo "🔨 构建SRS Docker镜像..."
    cd "$SCRIPT_DIR"
    docker buildx build --platform linux/amd64 -t "$SRS_IMAGE" .
    echo "✅ 镜像构建完成: $SRS_IMAGE"
}

function deploy_srs() {
    echo "🚀 部署SRS到Kubernetes..."

    # 应用ConfigMap
    echo "创建ConfigMap..."
    kubectl apply -f "$SCRIPT_DIR/configmap-srs.yaml" -n "$NAMESPACE"

    # 应用Deployment
    echo "创建Deployment..."
    kubectl apply -f "$SCRIPT_DIR/deployment-srs.yaml" -n "$NAMESPACE"

    # 应用Service
    echo "创建Service..."
    kubectl apply -f "$SCRIPT_DIR/service-srs.yaml" -n "$NAMESPACE"

    # 可选：应用NodePort Service
    if [[ "${ENABLE_NODEPORT:-false}" == "true" ]]; then
        echo "创建NodePort Service..."
        kubectl apply -f "$SCRIPT_DIR/service-nodeport-srs.yaml" -n "$NAMESPACE"
    fi

    # 可选：应用Ingress
    if [[ "${ENABLE_INGRESS:-false}" == "true" ]]; then
        echo "创建Ingress..."
        kubectl apply -f "$SCRIPT_DIR/ingress-srs.yaml" -n "$NAMESPACE"
    fi

    echo "✅ SRS部署完成"
    echo ""
    echo "等待Pod就绪..."
    kubectl wait --for=condition=ready pod -l app=srs -n "$NAMESPACE" --timeout=300s

    show_status
}

function delete_srs() {
    echo "🗑️  删除SRS部署..."

    # 删除所有资源
    kubectl delete -f "$SCRIPT_DIR/ingress-srs.yaml" -n "$NAMESPACE" --ignore-not-found=true
    kubectl delete -f "$SCRIPT_DIR/service-nodeport-srs.yaml" -n "$NAMESPACE" --ignore-not-found=true
    kubectl delete -f "$SCRIPT_DIR/service-srs.yaml" -n "$NAMESPACE" --ignore-not-found=true
    kubectl delete -f "$SCRIPT_DIR/deployment-srs.yaml" -n "$NAMESPACE" --ignore-not-found=true
    kubectl delete -f "$SCRIPT_DIR/configmap-srs.yaml" -n "$NAMESPACE" --ignore-not-found=true

    echo "✅ SRS部署已删除"
}

function show_status() {
    echo "📊 SRS状态信息:"
    echo ""
    echo "=== Pods ==="
    kubectl get pods -l app=srs -n "$NAMESPACE" -o wide
    echo ""
    echo "=== Services ==="
    kubectl get svc -l app=srs -n "$NAMESPACE"
    echo ""
    echo "=== Ingress ==="
    kubectl get ingress -l app=srs -n "$NAMESPACE" 2>/dev/null || echo "未配置Ingress"
    echo ""

    # 获取访问信息
    echo "🌐 访问信息:"

    # ClusterIP访问
    SVC_IP=$(kubectl get svc srs-service -n "$NAMESPACE" -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "N/A")
    if [[ "$SVC_IP" != "N/A" ]]; then
        echo "集群内访问:"
        echo "  RTMP: rtmp://$SVC_IP:1935/live"
        echo "  HTTP API: http://$SVC_IP:1985/api/v1/summaries"
        echo "  Web控制台: http://$SVC_IP:8080"
        echo "  WebRTC: http://$SVC_IP:8000"
    fi

    # NodePort访问
    if kubectl get svc srs-nodeport -n "$NAMESPACE" >/dev/null 2>&1; then
        NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
        echo "NodePort访问 (节点IP: $NODE_IP):"
        echo "  RTMP: rtmp://$NODE_IP:31935/live"
        echo "  HTTP API: http://$NODE_IP:31985/api/v1/summaries"
        echo "  Web控制台: http://$NODE_IP:30080"
        echo "  WebRTC: http://$NODE_IP:30000"
    fi
}

function show_logs() {
    echo "📋 SRS日志:"
    kubectl logs -l app=srs -n "$NAMESPACE" --tail=100 -f
}

# 主程序
case "${1:-}" in
    build)
        build_image
        ;;
    deploy)
        deploy_srs
        ;;
    delete)
        delete_srs
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    *)
        print_usage
        exit 1
        ;;
esac
