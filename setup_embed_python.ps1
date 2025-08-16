# =============================================
# setup_embed_python.ps1
# ---------------------------------------------
# Windows 組み込み版 Python 環境セットアップ自動化スクリプト
#
# 【主な機能・ワークフロー】
#   - 既存Python環境フォルダ(例: python310等)を検出し、ユーザー確認後に安全に削除
#   - Python公式サイトから3.9以降のバージョン一覧を取得し、対話的にバージョン選択
#   - 選択バージョンのembeddable zipが存在するか自動判定し、最新版を推奨
#   - 組み込み版zipをダウンロード・展開し、site有効化や追加パス設定を自動化
#       ※ 追加パスを変更したい場合は $extraPaths を編集してください
#   - 最新のuv.exeをGitHubからダウンロード
#   - uv.exeを使ってpipインストールとrequirements.txtによる依存モジュール自動インストール
#       - uv.exe が利用できない場合は、公式から get-pip.py をダウンロードして pip をインストール
#
# 【実行例】
#   - PowerShellで本スクリプトを右クリック「PowerShellで実行」またはターミナルから実行
# =============================================

# 検索パスに追加するパスのリストを作成 (必要に応じて修正)
#  - パスを追加する際にはカンマ区切りで追加 ("pathA", "pathB" など)
#  - パスは Python.exe のあるディレクトリからの相対パスを指定する
$extraPaths = @(
    "../source"
)

$ftpBase = "https://www.python.org/ftp/python/"
$response = Invoke-WebRequest -Uri $ftpBase

# 元のディレクトリを保存
$originalDir = Get-Location

try {
    # Releaseフォルダの作成と移動
    $releaseDir = Join-Path $PSScriptRoot "."
    $releaseDir = [System.IO.Path]::GetFullPath($releaseDir)

    if (-not (Test-Path $releaseDir)) {
        New-Item -ItemType Directory -Path $releaseDir | Out-Null
    }
    Set-Location $releaseDir

    # コマンドラインオプション判定: --pip があれば uv を使わず pip のみ（foreach の外に移動）
    $forcePip = $false
    if ($args -contains "--pip") {
        $forcePip = $true
        Write-Host "--pip オプション指定: uv を使わず pip のみでインストールします。" -ForegroundColor Yellow
    }
    # Python***フォルダを確認し、存在する場合は削除するかユーザに確認
    $pythonDirs = Get-ChildItem -Path $releaseDir -Directory | Where-Object { $_.Name -match '^python(\d+|\d+\.\d+)$' }
    foreach ($pyDir in $pythonDirs) {
        $dirName = $pyDir.Name
        Write-Host "検出: $dirName" -ForegroundColor Yellow
        $ans = Read-Host "[$dirName] フォルダが既に存在します。削除してよろしいですか？ (y/N)"
        if ($ans -eq "y" -or $ans -eq "Y") {
            Remove-Item $pyDir.FullName -Recurse -Force
            Write-Host "$dirName フォルダを削除しました。" -ForegroundColor Green
        }
        else {
            Write-Host "処理を中断します。" -ForegroundColor Yellow
            exit 1
        }
    }

    # 全バージョン取得
    $allVersions = ($response.Content -split "`n") |
        Where-Object { $_ -match 'href="(\d+\.\d+\.\d+)/"' } |
        ForEach-Object { ($_ -replace '.*href="([^"]+)/".*', '$1') } |
        Where-Object { $_ -like "3.*" }

    # 3.9以上のメジャーバージョン抽出（昇順）
    $majorVersions = $allVersions |
        ForEach-Object { ($_ -split '\.')[0..1] -join '.' } |
        Where-Object { [version]$_ -ge [version]"3.9" } |
        Sort-Object { [version]$_ } -Unique

    # まずメジャーバージョン選択
    Write-Host "`n== メジャーバージョンを選択してください (3.9以降) =="
    for ($i = 0; $i -lt $majorVersions.Count; $i++) {
        Write-Host "[$i] $($majorVersions[$i])"
    }
    $majorIndex = Read-Host "番号を入力してください"
    if ($majorIndex -notmatch '^\d+$' -or [int]$majorIndex -ge $majorVersions.Count) {
        Write-Error "無効な入力です"
        exit 1
    }
    $selectedMajor = $majorVersions[$majorIndex]

    # 選択したメジャーバージョンに該当する全パッチバージョンを抽出
    $patchVersions = $allVersions | Where-Object { $_ -like "$selectedMajor.*" } | Sort-Object { [version]$_ }

    # ↓ ここで組み込み版存在チェックをしてフィルターする
    Write-Host "組み込み版の存在チェックをしています。少々お待ちください..." -ForegroundColor Cyan

    $validPatchVersions = @()
    foreach ($ver in $patchVersions) {
        $zipUrl = "$ftpBase$ver/python-$ver-embed-amd64.zip"
        try {
            # HEAD リクエストで存在確認
            Invoke-WebRequest -Uri $zipUrl -Method Head -ErrorAction Stop | Out-Null
            $validPatchVersions += $ver
        }
        catch {
            # 存在しない場合は無視
        }
    }

    if ($validPatchVersions.Count -eq 0) {
        Write-Warning "選択したメジャーバージョンに組み込み版が存在しません。"
        exit 1
    }

    # 有効なパッチバージョンを昇順で表示
    $validPatchVersions = $validPatchVersions | Sort-Object { [version]$_ }

    Write-Host "`n== 組み込み版が存在するパッチバージョンを選択してください =="
    for ($i = 0; $i -lt $validPatchVersions.Count; $i++) {
        Write-Host "[$i] $($validPatchVersions[$i])"
    }
    # デフォルトで最新版（昇順なので最後が最新版）
    $defaultPatchIndex = $validPatchVersions.Count - 1
    $patchIndex = Read-Host "番号を入力してください（Enterで最新版: $defaultPatchIndex）"
    if ($patchIndex -eq "") {
        $patchIndex = $defaultPatchIndex
    }
    if ($patchIndex -notmatch '^\d+$' -or [int]$patchIndex -ge $validPatchVersions.Count) {
        Write-Error "無効な入力です"
        exit 1
    }

    $version = $validPatchVersions[$patchIndex]
    Write-Host "`n選択されたバージョン: $version" -ForegroundColor Green

    Write-Host "`n組み込み版Pythonをダウンロードします。" -ForegroundColor Cyan
    Read-Host -Prompt "任意のキーを押してください..."

    # バージョン入力
    # $version = Read-Host "Pythonバージョンを入力してください (例: 3.10.11)"

    # バージョン文字列処理
    # $shortVersion = $version -replace '\.', ''        # 例: 31011
    $majorMinor = ($version -split '\.')[0..1] -join '.' # 3.10
    $embedName = "python-$version-embed-amd64.zip"
    $downloadUrl = "https://www.python.org/ftp/python/$version/$embedName"
    $targetFolder = "python$($majorMinor -replace '\.', '')"

    # 作業ディレクトリの作成
    New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null

    # ダウンロード
    $zipPath = "$targetFolder\$embedName"
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath

    # 展開
    Expand-Archive -Path $zipPath -DestinationPath $targetFolder -Force
    Remove-Item $zipPath

    # site 有効化: python3xx._pth を編集
    $pthFile = Get-ChildItem -Path $targetFolder -Filter "python*._pth" | Select-Object -First 1
    if ($pthFile) {
        $pthPath = $pthFile.FullName

        # site のインポートを有効化
        Write-Host "`n== $($pthFile.Name) の 'import site' を有効化します =="
        (Get-Content $pthPath) |
            ForEach-Object { $_ -replace '^#import site', 'import site' } |
            Set-Content $pthPath
        Write-Host "$($pthFile.Name) の 'import site' を有効化しました" -ForegroundColor Green

        # . のみの行の直後にパスを1行ずつ追加
        Write-Host "`n== $($pthFile.Name) に追加パスを追記します =="
        $pthLines = Get-Content $pthPath
        $newPthLines = @()
        for ($i = 0; $i -lt $pthLines.Count; $i++) {
            $newPthLines += $pthLines[$i]
            if ($pthLines[$i] -eq ".") {
                $newPthLines += $extraPaths
            }
        }
        Set-Content $pthPath $newPthLines
        Write-Host "追加パスを $($pthFile.Name) に追記しました" -ForegroundColor Green
    }
    else {
        Write-Error "_pth ファイルが見つからなかったため、セットアップを中断します。"
        exit 1
    }

    # 最新のuv.exeをGithubからReleaseフォルダにダウンロード・解凍
    function DownloadAndExtractUvExe {
        param (
            [string]$releaseDir
        )
        Write-Host "`n`nGithubから最新のuv.exeをダウンロードしています..." -ForegroundColor Cyan
        $uvApiUrl = "https://api.github.com/repos/astral-sh/uv/releases/latest"
        $uvRelease = Invoke-RestMethod -Uri $uvApiUrl

        $uvAsset = $null
        $uvAsset = $uvRelease.assets | Where-Object { $_.name -eq "uv-x86_64-pc-windows-msvc.zip" } | Select-Object -First 1
        if ($null -eq $uvAsset) {
            $uvAsset = $uvRelease.assets | Where-Object { $_.name -eq "uv-i686-pc-windows-msvc.zip" } | Select-Object -First 1
        }
        if ($null -eq $uvAsset) {
            $uvAsset = $uvRelease.assets | Where-Object { $_.name -eq "uv-aarch64-pc-windows-msvc.zip" } | Select-Object -First 1
        }
        if ($null -eq $uvAsset) {
            Write-Error "uvのWindows用zipが見つかりませんでした。"
            exit 1
        }
        $uvZipPath = Join-Path $releaseDir "uv-latest.zip"
        Invoke-WebRequest -Uri $uvAsset.browser_download_url -OutFile $uvZipPath

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [IO.Compression.ZipFile]::OpenRead($uvZipPath)
        $uvEntry = $zip.Entries | Where-Object { $_.FullName.ToLower().EndsWith("uv.exe") } | Select-Object -First 1
        if ($null -eq $uvEntry) {
            Write-Error "uv.exeがzip内に見つかりませんでした。"
            $zip.Dispose()
            Remove-Item $uvZipPath -Force
            exit 1
        }
        $uvExePath = Join-Path $releaseDir "uv.exe"
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($uvEntry, $uvExePath, $true)
        $zip.Dispose()
        Remove-Item $uvZipPath -Force
        Write-Host "uv.exeをReleaseフォルダに配置しました。" -ForegroundColor Green
    }

    # uv -V でuvコマンドの利用可否を判定し、uv優先・失敗時はpip
    Write-Host "`n== requirements.txt のモジュールをインストールします =="
    $pythonExe = Join-Path $targetFolder "python.exe"
    $requirementsPath = "./requirements.txt"
    if (Test-Path $requirementsPath) {
        if ($forcePip) {
            # pipのインストール
            Write-Host "pipでrequirements.txt のモジュールをインストールします。" -ForegroundColor Yellow
            $pipUrl = "https://bootstrap.pypa.io/get-pip.py"
            $getPip = "$targetFolder\get-pip.py"
            Invoke-WebRequest -Uri $pipUrl -OutFile $getPip
            & $pythonExe $getPip --disable-pip-version-check --no-warn-script-location
            Remove-Item $getPip

            # pip経由でのインストール
            & $pythonExe -m pip install -r $requirementsPath --disable-pip-version-check --no-warn-script-location --no-cache-dir
            Write-Host "pip経由でrequirements.txt のモジュールをインストールしました。" -ForegroundColor Green
        } else {
            # uv がインストール済みで実行可能かどうかチェック
            $uvAvailable = $false
            $uvExePath = $null

            # 1. カレントディレクトリの uv.exe を最初に確認
            $uvExeLocal = Join-Path $releaseDir "uv.exe"
            if (Test-Path $uvExeLocal) {
                try {
                    & $uvExeLocal -V > $null 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "カレントディレクトリの uv.exe を利用します。" -ForegroundColor Green
                        $uvAvailable = $true
                        $uvExePath = $uvExeLocal
                    }
                } catch {}
            }

            # 2. パスが通っている uv コマンド（インストール済みかチェック）
            if (-not $uvAvailable) {
                Write-Host "インストール済みの uv コマンドを確認します..." -ForegroundColor Cyan
                $uvCmd = "uv"
                $uvCmdPath = (Get-Command uv -All -ErrorAction Ignore).Source
                if ($uvCmdPath) {
                    try {
                        & $uvCmdPath -V > $null 2>&1
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "インストール済みの uv コマンドを利用します。" -ForegroundColor Green
                            $uvAvailable = $true
                            $uvExePath = $uvCmdPath
                        }
                    } catch {}
                }
            }

            # どちらもなければダウンロード
            if (-not $uvAvailable) {
                Write-Host "uv.exeが見つからないため、ダウンロードします..." -ForegroundColor Yellow
                DownloadAndExtractUvExe -releaseDir $releaseDir
                $uvExeLocal = Join-Path $releaseDir "uv.exe"
                if (Test-Path $uvExeLocal) {
                    $uvAvailable = $true
                    $uvExePath = $uvExeLocal
                }
            }

            if ($uvAvailable) {
                # uv経由でのインストール
                Write-Host $uvExePath
                & $uvExePath pip install -r $requirementsPath pip --python $pythonExe --no-cache-dir
                Write-Host "uv経由でrequirements.txt のモジュールをインストールしました。" -ForegroundColor Green
            } else {
                Write-Host "uvが見つからないため、pipでのインストールに切り替えます。" -ForegroundColor Yellow
                # pipのインストール
                Write-Host "pipでrequirements.txt のモジュールをインストールします。" -ForegroundColor Yellow
                $pipUrl = "https://bootstrap.pypa.io/get-pip.py"
                $getPip = "$targetFolder\get-pip.py"
                Invoke-WebRequest -Uri $pipUrl -OutFile $getPip
                & $pythonExe $getPip --disable-pip-version-check --no-warn-script-location
                Remove-Item $getPip

                # pip経由でのインストール
                & $pythonExe -m pip install -r $requirementsPath --disable-pip-version-check --no-warn-script-location --no-cache-dir
                Write-Host "pip経由でrequirements.txt のモジュールをインストールしました。" -ForegroundColor Green
            }
        }
    } else {
        $absPath = [System.IO.Path]::GetFullPath($requirementsPath)
        Write-Warning "$absPath が見つかりませんでした。"
        Write-Host "処理を中断します。" -ForegroundColor Yellow
        exit 1
    }

    Write-Host "Python $version の組み込み版セットアップが完了しました。" -ForegroundColor Green
} finally {
    # 元のディレクトリに戻る
    Set-Location $originalDir
}
