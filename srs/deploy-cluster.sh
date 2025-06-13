#!/bin/bash

# SRS集群部署脚本
# 使用方法: ./deploy-cluster.sh [deploy|scale|delete|status]

set -e

NAMESPACE=${NAMESPACE:-default}
REPLICAS=${REPLICAS:-3}
SRS_IMAGE=${SRS_IMAGE:-srs:latest}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

function print_usage() {
    echo "使用方法: $0 [deploy|scale|delete|status]"
    echo ""
    echo "命令:"
    echo "  deploy  - 部署SRS集群"
    echo "  scale   - 扩缩容SRS集群"
    echo "  delete  - 删除SRS集群"
    echo "  status  - 查看集群状态"
    echo ""
    echo "环境变量:"
    echo "  NAMESPACE - Kubernetes命名空间 (默认: default)"
    echo "  REPLICAS  - 集群副本数 (默认: 3)"
    echo "  SRS_IMAGE - SRS Docker镜像 (默认: srs:latest)"
}

function deploy_cluster() {
    echo "🚀 部署SRS集群..."

    # 部署生产配置
    kubectl apply -f "$SCRIPT_DIR/configmap-srs-production.yaml" -n "$NAMESPACE"

    # 部署StatefulSet
    kubectl apply -f "$SCRIPT_DIR/statefulset-srs-cluster.yaml" -n "$NAMESPACE"

    # 部署Service
    kubectl apply -f "$SCRIPT_DIR/service-srs-cluster.yaml" -n "$NAMESPACE"

    echo "✅ SRS集群部署完成"
    echo "等待Pod就绪..."
    kubectl wait --for=condition=ready pod -l app=srs-cluster -n "$NAMESPACE" --timeout=600s

    show_cluster_status
}

function scale_cluster() {
    echo "📈 扩缩容SRS集群到 $REPLICAS 个副本..."
    kubectl scale statefulset srs-cluster --replicas="$REPLICAS" -n "$NAMESPACE"

    echo "等待扩缩容完成..."
    kubectl wait --for=condition=ready pod -l app=srs-cluster -n "$NAMESPACE" --timeout=300s

    show_cluster_status
}

function delete_cluster() {
    echo "🗑️  删除SRS集群..."
    kubectl delete -f "$SCRIPT_DIR/service-srs-cluster.yaml" -n "$NAMESPACE" --ignore-not-found=true
    kubectl delete -f "$SCRIPT_DIR/statefulset-srs-cluster.yaml" -n "$NAMESPACE" --ignore-not-found=true
    kubectl delete -f "$SCRIPT_DIR/configmap-srs-production.yaml" -n "$NAMESPACE" --ignore-not-found=true

    echo "✅ SRS集群已删除"
}

function show_cluster_status() {
    echo "📊 SRS集群状态:"
    echo ""
    echo "=== StatefulSet ==="
    kubectl get statefulset srs-cluster -n "$NAMESPACE" -o wide
    echo ""
    echo "=== Pods ==="
    kubectl get pods -l app=srs-cluster -n "$NAMESPACE" -o wide
    echo ""
    echo "=== Services ==="
    kubectl get svc -l app=srs-cluster -n "$NAMESPACE"
    echo ""
    echo "=== PVC ==="
    kubectl get pvc -l app=srs-cluster -n "$NAMESPACE"
    echo ""

    # 获取负载均衡器访问信息
    LB_IP=$(kubectl get svc srs-cluster-lb -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [[ -n "$LB_IP" ]]; then
        echo "🌐 负载均衡器访问地址 (IP: $LB_IP):"
        echo "  RTMP: rtmp://$LB_IP:1935/live"
        echo "  HTTP API: http://$LB_IP:1985/api/v1/summaries"
        echo "  Web控制台: http://$LB_IP:8080"
        echo "  WebRTC: http://$LB_IP:8000"
    else
        echo "⏳ 负载均衡器IP分配中..."
    fi

    # 显示各个Pod的API地址
    echo ""
    echo "📡 各节点API地址:"
    kubectl get pods -l app=srs-cluster -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.podIP}{"\n"}{end}' | while read name ip; do
        if [[ -n "$ip" ]]; then
            echo "  $name: http://$ip:1985/api/v1/summaries"
        fi
    done
}

# 主程序
case "${1:-}" in
    deploy)
        deploy_cluster
        ;;
    scale)
        scale_cluster
        ;;
    delete)
        delete_cluster
        ;;
    status)
        show_cluster_status
        ;;
    *)
        print_usage
        exit 1
        ;;
esac
