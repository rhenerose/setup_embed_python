@echo off
REM run.bat - �N���o�b�`
REM   �X�N���v�g�Ɠ����f�B���N�g�����Python�t�H���_��T�����A�����̃t�@�C�������s���܂��B
REM   ���w�莞�� source\main.py �����s���܂��B

REM ���̃o�b�`�̂���ꏊ���J�����g�f�B���N�g����
pushd "%~dp0"

REM Python���s�t�@�C���̃p�X�ipython310 �Ȃǂ��������o�j
for /d %%D in ("%~dp0python*") do (
    set PYDIR=%%~fD
)
set PYEXE=%PYDIR%\python.exe

REM �������w�肳��Ă���΂��̃t�@�C�����A�Ȃ���� source\main.py �����s
if "%~1"=="" (
    "%PYEXE%" source\main.py
) else (
    "%PYEXE%" %*
)
popd