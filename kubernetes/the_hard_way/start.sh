#!bin/bash

# STEP 0
# Зарезервированный статический ip адрес
export KUBERNETES_PUBLIC_ADDRESS=84.201.159.56

# STEP 1
echo "---> Step 1: Terraforming yandex cloud..."
mkdir logs
cd ./terraform/
echo "yes" | terraform apply > ../logs/terraforming.log
cd -

# STEP 2
echo "---> Step 2: Mining and export ip adresses..."
for instance in 0 1 2; do
  addr=$(yc compute instance get worker-${instance} \
  | grep -A1 one_to_one_nat: \
  | grep -oE '\b[0-9]{1,3}(\.[0-9]{1,3}){3}\b')
  export EXTERNAL_IP_WORKER_${instance}=$addr
  echo "worker-$instance ip: $addr"
  ssh-keygen -f "/home/alexeybabenko/.ssh/known_hosts" -R $addr
done

for instance in 0 1 2; do
  addr=$(yc compute instance get master-${instance} \
  | grep -A1 one_to_one_nat: \
  | grep -oE '\b[0-9]{1,3}(\.[0-9]{1,3}){3}\b')
  export EXTERNAL_IP_MASTER_${instance}=$addr
  echo "master-$instance ip: $addr"
  ssh-keygen -f "/home/alexeybabenko/.ssh/known_hosts" -R $addr
done

# STEP 3
echo "---> Step 3: Creating TLS certs..."
mkdir certs
cd ./certs
cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca
cd -

# STEP 4
echo "---> Step 4: Creating Admin Client cert..."
cd ./certs

cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:masters",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin
cd -

# STEP 5
echo "---> Step 5: Creating Kubelet Client certs..."
cd ./certs
for instance in worker-0 worker-1 worker-2; do
cat > ${instance}-csr.json <<EOF
{
  "CN": "system:node:${instance}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

EXTERNAL_IP=$(yc compute instance get ${instance} \
  | grep -A1 one_to_one_nat: \
  | grep -oE '\b[0-9]{1,3}(\.[0-9]{1,3}){3}\b')
  
INTERNAL_IP=$(yc compute instance get ${instance} \
  | grep -A1 primary_v4_address: \
  | grep -oE '\b[0-9]{1,3}(\.[0-9]{1,3}){3}\b')

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${instance},${EXTERNAL_IP},${INTERNAL_IP} \
  -profile=kubernetes \
  ${instance}-csr.json | cfssljson -bare ${instance}
done
cd -

# STEP 6
echo "---> Step 6: Creating Scheduler Client cert..."
cd ./certs
cat > kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:kube-scheduler",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-scheduler-csr.json | cfssljson -bare kube-scheduler
cd -

# STEP 7
echo "---> Step 7: Creating API Server cert..."
cd ./certs
KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local

cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=10.32.0.1,10.240.0.10,10.240.0.11,10.240.0.12,${KUBERNETES_PUBLIC_ADDRESS},127.0.0.1,${KUBERNETES_HOSTNAMES} \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes

cd -

# STEP 8
echo "---> Step 8: Creating Service Account keys..."
cd ./certs
cat > service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  service-account-csr.json | cfssljson -bare service-account

cd -

# STEP 9
echo "---> Step 9: Creating Manager Client cert..."
cd ./certs
cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:kube-controller-manager",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager

cd -

# STEP 10
echo "---> Step 10: Creating Kube Proxy Client cert..."
cd ./certs
cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:node-proxier",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy

cd -

# SLEEP
echo "---> Sleeping for 60s"
sleep 60

# STEP 11
echo "---> Step 11: Sending keys to masters and workers..."
cd ./certs
scp -o StrictHostKeyChecking=no ca.pem worker-0-key.pem worker-0.pem ubuntu@${EXTERNAL_IP_WORKER_0}:~/
scp -o StrictHostKeyChecking=no ca.pem worker-1-key.pem worker-1.pem ubuntu@${EXTERNAL_IP_WORKER_1}:~/
scp -o StrictHostKeyChecking=no ca.pem worker-2-key.pem worker-2.pem ubuntu@${EXTERNAL_IP_WORKER_2}:~/
scp -o StrictHostKeyChecking=no ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
    service-account-key.pem service-account.pem ubuntu@${EXTERNAL_IP_MASTER_0}:~/
scp -o StrictHostKeyChecking=no ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
    service-account-key.pem service-account.pem ubuntu@${EXTERNAL_IP_MASTER_1}:~/
scp -o StrictHostKeyChecking=no ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
    service-account-key.pem service-account.pem ubuntu@${EXTERNAL_IP_MASTER_2}:~/
cd -

# STEP 12
echo "---> Step 12: Creating kubelet config..."
mkdir config
cd ./config
for instance in worker-0 worker-1 worker-2; do
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=../certs/ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-credentials system:node:${instance} \
    --client-certificate=../certs/${instance}.pem \
    --client-key=../certs/${instance}-key.pem \
    --embed-certs=true \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:${instance} \
    --kubeconfig=${instance}.kubeconfig

  kubectl config use-context default --kubeconfig=${instance}.kubeconfig
done

kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=../certs/ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
    --kubeconfig=kube-proxy.kubeconfig

  kubectl config set-credentials system:kube-proxy \
    --client-certificate=../certs/kube-proxy.pem \
    --client-key=../certs/kube-proxy-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-proxy.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-proxy \
    --kubeconfig=kube-proxy.kubeconfig

  kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=../certs/ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config set-credentials system:kube-controller-manager \
    --client-certificate=../certs/kube-controller-manager.pem \
    --client-key=../certs/kube-controller-manager-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-controller-manager \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=../certs/ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config set-credentials system:kube-scheduler \
    --client-certificate=../certs/kube-scheduler.pem \
    --client-key=../certs/kube-scheduler-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-scheduler \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=../certs/ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=admin.kubeconfig

  kubectl config set-credentials admin \
    --client-certificate=../certs/admin.pem \
    --client-key=../certs/admin-key.pem \
    --embed-certs=true \
    --kubeconfig=admin.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=admin \
    --kubeconfig=admin.kubeconfig

  kubectl config use-context default --kubeconfig=admin.kubeconfig

cd -

# STEP 13
echo "---> Step 13: Sending Kubernetes configs to masters and workers..."
cd ./config
scp -o StrictHostKeyChecking=no worker-0.kubeconfig kube-proxy.kubeconfig ubuntu@${EXTERNAL_IP_WORKER_0}:~/
scp -o StrictHostKeyChecking=no worker-1.kubeconfig kube-proxy.kubeconfig ubuntu@${EXTERNAL_IP_WORKER_1}:~/
scp -o StrictHostKeyChecking=no worker-2.kubeconfig kube-proxy.kubeconfig ubuntu@${EXTERNAL_IP_WORKER_2}:~/
scp -o StrictHostKeyChecking=no admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig ubuntu@${EXTERNAL_IP_MASTER_0}:~/
scp -o StrictHostKeyChecking=no admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig ubuntu@${EXTERNAL_IP_MASTER_1}:~/
scp -o StrictHostKeyChecking=no admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig ubuntu@${EXTERNAL_IP_MASTER_2}:~/
cd -

# STEP 14
echo "---> Step 14: Process encryption tools..."
cd ./config
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF
scp -o StrictHostKeyChecking=no encryption-config.yaml ubuntu@${EXTERNAL_IP_MASTER_0}:~/
scp -o StrictHostKeyChecking=no encryption-config.yaml ubuntu@${EXTERNAL_IP_MASTER_1}:~/
scp -o StrictHostKeyChecking=no encryption-config.yaml ubuntu@${EXTERNAL_IP_MASTER_2}:~/
cd -

# STEP 15
echo "---> Step 15: Creating ansible inventory and start masters.yml playbook..."
cd ./ansible
cat > inventory <<EOF
[masters]
master-0 ansible_ssh_host=${EXTERNAL_IP_MASTER_0} ansible_ssh_user=ubuntu
master-1 ansible_ssh_host=${EXTERNAL_IP_MASTER_1} ansible_ssh_user=ubuntu
master-2 ansible_ssh_host=${EXTERNAL_IP_MASTER_2} ansible_ssh_user=ubuntu
[workers]
worker-0 ansible_ssh_host=${EXTERNAL_IP_WORKER_0} ansible_ssh_user=ubuntu
worker-1 ansible_ssh_host=${EXTERNAL_IP_WORKER_1} ansible_ssh_user=ubuntu
worker-2 ansible_ssh_host=${EXTERNAL_IP_WORKER_2} ansible_ssh_user=ubuntu
EOF
ansible-playbook -i ./inventory masters.yml
cd -

# STEP 16
echo "---> Step 16: Validating: getting Kubernetes version..."
curl --cacert ./certs/ca.pem https://${KUBERNETES_PUBLIC_ADDRESS}:6443/version

# STEP 17
echo "---> Step 17: Start workers.yml playbook..."
cd ./ansible
ansible-playbook -i ./inventory workers.yml
cd -

# STEP 18
echo "---> Step 18: Local kubectl config..."
kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=./certs/ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443

kubectl config set-credentials admin \
    --client-certificate=./certs/admin.pem \
    --client-key=./certs/admin-key.pem

kubectl config set-context kubernetes-the-hard-way \
    --cluster=kubernetes-the-hard-way \
    --user=admin

kubectl config use-context kubernetes-the-hard-way

# STEP 19
echo "---> Step 19: Verification..."
kubectl get componentstatuses
kubectl get nodes

# STEP 20
echo "---> Step 20: Setting user full permissions to the kubelet API..."
kubectl create clusterrolebinding apiserver-kubelet-admin --user=kubernetes --clusterrole=system:kubelet-api-admin

# STEP 21
echo "---> Step 21: Applying deployments..."
kubectl apply -f ../reddit/post-deployment.yml
kubectl apply -f ../reddit/ui-deployment.yml
kubectl apply -f ../reddit/comment-deployment.yml
kubectl apply -f ../reddit/mongo-deployment.yml

# SLEEP
echo "---> Sleeping for 20s"
sleep 20

# STEP 21
echo "---> Step 22: Verification..."
kubectl get pods

echo "---> All steps finished!"
