# WSL2・Ubuntu・Docker・Ollama・OpenWebUI・Dify 完全構築マニュアル【RTX 5090対応版】

## 📋 目次
1. [事前準備とRTX 5090の確認](#1-事前準備とrtx-5090の確認)
2. [WSL2のインストールとGPU対応設定](#2-wsl2のインストールとgpu対応設定)
3. [Ubuntuのインストールと初期設定](#3-ubuntuのインストールと初期設定)
4. [Docker Desktopのインストール](#4-docker-desktopのインストール)
5. [CUDA Toolkitのインストール（RTX 5090対応）](#5-cuda-toolkitのインストールrtx-5090対応)
6. [Ollamaのインストールと設定](#6-ollamaのインストールと設定)
7. [Gemma 3 27Bモデルの導入](#7-gemma-3-27bモデルの導入)
8. [OpenWebUIのインストールとRAG設定](#8-openwebuiのインストールとrag設定)
9. [ruri-v3の導入（日本語RAG用）](#9-ruri-v3の導入日本語rag用)
10. [Difyのインストール](#10-difyのインストール)
11. [自動起動の設定](#11-自動起動の設定)
12. [動作確認とベンチマーク](#12-動作確認とベンチマーク)
13. [トラブルシューティング](#13-トラブルシューティング)

---

## 1. 事前準備とRTX 5090の確認

### 🖥️ システム要件の確認

**必須要件：**
- Windows 11 または Windows 10 バージョン 2004以降（ビルド 19041以降）
- **GPU：NVIDIA GeForce RTX 5090**
- メモリ：32GB以上（推奨：64GB以上）
- ストレージ：100GB以上の空き容量
- 電源：1000W以上のPSU（RTX 5090は575W TGP）

### RTX 5090の仕様確認
```
- CUDAコア数：21,760
- メモリ：32GB GDDR7
- メモリ帯域：1,792 GB/s
- Compute Capability：sm_120（Blackwellアーキテクチャ）
- CUDA 12.8対応
```

### 確認方法

1. **Windowsバージョンの確認**
   ```cmd
   winver
   ```

2. **GPUの確認（PowerShell管理者権限）**
   ```powershell
   Get-WmiObject Win32_VideoController | Select-Object Name, DriverVersion
   ```

3. **最新のNVIDIAドライバのインストール**
   - https://www.nvidia.com/Download/index.aspx にアクセス
   - 「GeForce RTX 5090」を選択
   - Windows 11/10用のGame Readyドライバ（572.16以降）をダウンロード
   - **重要**：WSL2用にLinuxドライバは不要（Windowsドライバを共有）

---

## 2. WSL2のインストールとGPU対応設定

### 🚀 WSL2のインストール

1. **PowerShellを管理者として開く**
   ```powershell
   wsl --install
   ```

2. **PCを再起動**

3. **WSL2をデフォルトバージョンに設定**
   ```powershell
   wsl --set-default-version 2
   ```

4. **WSLカーネルを最新に更新**
   ```powershell
   wsl --update
   wsl --shutdown
   ```

### GPU対応の確認
```powershell
# WSL2でGPUが認識されているか確認
wsl nvidia-smi
```

期待される出力：
```
+-------------------------------------------------------------------------+
| NVIDIA-SMI 572.16       Driver Version: 572.16       CUDA Version: 12.8 |
|-------------------------------+----------------------+-------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|===============================+======================+===================+
|   0  NVIDIA GeForce RTX 5090  Off | 00000000:01:00.0 Off |                  N/A |
```

---

## 3. Ubuntuのインストールと初期設定

### 🐧 Ubuntu 24.04 LTSのインストール

1. **Microsoft Storeから Ubuntu 24.04 LTSをインストール**
   - または PowerShellで：
   ```powershell
   wsl --install -d Ubuntu-24.04
   ```

2. **初回起動時の設定**
   ```bash
   Enter new UNIX username: [ユーザー名]
   New password: [パスワード]
   Retype new password: [パスワード再入力]
   ```

3. **システムの更新と必要なパッケージのインストール**
   ```bash
   sudo apt update && sudo apt upgrade -y
   sudo apt install -y curl wget git nano build-essential
   ```

4. **GPUの確認（Ubuntu内）**
   ```bash
   nvidia-smi
   ```

---

## 4. Docker Desktopのインストール

### 🐳 Docker Desktop for Windowsの設定

1. **Docker Desktopをダウンロード**
   - https://www.docker.com/products/docker-desktop/

2. **インストール時の設定**
   - ✅ Use WSL 2 instead of Hyper-V
   - ✅ Add shortcut to desktop

3. **Docker Desktopの設定**
   - Settings → Resources → WSL Integration
   - Ubuntu-24.04のトグルをON
   - Apply & Restart

4. **Docker Composeの確認**
   ```bash
   docker --version
   docker compose version
   ```

---

## 5. CUDA Toolkitのインストール（RTX 5090対応）

### 🔧 CUDA 12.8のインストール（WSL2内）

⚠️ **重要**：WSL2専用のCUDA Toolkitをインストール（ドライバは含まれない）

```bash
# CUDA 12.8のインストール
wget https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt-get update
sudo apt-get -y install cuda-toolkit-12-8

# 環境変数の設定
echo 'export PATH=/usr/local/cuda-12.8/bin:$PATH' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=/usr/local/cuda-12.8/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc
source ~/.bashrc

# 確認
nvcc --version
```

---

## 6. Ollamaのインストールと設定

### 🤖 Ollamaのセットアップ

1. **Ollamaをインストール**
   ```bash
   curl -fsSL https://ollama.com/install.sh | sh
   ```

2. **Ollamaサービスの起動**
   ```bash
   sudo systemctl start ollama
   sudo systemctl enable ollama
   ```

3. **GPU使用の最適化設定**
   ```bash
   # メモリ設定（RTX 5090の32GBを活用）
   export OLLAMA_GPU_MEMORY=30g
   export OLLAMA_MAX_MEMORY=30g
   
   # ~/.bashrcに追加
   echo 'export OLLAMA_GPU_MEMORY=30g' >> ~/.bashrc
   echo 'export OLLAMA_MAX_MEMORY=30g' >> ~/.bashrc
   ```

---

## 7. Gemma 3 27Bモデルの導入

### 📥 Gemma 3 27Bのインストール

1. **モデルのダウンロード（量子化版を選択）**
   ```bash
   # 4ビット量子化版（約17GB、推奨）
   ollama pull gemma3:27b-q4_K_M
   
   # または8ビット量子化版（メモリに余裕がある場合）
   # ollama pull gemma3:27b-q8_0
   ```

2. **モデルの動作確認**
   ```bash
   ollama run gemma3:27b-q4_K_M "こんにちは、日本語で答えてください。"
   ```

3. **パフォーマンス設定の最適化**
   ```bash
   # コンテキスト長を8192に設定（デフォルト2048から拡張）
   ollama run gemma3:27b-q4_K_M --num-ctx 8192
   ```

---

## 8. OpenWebUIのインストールとRAG設定

### 🌐 Docker Composeを使用したOpenWebUIのセットアップ

1. **設定ディレクトリの作成**
   ```bash
   mkdir -p ~/openwebui && cd ~/openwebui
   ```

2. **docker-compose.ymlの作成**
   ```yaml
   cat <<EOF > docker-compose.yml
   version: '3.8'
   
   services:
     ollama:
       image: ollama/ollama:latest
       container_name: ollama
       volumes:
         - ollama:/root/.ollama
       ports:
         - "11434:11434"
       restart: unless-stopped
       deploy:
         resources:
           reservations:
             devices:
               - driver: nvidia
                 count: 1
                 capabilities: [gpu]
   
     open-webui:
       image: ghcr.io/open-webui/open-webui:main
       container_name: open-webui
       volumes:
         - open-webui:/app/backend/data
       depends_on:
         - ollama
       ports:
         - "3000:8080"
       environment:
         - OLLAMA_BASE_URL=http://ollama:11434
         - WEBUI_SECRET_KEY=your-secret-key-here
         - ENABLE_RAG_WEB_SEARCH=true
         - RAG_EMBEDDING_ENGINE=ollama
         - CUDA_VISIBLE_DEVICES=0
       restart: unless-stopped
   
   volumes:
     ollama:
     open-webui:
   EOF
   ```

3. **OpenWebUIの起動**
   ```bash
   docker compose up -d
   ```

4. **初回アクセスとセットアップ**
   - ブラウザで http://localhost:3000 にアクセス
   - 管理者アカウントを作成

---

## 9. ruri-v3の導入（日本語RAG用）

### 🗾 日本語埋め込みモデルの設定

1. **ruri-v3モデルのダウンロード（Ollama用）**
   ```bash
   # paraphrase-multilingualを代替として使用（Ollama対応）
   ollama pull paraphrase-multilingual
   ```

2. **OpenWebUIでのRAG設定**
   - Settings → Admin Settings → Documents
   - 以下の設定を適用：

   ```
   Content Extraction Engine: Tika
   Text Splitter: Recursive Character
   Chunk Size: 1024
   Chunk Overlap: 100
   Embedding Model Engine: Ollama
   Embedding Model: paraphrase-multilingual:latest
   Full Context Mode: OFF
   Hybrid Search: ON
   Reranking Model: （空欄）
   Top K: 8
   Minimum Score: 0.3
   ```

3. **日本語文書の最適化設定**
   ```bash
   # OpenWebUIコンテナ内でTikaの日本語対応を確認
   docker exec -it open-webui bash
   apt-get update && apt-get install -y tesseract-ocr-jpn
   exit
   ```

### 高度なruri-v3設定（オプション）

**Sentence Transformersを使用する場合**（より高精度）：

1. **カスタムDockerイメージの作成**
   ```dockerfile
   cat <<EOF > Dockerfile.custom
   FROM ghcr.io/open-webui/open-webui:main
   
   # PyTorchのCUDA対応版をインストール
   RUN pip install --upgrade torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
   
   # sentence-transformersをインストール
   RUN pip install sentence-transformers
   
   # 日本語処理用ライブラリ
   RUN pip install fugashi ipadic
   EOF
   ```

2. **docker-compose.ymlを更新**
   ```yaml
   open-webui:
     build:
       context: .
       dockerfile: Dockerfile.custom
   ```

---

## 10. Difyのインストール

### 🎯 Difyのセットアップ

1. **Difyのクローンと設定**
   ```bash
   cd ~
   git clone https://github.com/langgenius/dify.git
   cd dify/docker
   cp .env.example .env
   ```

2. **環境変数の編集**
   ```bash
   nano .env
   # 以下を追加/変更
   # OLLAMA_URL=http://host.docker.internal:11434
   ```

3. **Difyの起動**
   ```bash
   docker compose up -d
   ```

---

## 11. 自動起動の設定

### 🚀 Windows起動時の完全自動化

1. **起動スクリプトの作成**
   ```batch
   mkdir %USERPROFILE%\startup-scripts
   ```

2. **start-ai-services.bat の作成**
   ```batch
   @echo off
   echo AI Services Starting...
   
   REM Docker Desktopを起動
   start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"
   
   REM Docker起動待機
   timeout /t 20 /nobreak > nul
   
   REM WSL2でサービスを起動
   wsl -d Ubuntu-24.04 -u root bash -c "systemctl start ollama"
   
   REM OpenWebUIとOllamaを起動
   wsl -d Ubuntu-24.04 bash -c "cd ~/openwebui && docker compose up -d"
   
   REM Difyを起動
   wsl -d Ubuntu-24.04 bash -c "cd ~/dify/docker && docker compose up -d"
   
   REM Gemma 3 27Bモデルをプリロード
   timeout /t 10 /nobreak > nul
   wsl -d Ubuntu-24.04 bash -c "ollama run gemma3:27b-q4_K_M 'システム起動確認' > /dev/null 2>&1 &"
   
   echo All AI services started successfully!
   pause
   ```

3. **タスクスケジューラへの登録**
   ```powershell
   $action = New-ScheduledTaskAction -Execute "$env:USERPROFILE\startup-scripts\start-ai-services.bat"
   $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
   $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest
   $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
   
   Register-ScheduledTask -TaskName "Start AI Services" -Action $action -Trigger $trigger -Principal $principal -Settings $settings
   ```

---

## 12. 動作確認とベンチマーク

### ✅ システム全体の確認

1. **GPU使用状況の確認**
   ```bash
   # リアルタイムモニタリング
   watch -n 1 nvidia-smi
   ```

2. **各サービスの状態確認**
   ```bash
   # Ollamaの確認
   ollama list
   curl http://localhost:11434/api/tags
   
   # Dockerコンテナの確認
   docker ps
   
   # メモリ使用状況
   free -h
   ```

3. **Gemma 3 27Bのベンチマーク**
   ```bash
   # 推論速度テスト
   time ollama run gemma3:27b-q4_K_M "Explain quantum computing in simple terms"
   ```

4. **RAGシステムのテスト**
   - OpenWebUI（http://localhost:3000）にアクセス
   - 日本語PDFをアップロード
   - 「#」を付けて文書を参照しながら質問

### 🎯 パフォーマンス最適化のヒント

1. **バッチサイズの調整**
   ```bash
   export OLLAMA_NUM_PARALLEL=4  # 並列処理数
   ```

2. **キャッシュの設定**
   ```bash
   export OLLAMA_MODELS=/path/to/fast/ssd  # 高速SSDに移動
   ```

---

## 13. トラブルシューティング

### ❗ よくある問題と解決方法

#### 問題1: RTX 5090が認識されない
```bash
# WSL2カーネルの更新
wsl --update --pre-release

# Windowsドライバの再インストール
# DDU（Display Driver Uninstaller）でクリーンインストール
```

#### 問題2: CUDA 12.8エラー
```bash
# PyTorchのCUDA 12.8対応確認
python -c "import torch; print(torch.cuda.is_available())"

# 必要に応じてPyTorchを更新
pip install --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu121
```

#### 問題3: メモリ不足（32GB VRAM使用時）
```bash
# WSL2のメモリ制限を調整
cat <<EOF > /mnt/c/Users/$USER/.wslconfig
[wsl2]
memory=48GB
processors=16
localhostForwarding=true
EOF

wsl --shutdown
```

#### 問題4: OpenWebUIでRAGが遅い
```yaml
# docker-compose.ymlに追加
environment:
  - OLLAMA_FLASH_ATTENTION=1
  - OLLAMA_KV_CACHE_TYPE=q8_0
```

#### 問題5: Gemma 3 27Bの応答が遅い
```bash
# GPUレイヤー数を最適化
export OLLAMA_GPU_LAYERS=62  # RTX 5090用に調整
```

### 🔧 高度なデバッグ

1. **CUDAの詳細情報**
   ```bash
   nvidia-smi -q
   ```

2. **Dockerログの確認**
   ```bash
   docker logs -f ollama
   docker logs -f open-webui
   ```

3. **システムリソースの監視**
   ```bash
   htop  # CPU/メモリ
   nvtop  # GPU詳細
   ```

---

## 🎉 完成！

これで、RTX 5090を活用した最先端のAI環境が構築できました。

### 📊 期待されるパフォーマンス
- **Gemma 3 27B推論速度**：約30-50 tokens/秒（RTX 5090）
- **RAG検索速度**：1秒以内（1000文書）
- **同時処理能力**：4-8並列リクエスト

### 次のステップ
1. 他の大規模モデルの導入（Llama 3.3 70B、DeepSeek-R1など）
2. カスタムRAGパイプラインの構築
3. DifyでのワークフローGemma 3とruri-v3の連携

### 参考リンク
- [NVIDIA CUDA on WSL](https://docs.nvidia.com/cuda/wsl-user-guide/)
- [Ollama公式](https://ollama.com/)
- [OpenWebUI Docs](https://docs.openwebui.com/)
- [ruri-v3論文](https://arxiv.org/abs/2409.07737)
- [Dify Docs](https://docs.dify.ai/)

ご不明な点があれば、各サービスのログを確認し、上記のトラブルシューティングを参考にしてください。
