#!/bin/bash

SCRIPTPATH=$( dirname $(readlink -f $0) )
RES_DIR=${SCRIPTPATH}/$(basename -s .sh $0)
source ${SCRIPTPATH}/testlib.sh

RET=0
TEST_NS="${KV_NAMESPACE}"

# Test if existing affinities/nodeSelectors/tolerations are propagated to the daemon set
echo "[test_id:4853]: Check if Node Labeller Daemon set is created"
oc apply -n ${TEST_NS} -f "${RES_DIR}/11-node-labeller-affinity-nodeSelector-tolerations.yaml" || exit 2

# Wait for the operator to create the daemon set, we don't care if pods are actually ready, as
# we only check for the pod scheduling fields
DAEMONSET_FOUND=false
for i in {1..20}; do
  oc get -n ${TEST_NS} ds kubevirt-node-labeller
  EXIT_CODE=$?
  if (( $EXIT_CODE == 0 )); then
    DAEMONSET_FOUND=true
    break
  else
    sleep 10
  fi
done

if [ "$DAEMONSET_FOUND" == "false" ]; then
  echo "kubevirt-node-labeller daemon set was not found"
  exit 1
fi

echo "[test_id:4854]: Check if Node selector value is set as expected"
oc get -n ${TEST_NS} ds kubevirt-node-labeller -ojson | jq '.spec.template.spec'
NODE_SELECTOR=$(oc get -n ${TEST_NS} ds kubevirt-node-labeller -ojson | jq '.spec.template.spec.nodeSelector.testKey' | tr -d '"')
if [ "$NODE_SELECTOR" != "testValue" ]; then
  echo $NODE_SELECTOR
  echo "node labeller daemon set is missing proper nodeSelector"
  RET=1
fi

echo "[test_id:4856]: Check if Tolerations is set as expected"
TOLERATION=$(oc get -n ${TEST_NS} ds kubevirt-node-labeller -ojson | jq '.spec.template.spec.tolerations[0].key' | tr -d '"')
if [ "$TOLERATION" != "testKey" ]; then
  echo $TOLERATION
  echo "node labeller daemon set is missing proper tolerations"
  RET=1
fi

echo "[test_id:4857]: Check if Affinity is set as expected"
AFFINITY=$(oc get -n ${TEST_NS} ds kubevirt-node-labeller -ojson | jq '.spec.template.spec.affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution[0].preference.matchExpressions[0].key' | tr -d '"')
if [ "$AFFINITY" != "testKey" ]; then
  echo $AFFINITY
  echo "node labeller daemon set is missing proper affinity"
  RET=1
fi

timeout=300
sample=10
current_time=0

echo "[test_id:4997]: Check if patch is applied without error"
oc patch -n ${TEST_NS} KubevirtNodeLabellerBundle kubevirt-node-labeller-bundle --type='json' -p='[{"op": "remove", "path": "/spec/affinity"}, {"op": "remove", "path": "/spec/nodeSelector"}, {"op": "remove", "path": "/spec/tolerations"}]'
#wait until operator applies newest configuration
while [ $(oc get -n ${TEST_NS} pods | grep node-labeller.*Running | wc -l) -lt 1 ] ; do 
  oc get pods
  if [ $current_time -gt $timeout ]; then
    RET=1
    echo "node-labeller is not in running state"
    break
  fi
  current_time=$((current_time + sample))
  sleep $sample;
done

echo "[test_id:4998]: Check if nodeSelector is set as expected"
NODE_SELECTOR=$(oc get -n ${TEST_NS} ds kubevirt-node-labeller -ojson | jq '.spec.template.spec.nodeSelector.testKey' | tr -d '"')
if [ "$NODE_SELECTOR" != "null" ] && [ "$NODE_SELECTOR" != "{}" ]; then
  echo $NODE_SELECTOR
  echo "node labeller is missing proper nodeSelector after update"
  RET=1
fi

echo "[test_id:4999]: Check if tolerations is set as expected"
TOLERATION=$(oc get -n ${TEST_NS} ds kubevirt-node-labeller -ojson | jq '.spec.template.spec.tolerations[0].key' | tr -d '"')
if [ "$TOLERATION" != "null" ] && [ "$TOLERATION" != "[]" ]; then
  echo $TOLERATION
  echo "node labeller daemon is missing proper tolerations after update"
  RET=1
fi

echo "[test_id:5000]: Check if affinity is set as expected"
AFFINITY=$(oc get -n ${TEST_NS} ds kubevirt-node-labeller -ojson | jq '.spec.template.spec.affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution[0].preference.matchExpressions[0].key' | tr -d '"')
if [ "$AFFINITY" != "null" ] && [ "$AFFINITY" != "{}" ]; then
  echo $AFFINITY
  echo "node labeller daemon is missing proper affinity after update"
  RET=1
fi

oc delete -n ${TEST_NS} -f "${RES_DIR}/11-node-labeller-affinity-nodeSelector-tolerations.yaml" || exit 2

# Wait for the daemon set from the previous test to be deleted
DAEMONSET_DELETED=false
for i in {1..20}; do
  oc get -n ${TEST_NS} ds kubevirt-node-labeller
  EXIT_CODE=$?
  if (( $EXIT_CODE == 1 )); then
    DAEMONSET_DELETED=true
    break
  else
    sleep 10
  fi
done

if [ "$DAEMONSET_DELETED" == "false" ]; then
  echo "kubevirt-node-labeller daemon set was not deleted after the previous test"
  exit 1
fi

# Test if empty affinity/nodeSelector/tolerations values are propagated to the daemon set
echo "[test_id:4884]: Check if Node Labeller Daemon set is created"
oc create -n ${TEST_NS} -f "${RES_DIR}/11-node-labeller-empty-affinity-nodeSelector-tolerations.yaml" || exit 2

DAEMONSET_FOUND=false
for i in {1..20}; do
  oc get -n ${TEST_NS} ds kubevirt-node-labeller
  EXIT_CODE=$?
  if (( $EXIT_CODE == 0 )); then
    DAEMONSET_FOUND=true
    break
  else
    sleep 10
  fi
done

if [ "$DAEMONSET_FOUND" == "false" ]; then
  echo "kubevirt-node-labeller daemon set was not found"
  exit 1
fi

echo "[test_id:4885]: Check if Node selector value is set as expected"
oc get -n ${TEST_NS} ds kubevirt-node-labeller -ojson | jq '.spec.template.spec'

NODE_SELECTOR=$(oc get -n ${TEST_NS} ds kubevirt-node-labeller -ojson | jq '.spec.template.spec.nodeSelector' | tr -d '"')
if [ "$NODE_SELECTOR" != "null" ] && [ "$NODE_SELECTOR" != "{}" ]; then
  echo $NODE_SELECTOR
  echo "node labeller daemon set is missing proper nodeSelector"
  RET=1
fi

echo "[test_id:4886]: Check if Tolerations is set as expectedd"
TOLERATION=$(oc get -n ${TEST_NS} ds kubevirt-node-labeller -ojson | jq '.spec.template.spec.tolerations' | tr -d '"')
if [ "$TOLERATION" != "null" ] && [ "$TOLERATIONS" != "[]" ]; then
  echo $TOLERATION
  echo "node labeller daemon set is missing proper tolerations"
  RET=1
fi

echo "[test_id:4887]: Check if Affinity is set as expected"
AFFINITY=$(oc get -n ${TEST_NS} ds kubevirt-node-labeller -ojson | jq '.spec.template.spec.affinity' | tr -d '"')
if [ "$AFFINITY" != "null" ] && [ "$AFFINITY" != "{}" ] ; then
  echo $AFFINITY
  echo "node labeller daemon set is missing proper affinity"
  RET=1
fi

oc delete -n ${TEST_NS} -f "${RES_DIR}/11-node-labeller-empty-affinity-nodeSelector-tolerations.yaml" || exit 2

exit $RET
