# WSL2・Docker・Ollama・OpenWebUI 簡単構築マニュアル【RTX 5090対応版】

## 📋 目次
1. [システム要件とRTX 5090の確認](#1-システム要件とrtx-5090の確認)
2. [WSL2のインストール（5分）](#2-wsl2のインストール5分)
3. [Docker Desktopのインストール（10分）](#3-docker-desktopのインストール10分)
4. [NVIDIA Container Toolkitの設定（5分）](#4-nvidia-container-toolkitの設定5分)
5. [Docker ComposeでOllama＋OpenWebUIを一括起動（5分）](#5-docker-composeでollamaopenwebuiを一括起動5分)
6. [gpt-oss-20bとgemma3-27bモデルの導入（WebUI上で完結）](#6-gpt-oss-20bとgemma3-27bモデルの導入webui上で完結)
7. [日本語RAG用ruri-v3の設定（WebUI上で完結）](#7-日本語rag用ruri-v3の設定webui上で完結)
8. [Windows起動時の自動起動設定（5分）](#8-windows起動時の自動起動設定5分)
9. [動作確認](#9-動作確認)
10. [トラブルシューティング](#10-トラブルシューティング)

---

## 1. システム要件とRTX 5090の確認

### 🖥️ 必須要件
- **OS**: Windows 11 または Windows 10 バージョン 2004以降
- **GPU**: NVIDIA GeForce RTX 5090（32GB VRAM）
- **メモリ**: 32GB以上推奨
- **ストレージ**: 50GB以上の空き容量

### 確認方法（PowerShell管理者権限）
```powershell
# Windowsバージョン確認
winver

# GPU確認
Get-WmiObject Win32_VideoController | Select-Object Name, DriverVersion
```

### NVIDIAドライバのインストール
1. https://www.nvidia.com/Download/index.aspx にアクセス
2. GeForce RTX 5090を選択してダウンロード（572.16以降）
3. インストール後、PCを再起動

---

## 2. WSL2のインストール（5分）

### 🚀 ワンコマンドでインストール

PowerShellを管理者として開き、以下を実行：

```powershell
# WSL2を一括インストール
wsl --install

# PCを再起動（重要！）
```

再起動後、Ubuntuが自動的に起動します：
- ユーザー名とパスワードを設定（覚えておく）
- 設定が完了したらUbuntuのウィンドウは閉じてOK

---

## 3. Docker Desktopのインストール（10分）

### 🐳 インストール手順

1. **ダウンロード**
   - https://www.docker.com/products/docker-desktop/ からダウンロード

2. **インストール時の設定**
   - ✅ Use WSL 2 instead of Hyper-V（チェック）
   - ✅ Add shortcut to desktop（チェック）

3. **初回起動と設定**
   - Docker Desktopを起動
   - 利用規約に同意
   - Settings → General → 「Start Docker Desktop when you sign in」をON
   - Settings → Resources → WSL Integration → Ubuntu-24.04をON
   - Apply & Restart

---

## 4. NVIDIA Container Toolkitの設定（5分）

### 🎮 GPUをDockerで使用可能にする（必須）

この手順により、DockerコンテナからRTX 5090を使用できるようになります。

1. **WSL2のUbuntuを開く**
   - Windowsスタートメニューから「Ubuntu」を起動

2. **NVIDIA Container Toolkitのインストール**
   
   以下のコマンドを順番に実行：

```bash
# GPGキーの追加
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

# リポジトリの追加
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# パッケージリストの更新
sudo apt-get update

# NVIDIA Container Toolkitのインストール
sudo apt-get install -y nvidia-container-toolkit

# Docker daemonの設定
sudo nvidia-ctk runtime configure --runtime=docker
```

3. **Docker Desktopの再起動**
   - システムトレイのDockerアイコンを右クリック
   - 「Quit Docker Desktop」をクリック
   - デスクトップのDocker Desktopアイコンから再起動

4. **GPU認識の確認**
   
   WSL2のUbuntuで以下を実行：
```bash
# GPUが正しく認識されているか確認
docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi
```
   
   RTX 5090の情報が表示されればOK！表示されない場合は、トラブルシューティングを参照。

---

## 5. Docker ComposeでOllama＋OpenWebUIを一括起動（5分）

### 📦 セットアップファイルの作成

1. **デスクトップに`ai-setup`フォルダを作成**

2. **メモ帳で`docker-compose.yml`を作成**
   - フォルダ内で右クリック → 新規作成 → テキストドキュメント
   - 名前を`docker-compose.yml`に変更（拡張子も変更）

3. **以下の内容をコピー＆ペースト**：

```yaml
version: '3.8'

services:
  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    volumes:
      - ollama_data:/root/.ollama
    ports:
      - "11434:11434"
    restart: always
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
    environment:
      - OLLAMA_GPU_MEMORY=30g
      - OLLAMA_MAX_MEMORY=30g

  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui
    volumes:
      - open-webui_data:/app/backend/data
    depends_on:
      - ollama
    ports:
      - "3000:8080"
    environment:
      - OLLAMA_BASE_URL=http://ollama:11434
      - WEBUI_SECRET_KEY=your-secret-key-change-this
      - ENABLE_RAG_WEB_SEARCH=true
      - RAG_EMBEDDING_ENGINE=ollama
      - RAG_EMBEDDING_MODEL=kun432/cl-nagoya-ruri-large:latest
      - CUDA_VISIBLE_DEVICES=0
      - ENABLE_SIGNUP=true
    restart: always

volumes:
  ollama_data:
  open-webui_data:
```

4. **サービスの起動**
   - PowerShellでフォルダに移動：
   ```powershell
   cd OneDrive\Desktop\ai-setup
   docker-compose up -d
   ```

5. **初回セットアップ（3分待機後）**
   - ブラウザで http://localhost:3000 にアクセス
   - 最初のユーザーを作成（管理者になります）
   - メールアドレスとパスワードを設定

---

## 6. gpt-oss-20bとgemma3-27bモデルの導入（WebUI上で完結）

WebUIから主要なLLMを簡単に追加できます。ここでは代表的な2つのモデルを導入します。

### 🤖 gpt-oss-20bの導入

1. **OpenWebUIにログイン**
   - http://localhost:3000

2. **モデルのダウンロード**
   - 左側メニューの「⚙️ Settings」をクリック
   - 「Models」タブを選択
   - 「Pull a model from Ollama」の入力欄に以下を入力：
   ```
   gpt-oss:20b
   ```
   - 「Download」ボタンをクリック
   - ダウンロード進捗がリアルタイムで表示されます（約12.4GB、10-15分）

3. **モデルの確認**
   - ダウンロード完了後、チャット画面上部のモデル選択で「gpt-oss:20b」が選択可能に

### ✨ gemma3-27bの導入

1. **モデルのダウンロード**
   - 同様に「Pull a model from Ollama」の入力欄に以下を入力：
   ```
   gemma3:27b
   ```
   - 「Download」ボタンをクリック
   - ダウンロード進捗がリアルタイムで表示されます（約16.2GB、15-20分）

2. **モデルの確認**
   - ダウンロード完了後、チャット画面上部のモデル選択で「gemma3:27b」が選択可能に

---

## 7. 日本語RAG用ruri-v3の設定（WebUI上で完結）

### 🗾 日本語埋め込みモデルの導入

1. **ruri-v3モデルのダウンロード（WebUI上）**
   - Settings → Models
   - 「Pull a model from Ollama」に以下を入力：
   ```
   kun432/cl-nagoya-ruri-large
   ```
   - 「Download」ボタンをクリック（約1GB、2-3分）

2. **RAG設定の最適化**
   - Settings → Admin Settings → Documents
   - 以下の設定を適用：

   | 設定項目 | 値 |
   |---------|-----|
   | Content Extraction Engine | **Default** |
   | Text Splitter | **Recursive Character** |
   | Chunk Size | **1024** |
   | Chunk Overlap | **200** |
   | Embedding Model Engine | **Ollama** |
   | Embedding Model | **kun432/cl-nagoya-ruri-large:latest** |
   | Full Context Mode | **OFF** |
   | Hybrid Search | **ON** |
   | Top K | **5** |
   | Minimum Score | **0.3** |

3. **保存**
   - 「Save」ボタンをクリック

### 📄 文書のアップロード方法
1. チャット画面の「📎」アイコンをクリック
2. PDFやテキストファイルをドラッグ＆ドロップ
3. アップロード完了後、「#」を入力すると文書名が表示
4. 文書を参照しながら質問可能

---

## 8. Windows起動時の自動起動設定（5分）

### 🚀 完全自動化の設定

1. **起動スクリプトの作成**
   - デスクトップに`start-ai.bat`を作成
   - 以下の内容をコピー＆ペースト：

```batch
@echo off
echo AI Services Starting...

REM Docker Desktopが起動するまで待機
timeout /t 30 /nobreak > nul

REM Docker Composeでサービスを起動
cd /d "%USERPROFILE%\Desktop\ai-setup"
docker compose up -d

echo All services started!
echo Access OpenWebUI at http://localhost:3000
pause
```

2. **タスクスケジューラに登録**
   - Windowsキー + R → `taskschd.msc`と入力
   - 「タスクの作成」をクリック
   
   **「全般」タブ：**
   - 名前：`Start AI Services`
   - 「ユーザーがログオンしているときのみ実行する」を選択
   - 「最上位の特権で実行する」にチェック
   
   **「トリガー」タブ：**
   - 「新規」をクリック
   - 「ログオン時」を選択
   - 「遅延時間を指定する」にチェック → 30秒
   
   **「操作」タブ：**
   - 「新規」をクリック
   - プログラム：`%USERPROFILE%\Desktop\start-ai.bat`
   
   **「条件」タブ：**
   - すべてのチェックを外す
   
   **「設定」タブ：**
   - 「タスクが失敗した場合の再起動の間隔」：1分
   - 「再起動試行の最大数」：3回

3. **Docker Desktopの自動起動確認**
   - Docker Desktop → Settings → General
   - 「Start Docker Desktop when you sign in」がONになっていることを確認

---

## 9. 動作確認

### ✅ サービスの確認

1. **Dockerコンテナの状態確認**
   ```powershell
   docker ps
   ```
   → ollama と open-webui の2つのコンテナが「Up」状態

2. **GPU使用状況の確認**
   ```powershell
   # WSL2で実行
   wsl
   docker exec ollama nvidia-smi
   ```
   → RTX 5090のメモリ使用状況が表示される

3. **OpenWebUIアクセス**
   - http://localhost:3000
   - ログインして動作確認

4. **モデルのテスト**
   - **gpt-oss-20b**: モデル選択で`gpt-oss:20b`を選択し、「こんにちは、日本語で答えてください」と入力して応答を確認。
   - **gemma3-27b**: モデル選択で`gemma3:27b`を選択し、「日本の首都について教えてください」と入力して応答を確認。

5. **RAGのテスト**
   - PDFをアップロード
   - 「#」を付けて文書を選択
   - 文書に関する質問をする

### 📊 期待されるパフォーマンス（RTX 5090）

| モデル | 推論速度 (tokens/秒) | メモリ使用量 (VRAM) |
|---|---|---|
| **gpt-oss:20b** | 30-50 | 約16GB |
| **gemma3:27b** | 25-45 | 約18GB |

- **起動時間**：Docker起動後約1分

---

## 10. トラブルシューティング

### ❗ よくある問題と解決方法

#### 問題1：「localhost:3000に接続できない」
```powershell
# Dockerサービスの再起動
docker compose down
docker compose up -d
```

#### 問題2：GPUが認識されない
```powershell
# WSL2でGPU確認
wsl nvidia-smi

# 表示されない場合、WSL2カーネルを更新
wsl --update --pre-release

# NVIDIA Container Toolkitの再インストール（WSL2内）
sudo apt-get remove nvidia-container-toolkit
sudo apt-get install nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker

# Docker Desktopを再起動
```

#### 問題3：「docker: Error response from daemon: could not select device driver "" with capabilities: [[gpu]]」
これはNVIDIA Container Toolkitが正しくインストールされていない場合に発生します。
- セクション4の手順を再実行
- Docker Desktopを完全に終了して再起動
- 必要に応じてPCを再起動

#### 問題4：モデルのダウンロードが遅い
- ネットワーク速度を確認
- Docker Desktop → Settings → Resources → Network でプロキシ設定を確認

#### 問題5：メモリ不足エラー
```powershell
# WSL2のメモリ制限を増やす
notepad $env:USERPROFILE\.wslconfig
```
以下を追加：
```ini
[wsl2]
memory=48GB
processors=16
localhostForwarding=true
```
その後：
```powershell
wsl --shutdown
```

#### 問題6：自動起動が動作しない
- タスクスケジューラで「前回の実行結果」を確認
- Docker Desktopが起動しているか確認
- 遅延時間を60秒に増やす

### 🔧 ログの確認方法
```powershell
# Ollamaのログ
docker logs ollama

# OpenWebUIのログ
docker logs open-webui

# リアルタイム監視
docker logs -f open-webui

# GPU使用状況のリアルタイム監視（WSL2内）
watch -n 1 docker exec ollama nvidia-smi
```

### 🛠️ 完全リセット方法
問題が解決しない場合の最終手段：
```powershell
# すべてのコンテナとボリュームを削除
docker compose down -v

# Dockerイメージの削除
docker rmi ollama/ollama ghcr.io/open-webui/open-webui:main

# 再度起動
docker compose up -d
```

---

## 🎉 完成！

これで最新のAI環境が構築できました。すべての操作がGUI上で完結し、Windows起動時に自動的に立ち上がります。

### 主な利点
- **CLI操作最小限**：ほぼすべてWebUI上で操作
- **GPU完全対応**：RTX 5090の性能をフル活用
- **自動起動**：Windows起動時に全サービスが自動起動
- **簡単管理**：Docker Desktopで視覚的に管理
- **日本語対応**：ruri-v3による高精度な日本語RAG

### 次のステップ
1. 他のモデルの追加（llama3.2、mistral等）
2. カスタムプロンプトの作成
3. API経由での外部連携
4. マルチモデル比較による最適化

### 参考リンク
- [OpenWebUI公式ドキュメント](https://docs.openwebui.com/)
- [Ollama公式サイト](https://ollama.com/)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
