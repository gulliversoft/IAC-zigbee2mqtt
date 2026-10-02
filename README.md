# Zigbee2MQTT on Kubernetes with Terraform

## Owner

- Name: Gulliversoft
- GitHub: https://github.com/gulliversoft
- Website: https://www.gulliversoft.com/

This project deploys Zigbee2MQTT to Kubernetes (Minikube) using Infrastructure as Code (Terraform), including:

- Zigbee2MQTT deployment
- USB dongle passthrough (`/dev/serial/by-id/...` -> `/dev/ttyUSB0`)
- MQTT broker (Mosquitto) in-cluster
- NodePort service for web UI access
- Persistent host data directory (`/data/zigbee2mqtt`)

## Why This Approach (IaC) Instead of Plain Docker

The official Zigbee2MQTT Docker guide is great for direct container usage:

- https://www.zigbee2mqtt.io/guide/installation/02_docker.html#running-the-container

This setup uses Terraform + Kubernetes because it provides:

- Reproducibility: full environment is declarative in `main.tf`
- Versionable infrastructure: reviewable changes in Git
- Safer operations: predictable `plan`/`apply` workflow
- Team handover: no hidden manual runtime flags

In short: plain Docker is simple for quick starts, while Terraform/Kubernetes is stronger for repeatable operations and lifecycle management.

## Why Not Minikube Docker Driver for This Use Case

For USB Zigbee adapters, hardware access is the critical requirement.

When Minikube runs with the Docker driver, Kubernetes runs inside a containerized node. In that mode, host USB device passthrough is unreliable/limited and can cause issues such as:

- device path not visible inside node
- mount type mismatches (`CharDevice` errors)
- permission and namespace access problems

Using a host-level Kubernetes runtime (instead of Docker driver) provides more direct and stable access to serial hardware (`/dev/ttyUSB0`, `/dev/serial/by-id/...`).

## Architecture

```mermaid
flowchart LR
    A[USB Zigbee Dongle<br/>/dev/serial/by-id/... -> /dev/ttyUSB0] --> B[Zigbee2MQTT Pod]
    C[/data/zigbee2mqtt<br/>hostPath persistence] --> B
    B --> D[Mosquitto Service<br/>mqtt://mosquitto:1883]
    D --> E[Mosquitto Pod]
    B --> F[Kubernetes Service NodePort<br/>:30080 -> :8080]
    F --> G[Browser UI<br/>http://<host-ip>:30080]
```

## Runtime Behavior

1. Zigbee2MQTT starts and reads config from `/app/data`.
2. The USB adapter is discovered on `/dev/ttyUSB0` (zstack).
3. Zigbee stack initializes (`zigbee-herdsman started`).
4. Zigbee2MQTT connects to MQTT (`mqtt://mosquitto:1883`).
5. Frontend serves on internal port `8080`.
6. Kubernetes NodePort exposes UI at `30080`.

Expected healthy log sequence:

- `Matched adapter ... => zstack`
- `Serialport opened`
- `Connected to MQTT server`
- `Zigbee2MQTT started!`

## Access

- UI: `http://<host-ip>:30080`
- Internal service: `terraformed-garden-plant-svc.garden.svc.cluster.local:8080`

## Deploy Commands

```bash
terraform validate
terraform plan
terraform apply -auto-approve
```

## Troubleshooting Quick Notes

- If onboarding appears repeatedly, check persisted config in `/data/zigbee2mqtt/configuration.yaml`.
- If UI redirects to `localhost:8080`, open NodePort URL directly.
- If startup fails at MQTT connection, verify Mosquitto service/pod is running.
- If USB cannot open (`Operation not permitted`), re-check device mount path and container permissions.

## Related Projects by Gulliversoft

Public repositories from the GitHub profile (overview):

- IAC-zigbee2mqtt
    Infrastructure as Code project around Zigbee2MQTT deployment patterns.
    https://github.com/gulliversoft/IAC-zigbee2mqtt
- helmfactory
    Helm and templating focused Kubernetes packaging work.
    https://github.com/gulliversoft/helmfactory
- Deploy-to-k8s
    Demo cases for Terraform-based Kubernetes deployment techniques.
    https://github.com/gulliversoft/Deploy-to-k8s
- am65x
    Low-level hardware access C library.
    https://github.com/gulliversoft/am65x
- Deploy-to-AKS
    Azure DevOps to AKS deployment showcase (fork).
    https://github.com/gulliversoft/Deploy-to-AKS
- betaflight
    Firmware customization work for DroneID-related flying use cases (fork).
    https://github.com/gulliversoft/betaflight
- DroneID
    Linux transmitter project for Bluetooth and Wi-Fi Drone ID (fork).
    https://github.com/gulliversoft/DroneID
- gpsd
    Mirrored/forked GPS daemon codebase variant.
    https://github.com/gulliversoft/gpsd
- Optomat
    C++ project.
    https://github.com/gulliversoft/Optomat
- ep3-bs
    Online booking system for courts (fork).
    https://github.com/gulliversoft/ep3-bs
- node-red-contrib-rfid-nfc
    Node-RED integration for NXP PN532 RFID/NFC.
    https://github.com/gulliversoft/node-red-contrib-rfid-nfc

Profile reference:

- https://github.com/gulliversoft?tab=repositories
