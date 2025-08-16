# setup_embed_python

このリポジトリは、Windows環境で埋め込み Python をセットアップし、  
Pythonスクリプトを簡単に実行できるようにするサンプルプロジェクトです。  

## 構成

- `setup_embed_python.ps1` : PowerShellによるセットアップスクリプト
- `source/` : Pythonスクリプト（例: `main.py`）
- `requirements.txt` : 必要なPythonパッケージ一覧 (サンプル) モジュールのインストールには `uv.exe` を使用します。
- `run.bat` : Windows用の実行バッチファイル (サンプル)

## setup_embed_python.ps1 の概要

Windows Releaseフォルダ用の埋め込み版Python環境を自動セットアップするPowerShellスクリプトです。

### 主な機能・ワークフロー

- 既存のPython環境フォルダ（例: python310等）の検出と削除
- Python公式サイトから3.9以降のバージョン一覧取得・対話的選択
- 選択バージョンのembeddable zipの自動ダウンロード・展開
- site有効化や追加パス設定の自動化（`$extraPaths`でカスタマイズ可能）
- 最新のuv.exeをGitHubから取得
- uv.exeまたはpipによるrequirements.txtの依存モジュール自動インストール
- run.batの自動生成（main.pyを埋め込みPythonで起動）

## 使い方

PowerShellで右クリック「PowerShellで実行」またはターミナルから実行できます。

## run.batの実行

1. `run.bat` をダブルクリックまたはターミナルから実行
2. 埋め込みPython環境が起動し、`source/main.py` が実行されます。
3. 引数にPythonファイルを指定すると、任意のPythonスクリプトを実行できます。  
   例: `run.bat source/your_script.py`
