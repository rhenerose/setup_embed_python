@echo off
REM run.bat - 起動バッチ
REM   スクリプトと同じディレクトリ上でPythonフォルダを探索し、引数のファイルを実行します。
REM   未指定時は source\main.py を実行します。

REM このバッチのある場所をカレントディレクトリに
pushd "%~dp0"

REM Python実行ファイルのパス（python310 などを自動検出）
for /d %%D in ("%~dp0python*") do (
    set PYDIR=%%~fD
)
set PYEXE=%PYDIR%\python.exe

REM 引数が指定されていればそのファイルを、なければ source\main.py を実行
if "%~1"=="" (
    "%PYEXE%" source\main.py
) else (
    "%PYEXE%" %*
)
popd