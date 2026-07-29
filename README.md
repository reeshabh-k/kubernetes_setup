# Kubernetes Setup

Scripts to set up a Kubernetes cluster on Ubuntu machines behind the IITD proxy.

There are two sets of scripts: `master/` for the master node, and `worker/` for worker nodes.

Each script starts `proxy.sh` in the background and waits 2 seconds for it to connect, since most commands here need internet access through the IITD proxy. Some phases run as your normal user and some run via `sudo`, so the scripts resolve the path as `/home/$SUDO_USER/proxy.sh` when run with `sudo`, or `$HOME/proxy.sh` otherwise — either way it expects `proxy.sh` to be in your home directory.

## Phase 1 - Prepare the node

File: `phase1.sh` (needs `sudo`, run on master and every worker)

Updates Ubuntu, turns off swap (required by Kubernetes), loads the kernel modules Kubernetes needs (`overlay`, `br_netfilter`), sets the required network settings, and installs and configures containerd (the container runtime).

## Phase 2 - Install Kubernetes

File: `phase2.sh` (needs `sudo`, run on master and every worker)

Sets up the proxy for the system, apt, containerd, and kubelet. Adds the Kubernetes apt repository and installs `kubelet`, `kubeadm`, and `kubectl`. Also installs Helm.

## Phase 3 - Deploy workloads (master only)

Files: `master/phase3.sh`, `master/minio-values.yaml`, `master/flink-deployment.yaml` (run on master only, after the cluster is up and all workers have joined)

Hadoop, Flink, and MinIO don't need to be installed on every machine by hand. Instead, this phase uses Helm to deploy them as pods inside the cluster, and Kubernetes' scheduler decides which worker each pod actually runs on:

- **MinIO** is installed via its official Helm chart, using `minio-values.yaml`. This gives us S3-compatible storage, so there's no need for Hadoop/HDFS anymore.
- **Flink** is installed via the official Flink Kubernetes Operator. Once the operator is running, `flink-deployment.yaml` is applied to actually start a Flink cluster (JobManager + TaskManagers).

This only needs to be run once, from the master, since Helm and `kubectl` talk to the whole cluster, not to one machine.

### CPU split

This setup assumes 5 worker nodes, each with 8 cores. Each worker runs one MinIO pod and one Flink TaskManager pod, and each is capped at 4 cores (via `resources`/`resource` limits in the two config files), so the two workloads split each worker's cores roughly in half. Pod anti-affinity rules make sure MinIO and Flink pods spread out one-per-worker instead of stacking on the same machine. The master keeps its default control-plane taint, so no workload pods land there.

If your cluster has a different number of workers or different core counts, update `replicas` (both files) and the CPU `resources`/`resource` values to match.

## Putting it together

1. Run `phase1.sh` then `phase2.sh` on the master.
2. On each worker, run `phase1.sh` then `phase2.sh` with `sudo -E` (not plain `sudo`), e.g. `sudo -E ./phase1.sh`. The `-E` keeps your shell's environment variables when switching to root, which `apt` needs here.
3. On the master, initialize the cluster:

   ```
   sudo kubeadm init --kubernetes-version=v1.33.13 --pod-network-cidr=192.168.0.0/16
   ```

   This prints a `kubeadm join` command.

4. Run that `kubeadm join` command on each worker to add it to the cluster.
5. Still on the master, install a pod network add-on (for example Calico) so pods can talk to each other. Without this, pods will stay stuck in `Pending`/`ContainerCreating`.
6. Once `kubectl get nodes` shows all workers as `Ready`, run `phase3.sh` on the master to deploy MinIO and Flink.
