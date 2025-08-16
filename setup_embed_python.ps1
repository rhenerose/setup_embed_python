# =============================================
# setup_embed_python.ps1
# ---------------------------------------------
# Windows �g�ݍ��ݔ� Python ���Z�b�g�A�b�v�������X�N���v�g
#
# �y��ȋ@�\�E���[�N�t���[�z
#   - ����Python���t�H���_(��: python310��)�����o���A���[�U�[�m�F��Ɉ��S�ɍ폜
#   - Python�����T�C�g����3.9�ȍ~�̃o�[�W�����ꗗ���擾���A�Θb�I�Ƀo�[�W�����I��
#   - �I���o�[�W������embeddable zip�����݂��邩�������肵�A�ŐV�ł𐄏�
#   - �g�ݍ��ݔ�zip���_�E�����[�h�E�W�J���Asite�L������ǉ��p�X�ݒ��������
#       �� �ǉ��p�X��ύX�������ꍇ�� $extraPaths ��ҏW���Ă�������
#   - �ŐV��uv.exe��GitHub����_�E�����[�h
#   - uv.exe���g����pip�C���X�g�[����requirements.txt�ɂ��ˑ����W���[�������C���X�g�[��
#       - uv.exe �����p�ł��Ȃ��ꍇ�́A�������� get-pip.py ���_�E�����[�h���� pip ���C���X�g�[��
#
# �y���s��z
#   - PowerShell�Ŗ{�X�N���v�g���E�N���b�N�uPowerShell�Ŏ��s�v�܂��̓^�[�~�i��������s
# =============================================

# �����p�X�ɒǉ�����p�X�̃��X�g���쐬 (�K�v�ɉ����ďC��)
#  - �p�X��ǉ�����ۂɂ̓J���}��؂�Œǉ� ("pathA", "pathB" �Ȃ�)
#  - �p�X�� Python.exe �̂���f�B���N�g������̑��΃p�X���w�肷��
$extraPaths = @(
    "../source"
)

$ftpBase = "https://www.python.org/ftp/python/"
$response = Invoke-WebRequest -Uri $ftpBase

# ���̃f�B���N�g����ۑ�
$originalDir = Get-Location

try {
    # Release�t�H���_�̍쐬�ƈړ�
    $releaseDir = Join-Path $PSScriptRoot "."
    $releaseDir = [System.IO.Path]::GetFullPath($releaseDir)

    if (-not (Test-Path $releaseDir)) {
        New-Item -ItemType Directory -Path $releaseDir | Out-Null
    }
    Set-Location $releaseDir

    # �R�}���h���C���I�v�V��������: --pip ������� uv ���g�킸 pip �̂݁iforeach �̊O�Ɉړ��j
    $forcePip = $false
    if ($args -contains "--pip") {
        $forcePip = $true
        Write-Host "--pip �I�v�V�����w��: uv ���g�킸 pip �݂̂ŃC���X�g�[�����܂��B" -ForegroundColor Yellow
    }
    # Python***�t�H���_���m�F���A���݂���ꍇ�͍폜���邩���[�U�Ɋm�F
    $pythonDirs = Get-ChildItem -Path $releaseDir -Directory | Where-Object { $_.Name -match '^python(\d+|\d+\.\d+)$' }
    foreach ($pyDir in $pythonDirs) {
        $dirName = $pyDir.Name
        Write-Host "���o: $dirName" -ForegroundColor Yellow
        $ans = Read-Host "[$dirName] �t�H���_�����ɑ��݂��܂��B�폜���Ă�낵���ł����H (y/N)"
        if ($ans -eq "y" -or $ans -eq "Y") {
            Remove-Item $pyDir.FullName -Recurse -Force
            Write-Host "$dirName �t�H���_���폜���܂����B" -ForegroundColor Green
        }
        else {
            Write-Host "�����𒆒f���܂��B" -ForegroundColor Yellow
            exit 1
        }
    }

    # �S�o�[�W�����擾
    $allVersions = ($response.Content -split "`n") |
        Where-Object { $_ -match 'href="(\d+\.\d+\.\d+)/"' } |
        ForEach-Object { ($_ -replace '.*href="([^"]+)/".*', '$1') } |
        Where-Object { $_ -like "3.*" }

    # 3.9�ȏ�̃��W���[�o�[�W�������o�i�����j
    $majorVersions = $allVersions |
        ForEach-Object { ($_ -split '\.')[0..1] -join '.' } |
        Where-Object { [version]$_ -ge [version]"3.9" } |
        Sort-Object { [version]$_ } -Unique

    # �܂����W���[�o�[�W�����I��
    Write-Host "`n== ���W���[�o�[�W������I�����Ă������� (3.9�ȍ~) =="
    for ($i = 0; $i -lt $majorVersions.Count; $i++) {
        Write-Host "[$i] $($majorVersions[$i])"
    }
    $majorIndex = Read-Host "�ԍ�����͂��Ă�������"
    if ($majorIndex -notmatch '^\d+$' -or [int]$majorIndex -ge $majorVersions.Count) {
        Write-Error "�����ȓ��͂ł�"
        exit 1
    }
    $selectedMajor = $majorVersions[$majorIndex]

    # �I���������W���[�o�[�W�����ɊY������S�p�b�`�o�[�W�����𒊏o
    $patchVersions = $allVersions | Where-Object { $_ -like "$selectedMajor.*" } | Sort-Object { [version]$_ }

    # �� �����őg�ݍ��ݔő��݃`�F�b�N�����ăt�B���^�[����
    Write-Host "�g�ݍ��ݔł̑��݃`�F�b�N�����Ă��܂��B���X���҂���������..." -ForegroundColor Cyan

    $validPatchVersions = @()
    foreach ($ver in $patchVersions) {
        $zipUrl = "$ftpBase$ver/python-$ver-embed-amd64.zip"
        try {
            # HEAD ���N�G�X�g�ő��݊m�F
            Invoke-WebRequest -Uri $zipUrl -Method Head -ErrorAction Stop | Out-Null
            $validPatchVersions += $ver
        }
        catch {
            # ���݂��Ȃ��ꍇ�͖���
        }
    }

    if ($validPatchVersions.Count -eq 0) {
        Write-Warning "�I���������W���[�o�[�W�����ɑg�ݍ��ݔł����݂��܂���B"
        exit 1
    }

    # �L���ȃp�b�`�o�[�W�����������ŕ\��
    $validPatchVersions = $validPatchVersions | Sort-Object { [version]$_ }

    Write-Host "`n== �g�ݍ��ݔł����݂���p�b�`�o�[�W������I�����Ă������� =="
    for ($i = 0; $i -lt $validPatchVersions.Count; $i++) {
        Write-Host "[$i] $($validPatchVersions[$i])"
    }
    # �f�t�H���g�ōŐV�Łi�����Ȃ̂ōŌオ�ŐV�Łj
    $defaultPatchIndex = $validPatchVersions.Count - 1
    $patchIndex = Read-Host "�ԍ�����͂��Ă��������iEnter�ōŐV��: $defaultPatchIndex�j"
    if ($patchIndex -eq "") {
        $patchIndex = $defaultPatchIndex
    }
    if ($patchIndex -notmatch '^\d+$' -or [int]$patchIndex -ge $validPatchVersions.Count) {
        Write-Error "�����ȓ��͂ł�"
        exit 1
    }

    $version = $validPatchVersions[$patchIndex]
    Write-Host "`n�I�����ꂽ�o�[�W����: $version" -ForegroundColor Green

    Write-Host "`n�g�ݍ��ݔ�Python���_�E�����[�h���܂��B" -ForegroundColor Cyan
    Read-Host -Prompt "�C�ӂ̃L�[�������Ă�������..."

    # �o�[�W��������
    # $version = Read-Host "Python�o�[�W��������͂��Ă������� (��: 3.10.11)"

    # �o�[�W���������񏈗�
    # $shortVersion = $version -replace '\.', ''        # ��: 31011
    $majorMinor = ($version -split '\.')[0..1] -join '.' # 3.10
    $embedName = "python-$version-embed-amd64.zip"
    $downloadUrl = "https://www.python.org/ftp/python/$version/$embedName"
    $targetFolder = "python$($majorMinor -replace '\.', '')"

    # ��ƃf�B���N�g���̍쐬
    New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null

    # �_�E�����[�h
    $zipPath = "$targetFolder\$embedName"
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath

    # �W�J
    Expand-Archive -Path $zipPath -DestinationPath $targetFolder -Force
    Remove-Item $zipPath

    # site �L����: python3xx._pth ��ҏW
    $pthFile = Get-ChildItem -Path $targetFolder -Filter "python*._pth" | Select-Object -First 1
    if ($pthFile) {
        $pthPath = $pthFile.FullName

        # site �̃C���|�[�g��L����
        Write-Host "`n== $($pthFile.Name) �� 'import site' ��L�������܂� =="
        (Get-Content $pthPath) |
            ForEach-Object { $_ -replace '^#import site', 'import site' } |
            Set-Content $pthPath
        Write-Host "$($pthFile.Name) �� 'import site' ��L�������܂���" -ForegroundColor Green

        # . �݂̂̍s�̒���Ƀp�X��1�s���ǉ�
        Write-Host "`n== $($pthFile.Name) �ɒǉ��p�X��ǋL���܂� =="
        $pthLines = Get-Content $pthPath
        $newPthLines = @()
        for ($i = 0; $i -lt $pthLines.Count; $i++) {
            $newPthLines += $pthLines[$i]
            if ($pthLines[$i] -eq ".") {
                $newPthLines += $extraPaths
            }
        }
        Set-Content $pthPath $newPthLines
        Write-Host "�ǉ��p�X�� $($pthFile.Name) �ɒǋL���܂���" -ForegroundColor Green
    }
    else {
        Write-Error "_pth �t�@�C����������Ȃ��������߁A�Z�b�g�A�b�v�𒆒f���܂��B"
        exit 1
    }

    # �ŐV��uv.exe��Github����Release�t�H���_�Ƀ_�E�����[�h�E��
    function DownloadAndExtractUvExe {
        param (
            [string]$releaseDir
        )
        Write-Host "`n`nGithub����ŐV��uv.exe���_�E�����[�h���Ă��܂�..." -ForegroundColor Cyan
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
            Write-Error "uv��Windows�pzip��������܂���ł����B"
            exit 1
        }
        $uvZipPath = Join-Path $releaseDir "uv-latest.zip"
        Invoke-WebRequest -Uri $uvAsset.browser_download_url -OutFile $uvZipPath

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [IO.Compression.ZipFile]::OpenRead($uvZipPath)
        $uvEntry = $zip.Entries | Where-Object { $_.FullName.ToLower().EndsWith("uv.exe") } | Select-Object -First 1
        if ($null -eq $uvEntry) {
            Write-Error "uv.exe��zip���Ɍ�����܂���ł����B"
            $zip.Dispose()
            Remove-Item $uvZipPath -Force
            exit 1
        }
        $uvExePath = Join-Path $releaseDir "uv.exe"
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($uvEntry, $uvExePath, $true)
        $zip.Dispose()
        Remove-Item $uvZipPath -Force
        Write-Host "uv.exe��Release�t�H���_�ɔz�u���܂����B" -ForegroundColor Green
    }

    # uv -V ��uv�R�}���h�̗��p�ۂ𔻒肵�Auv�D��E���s����pip
    Write-Host "`n== requirements.txt �̃��W���[�����C���X�g�[�����܂� =="
    $pythonExe = Join-Path $targetFolder "python.exe"
    $requirementsPath = "./requirements.txt"
    if (Test-Path $requirementsPath) {
        if ($forcePip) {
            # pip�̃C���X�g�[��
            Write-Host "pip��requirements.txt �̃��W���[�����C���X�g�[�����܂��B" -ForegroundColor Yellow
            $pipUrl = "https://bootstrap.pypa.io/get-pip.py"
            $getPip = "$targetFolder\get-pip.py"
            Invoke-WebRequest -Uri $pipUrl -OutFile $getPip
            & $pythonExe $getPip --disable-pip-version-check --no-warn-script-location
            Remove-Item $getPip

            # pip�o�R�ł̃C���X�g�[��
            & $pythonExe -m pip install -r $requirementsPath --disable-pip-version-check --no-warn-script-location --no-cache-dir
            Write-Host "pip�o�R��requirements.txt �̃��W���[�����C���X�g�[�����܂����B" -ForegroundColor Green
        } else {
            # uv ���C���X�g�[���ς݂Ŏ��s�\���ǂ����`�F�b�N
            $uvAvailable = $false
            $uvExePath = $null

            # 1. �J�����g�f�B���N�g���� uv.exe ���ŏ��Ɋm�F
            $uvExeLocal = Join-Path $releaseDir "uv.exe"
            if (Test-Path $uvExeLocal) {
                try {
                    & $uvExeLocal -V > $null 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "�J�����g�f�B���N�g���� uv.exe �𗘗p���܂��B" -ForegroundColor Green
                        $uvAvailable = $true
                        $uvExePath = $uvExeLocal
                    }
                } catch {}
            }

            # 2. �p�X���ʂ��Ă��� uv �R�}���h�i�C���X�g�[���ς݂��`�F�b�N�j
            if (-not $uvAvailable) {
                Write-Host "�C���X�g�[���ς݂� uv �R�}���h���m�F���܂�..." -ForegroundColor Cyan
                $uvCmd = "uv"
                $uvCmdPath = (Get-Command uv -All -ErrorAction Ignore).Source
                if ($uvCmdPath) {
                    try {
                        & $uvCmdPath -V > $null 2>&1
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "�C���X�g�[���ς݂� uv �R�}���h�𗘗p���܂��B" -ForegroundColor Green
                            $uvAvailable = $true
                            $uvExePath = $uvCmdPath
                        }
                    } catch {}
                }
            }

            # �ǂ�����Ȃ���΃_�E�����[�h
            if (-not $uvAvailable) {
                Write-Host "uv.exe��������Ȃ����߁A�_�E�����[�h���܂�..." -ForegroundColor Yellow
                DownloadAndExtractUvExe -releaseDir $releaseDir
                $uvExeLocal = Join-Path $releaseDir "uv.exe"
                if (Test-Path $uvExeLocal) {
                    $uvAvailable = $true
                    $uvExePath = $uvExeLocal
                }
            }

            if ($uvAvailable) {
                # uv�o�R�ł̃C���X�g�[��
                Write-Host $uvExePath
                & $uvExePath pip install -r $requirementsPath pip --python $pythonExe --no-cache-dir
                Write-Host "uv�o�R��requirements.txt �̃��W���[�����C���X�g�[�����܂����B" -ForegroundColor Green
            } else {
                Write-Host "uv��������Ȃ����߁Apip�ł̃C���X�g�[���ɐ؂�ւ��܂��B" -ForegroundColor Yellow
                # pip�̃C���X�g�[��
                Write-Host "pip��requirements.txt �̃��W���[�����C���X�g�[�����܂��B" -ForegroundColor Yellow
                $pipUrl = "https://bootstrap.pypa.io/get-pip.py"
                $getPip = "$targetFolder\get-pip.py"
                Invoke-WebRequest -Uri $pipUrl -OutFile $getPip
                & $pythonExe $getPip --disable-pip-version-check --no-warn-script-location
                Remove-Item $getPip

                # pip�o�R�ł̃C���X�g�[��
                & $pythonExe -m pip install -r $requirementsPath --disable-pip-version-check --no-warn-script-location --no-cache-dir
                Write-Host "pip�o�R��requirements.txt �̃��W���[�����C���X�g�[�����܂����B" -ForegroundColor Green
            }
        }
    } else {
        $absPath = [System.IO.Path]::GetFullPath($requirementsPath)
        Write-Warning "$absPath ��������܂���ł����B"
        Write-Host "�����𒆒f���܂��B" -ForegroundColor Yellow
        exit 1
    }

    Write-Host "Python $version �̑g�ݍ��ݔŃZ�b�g�A�b�v���������܂����B" -ForegroundColor Green
} finally {
    # ���̃f�B���N�g���ɖ߂�
    Set-Location $originalDir
}
