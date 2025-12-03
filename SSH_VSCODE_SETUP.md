# SSH via VS Code - Comprehensive Setup Guide

This guide provides step-by-step instructions for setting up SSH access to your Google Cloud Platform (GCP) VM instance using Visual Studio Code's Remote-SSH extension.

## 📋 Prerequisites

- Visual Studio Code installed on your local machine
- A GCP VM instance created and running
- Access to your GCP project with appropriate permissions
- Your VM's external IP address
- SSH access level permissions on GCP

## 🚀 Step-by-Step Setup

### Step 1: Install VS Code Remote-SSH Extension

1. **Open Visual Studio Code**

2. **Open Extensions View**:
   - Press `Ctrl+Shift+X` (Windows/Linux) or `Cmd+Shift+X` (Mac)
   - Or click the Extensions icon in the left sidebar

3. **Search for Remote-SSH**:
   - Type "Remote - SSH" in the search bar
   - Look for the extension by Microsoft

4. **Install the Extension**:
   - Click the **Install** button
   - Wait for the installation to complete
   - You may need to reload VS Code after installation

5. **Verify Installation**:
   - The Remote-SSH extension should appear in your installed extensions
   - You should see a green icon in the bottom-left corner of VS Code when ready

### Step 2: Generate SSH Key Pair on Your Local Machine

#### For Windows (PowerShell or Git Bash)

1. **Open PowerShell or Git Bash**

2. **Check if SSH keys already exist**:
   ```bash
   ls ~/.ssh
   ```
   Look for files like `id_rsa` and `id_rsa.pub` or `id_ed25519` and `id_ed25519.pub`

3. **Generate a new SSH key pair** (if you don't have one):
   ```bash
   ssh-keygen -t ed25519 -C "your_email@example.com"
   ```
   
   Or use RSA (if ed25519 is not supported):
   ```bash
   ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
   ```

4. **Follow the prompts**:
   - Press Enter to accept the default file location (`~/.ssh/id_ed25519`)
   - Enter a passphrase (recommended) or press Enter for no passphrase
   - Confirm the passphrase

5. **Your keys are created**:
   - Private key: `~/.ssh/id_ed25519` (keep this secret!)
   - Public key: `~/.ssh/id_ed25519.pub` (this is what you'll add to GCP)

#### For macOS/Linux

1. **Open Terminal**

2. **Check if SSH keys already exist**:
   ```bash
   ls -la ~/.ssh
   ```

3. **Generate a new SSH key pair**:
   ```bash
   ssh-keygen -t ed25519 -C "your_email@example.com"
   ```

4. **Follow the same prompts as Windows**

5. **View your public key** (you'll need this for GCP):
   ```bash
   cat ~/.ssh/id_ed25519.pub
   ```
   Copy the entire output - it starts with `ssh-ed25519` or `ssh-rsa`

### Step 3: Add Public Key to GCP VM

#### Option A: Using GCP Console (Recommended)

1. **Navigate to GCP Console**:
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Select your project

2. **Go to Compute Engine**:
   - Click on **Compute Engine** → **VM instances**
   - Find your VM instance in the list

3. **Edit VM Instance**:
   - Click on the VM instance name
   - Click **Edit** at the top

4. **Add SSH Key**:
   - Scroll down to **SSH Keys** section
   - Click **Add Item**
   - Paste your public key (the content from `~/.ssh/id_ed25519.pub`)
   - Format: `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... your_email@example.com`
   - Click **Save**

5. **Wait for the VM to update** (usually takes a few seconds)

#### Option B: Using gcloud CLI

1. **Install gcloud CLI** (if not already installed):
   ```bash
   # Follow instructions at: https://cloud.google.com/sdk/docs/install
   ```

2. **Authenticate**:
   ```bash
   gcloud auth login
   ```

3. **Set your project**:
   ```bash
   gcloud config set project YOUR_PROJECT_ID
   ```

4. **Add SSH key to VM**:
   ```bash
   gcloud compute instances add-metadata INSTANCE_NAME \
     --zone=ZONE \
     --metadata-from-file ssh-keys=~/.ssh/id_ed25519.pub
   ```

#### Option C: Manual Addition (Direct SSH Access Required)

1. **SSH into your VM** (using GCP's browser SSH or initial access):
   ```bash
   gcloud compute ssh INSTANCE_NAME --zone=ZONE
   ```

2. **Add your public key**:
   ```bash
   echo "YOUR_PUBLIC_KEY_CONTENT" >> ~/.ssh/authorized_keys
   chmod 600 ~/.ssh/authorized_keys
   chmod 700 ~/.ssh
   ```

### Step 4: Configure SSH in VS Code

1. **Open Command Palette**:
   - Press `Ctrl+Shift+P` (Windows/Linux) or `Cmd+Shift+P` (Mac)
   - Or click **View** → **Command Palette**

2. **Open SSH Config File**:
   - Type: `Remote-SSH: Open SSH Configuration File...`
   - Select the option
   - Choose your SSH config file (usually `~/.ssh/config` or `C:\Users\YourUsername\.ssh\config`)

3. **Add VM Configuration**:
   Add the following configuration to the file:
   ```ssh-config
   Host gcp-vm
       HostName YOUR_VM_EXTERNAL_IP
       User YOUR_USERNAME
       IdentityFile ~/.ssh/id_ed25519
       ServerAliveInterval 60
       ServerAliveCountMax 3
   ```

   **Configuration Details**:
   - `Host`: A friendly name for your connection (you can use any name)
   - `HostName`: Your VM's external IP address (from GCP Console)
   - `User`: Your username on the VM (usually your GCP username or the one you set up)
   - `IdentityFile`: Path to your private SSH key
   - `ServerAliveInterval`: Keeps connection alive (optional but recommended)
   - `ServerAliveCountMax`: Maximum keepalive attempts (optional)

4. **Save the Configuration File**:
   - Press `Ctrl+S` (Windows/Linux) or `Cmd+S` (Mac)
   - The file should be saved at `~/.ssh/config`

### Step 5: Connect to VM via VS Code

1. **Open Remote-SSH Menu**:
   - Click the green icon in the bottom-left corner of VS Code
   - Or press `Ctrl+Shift+P` and type `Remote-SSH: Connect to Host...`

2. **Select Your Host**:
   - You should see `gcp-vm` (or whatever you named it) in the list
   - Click on it

3. **Select Platform** (if prompted):
   - Choose **Linux** (most GCP VMs run Linux)

4. **Enter Password/Passphrase** (if applicable):
   - If you set a passphrase for your SSH key, enter it
   - You may be asked to select the key file location

5. **Wait for Connection**:
   - VS Code will show "Opening Remote..." in the bottom-right
   - A new VS Code window may open
   - The status bar will show "SSH: gcp-vm" when connected

6. **Verify Connection**:
   - Check the bottom-left corner - it should show "SSH: gcp-vm"
   - The terminal will be connected to your remote VM

### Step 6: Navigate to Your Project Directory

1. **Open File Explorer**:
   - Click the **Explorer** icon in the left sidebar (or press `Ctrl+Shift+E`)

2. **Open Folder**:
   - Click **File** → **Open Folder...**
   - Or press `Ctrl+K Ctrl+O`

3. **Navigate to Your User Directory**:
   - The default location is usually `/home/YOUR_USERNAME/`
   - Or navigate to where your project should be located
   - Common locations:
     - `/home/YOUR_USERNAME/`
     - `/home/YOUR_USERNAME/projects/`
     - `/home/YOUR_USERNAME/Documents/`

4. **Select Your Project Folder**:
   - If you've already cloned your repository, navigate to it
   - If not, you can create a new folder or clone your repository here

5. **Open the Folder**:
   - Click **OK** or **Select Folder**
   - VS Code will open the folder in the remote workspace

## 🔧 Additional Configuration

### Setting Up Git on Remote VM

1. **Open Terminal in VS Code**:
   - Press `` Ctrl+` `` (backtick) or **Terminal** → **New Terminal**

2. **Configure Git**:
   ```bash
   git config --global user.email "your_email@example.com"
   git config --global user.name "Your Name"
   ```

3. **Clone Your Repository** (if needed):
   ```bash
   cd ~
   git clone https://github.com/your-username/your-repo.git
   ```

### Setting Up SSH Key for GitHub (Optional)

1. **Generate SSH Key on Remote VM**:
   ```bash
   ssh-keygen -t ed25519 -C "your_email@example.com"
   ```

2. **Add to SSH Agent**:
   ```bash
   eval "$(ssh-agent -s)"
   ssh-add ~/.ssh/id_ed25519
   ```

3. **Copy Public Key**:
   ```bash
   cat ~/.ssh/id_ed25519.pub
   ```

4. **Add to GitHub**:
   - Go to GitHub → Settings → SSH and GPG keys
   - Click "New SSH key"
   - Paste your public key

## 🐛 Troubleshooting

### Connection Refused

**Error**: `connect ECONNREFUSED` or `Connection refused`

**Solutions**:
1. **Check VM is running**:
   ```bash
   # In GCP Console, verify VM status is "Running"
   ```

2. **Check Firewall Rules**:
   - Ensure SSH (port 22) is allowed in firewall rules
   - Check GCP Console → VPC Network → Firewall Rules

3. **Verify External IP**:
   - Confirm the IP address in GCP Console matches your config

4. **Check SSH Service**:
   ```bash
   # If you have initial access, check SSH service
   sudo systemctl status ssh
   ```

### Permission Denied (publickey)

**Error**: `Permission denied (publickey)`

**Solutions**:
1. **Verify Public Key Added**:
   - Check GCP Console → Compute Engine → VM instances → Edit → SSH Keys
   - Ensure your public key is listed

2. **Check Key File Permissions**:
   ```bash
   # On local machine
   chmod 600 ~/.ssh/id_ed25519
   chmod 644 ~/.ssh/id_ed25519.pub
   ```

3. **Verify Username**:
   - Ensure the username in SSH config matches your GCP username
   - Try different usernames: your GCP account email, or the default user

4. **Test SSH Connection**:
   ```bash
   ssh -v gcp-vm
   # Or directly:
   ssh -i ~/.ssh/id_ed25519 YOUR_USERNAME@YOUR_VM_IP
   ```

### Host Key Verification Failed

**Error**: `Host key verification failed`

**Solution**:
```bash
# Remove old host key
ssh-keygen -R YOUR_VM_IP

# Or edit ~/.ssh/known_hosts and remove the entry for your VM IP
```

### VS Code Extension Not Working

**Solutions**:
1. **Reload VS Code**:
   - Press `Ctrl+Shift+P` → `Developer: Reload Window`

2. **Reinstall Extension**:
   - Uninstall Remote-SSH extension
   - Restart VS Code
   - Reinstall the extension

3. **Check Extension Logs**:
   - View → Output → Select "Remote-SSH" from dropdown
   - Look for error messages

### Slow Connection

**Solutions**:
1. **Add to SSH Config**:
   ```ssh-config
   Host gcp-vm
       # ... existing config ...
       Compression yes
       TCPKeepAlive yes
   ```

2. **Use VS Code Settings**:
   - File → Preferences → Settings
   - Search for "remote.SSH"
   - Adjust connection timeout settings

### Cannot Find SSH Config File

**Solution**:
1. **Create the directory** (if it doesn't exist):
   ```bash
   mkdir -p ~/.ssh
   chmod 700 ~/.ssh
   ```

2. **Create config file**:
   ```bash
   touch ~/.ssh/config
   chmod 600 ~/.ssh/config
   ```

3. **Edit in VS Code**:
   - Use Command Palette: `Remote-SSH: Open SSH Configuration File...`

## 📝 Best Practices

1. **Use SSH Keys, Not Passwords**:
   - Always use SSH key authentication for better security
   - Never share your private key

2. **Use Descriptive Host Names**:
   ```ssh-config
   Host production-vm
   Host staging-vm
   Host dev-vm
   ```

3. **Keep Keys Secure**:
   - Use passphrases for your SSH keys
   - Don't commit private keys to version control
   - Regularly rotate SSH keys

4. **Organize Multiple VMs**:
   ```ssh-config
   # Production
   Host prod-vm
       HostName 34.123.45.67
       User admin
       IdentityFile ~/.ssh/id_ed25519

   # Staging
   Host staging-vm
       HostName 35.234.56.78
       User admin
       IdentityFile ~/.ssh/id_ed25519
   ```

5. **Use VS Code Settings Sync**:
   - Enable Settings Sync to sync your VS Code configuration across machines

6. **Keep Connection Alive**:
   - Use `ServerAliveInterval` and `ServerAliveCountMax` in SSH config

## 🔒 Security Considerations

1. **Firewall Rules**:
   - Restrict SSH access to specific IP addresses when possible
   - Use GCP's Identity-Aware Proxy (IAP) for additional security

2. **Key Management**:
   - Use different SSH keys for different environments
   - Regularly rotate SSH keys
   - Use key management services for production

3. **Access Control**:
   - Limit SSH access to necessary users only
   - Use IAM roles and permissions appropriately

4. **Monitoring**:
   - Enable Cloud Logging for SSH access
   - Monitor for unauthorized access attempts

## 📚 Additional Resources

- [VS Code Remote-SSH Documentation](https://code.visualstudio.com/docs/remote/ssh)
- [GCP SSH Documentation](https://cloud.google.com/compute/docs/instances/connecting-to-instance)
- [OpenSSH Documentation](https://www.openssh.com/manual.html)
- [SSH Key Management Best Practices](https://www.ssh.com/academy/ssh/key)

## ✅ Quick Reference

### Common Commands

```bash
# Test SSH connection
ssh -v gcp-vm

# Copy file to remote
scp file.txt gcp-vm:/home/username/

# Copy file from remote
scp gcp-vm:/home/username/file.txt ./

# View SSH config
cat ~/.ssh/config

# Generate new SSH key
ssh-keygen -t ed25519 -C "your_email@example.com"

# View public key
cat ~/.ssh/id_ed25519.pub
```

### VS Code Shortcuts

- `Ctrl+Shift+P` / `Cmd+Shift+P`: Command Palette
- `Ctrl+Shift+E` / `Cmd+Shift+E`: Explorer
- `` Ctrl+` `` / `` Cmd+` ``: Terminal
- `Ctrl+K Ctrl+O`: Open Folder

---

**Last Updated**: 2025-11-23  
**VS Code Version**: Latest  
**Remote-SSH Extension**: Latest

