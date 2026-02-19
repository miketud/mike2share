# Ollama Installation Guide - source https://docs.ollama.com/linux

This guide provides comprehensive instructions for installing and configuring Ollama on Linux systems, including GPU support and service setup.

## Installation

### Quick Install

To install Ollama, run the following command:

```shell
curl -fsSL https://ollama.com/install.sh | sh
```

### Manual Install

If you are upgrading from a prior version, remove the old libraries first:

```shell
sudo rm -rf /usr/lib/ollama
```

Download and extract the package:

```shell
curl -fsSL https://ollama.com/download/ollama-linux-amd64.tar.zst | sudo tar x -C /usr
```

Start Ollama:

```shell
ollama serve
```

In another terminal, verify that Ollama is running:

```shell
ollama -v
```

## GPU Support

### AMD GPU Install

If you have an AMD GPU, also download and extract the additional ROCm package:

```shell
curl -fsSL https://ollama.com/download/ollama-linux-amd64-rocm.tar.zst | sudo tar x -C /usr
```

### ARM64 Install

Download and extract the ARM64-specific package:

```shell
curl -fsSL https://ollama.com/download/ollama-linux-arm64.tar.zst | sudo tar x -C /usr
```

## System Service Setup (Recommended)

Create a user and group for Ollama:

```shell
sudo useradd -r -s /bin/false -U -m -d /usr/share/ollama ollama
sudo usermod -a -G ollama $(whoami)
```

Create a service file in `/etc/systemd/system/ollama.service`:

```ini
[Unit]
Description=Ollama Service
After=network-online.target

[Service]
ExecStart=/usr/bin/ollama serve
User=ollama
Group=ollama
Restart=always
RestartSec=3
Environment="PATH=$PATH"

[Install]
WantedBy=multi-user.target
```

Then start the service:

```shell
sudo systemctl daemon-reload
sudo systemctl enable ollama
```

## Driver Installation (Optional)

### CUDA Drivers

[Download and install](https://developer.nvidia.com/cuda-downloads) CUDA.

Verify that the drivers are installed by running the following command, which should print details about your GPU:

```shell
nvidia-smi
```

### AMD ROCm Drivers

[Download and Install](https://rocm.docs.amd.com/projects/install-on-linux/en/latest/tutorial/quick-start.html) ROCm v6.

<Note>
While AMD has contributed the `amdgpu` driver upstream to the official linux
kernel source, the version is older and may not support all ROCm features. We
recommend you install the latest driver from
https://www.amd.com/en/support/linux-drivers for best support of your Radeon
GPU.
</Note>

## Starting Ollama

Start Ollama and verify it is running:

```shell
sudo systemctl start ollama
sudo systemctl status ollama
```

## Customization

To customize the installation of Ollama, you can edit the systemd service file or the environment variables by running:

```shell
sudo systemctl edit ollama
```

Alternatively, create an override file manually in `/etc/systemd/system/ollama.service.d/override.conf`:

```ini
[Service]
Environment="OLLAMA_DEBUG=1"
```

## Updating

Update Ollama by running the install script again:

```shell
curl -fsSL https://ollama.com/install.sh | sh
```

Or by re-downloading Ollama:

```shell
curl -fsSL https://ollama.com/download/ollama-linux-amd64.tar.zst | sudo tar x -C /usr
```

## Installing Specific Versions

Use `OLLAMA_VERSION` environment variable with the install script to install a specific version of Ollama, including pre-releases. You can find the version numbers in the [releases page](https://github.com/ollama/ollama/releases).

For example:

```shell
curl -fsSL https://ollama.com/install.sh | OLLAMA_VERSION=0.5.7 sh
```

## Viewing Logs

To view logs of Ollama running as a startup service, run:

```shell
journalctl -e -u ollama
```

## Uninstall

Remove the ollama service:

```shell
sudo systemctl stop ollama
sudo systemctl disable ollama
sudo rm /etc/systemd/system/ollama.service
```

Remove ollama libraries from your lib directory (either `/usr/local/lib`, `/usr/lib`, or `/lib`):

```shell
sudo rm -r $(which ollama | tr 'bin' 'lib')
```

Remove the ollama binary from your bin directory (either `/usr/local/bin`, `/usr/bin`, or `/bin`):

```shell
sudo rm $(which ollama)
```

Remove the downloaded models and Ollama service user and group:

```shell
sudo userdel ollama
sudo groupdel ollama
sudo rm -r /usr/share/ollama