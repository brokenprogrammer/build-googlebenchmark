@echo off
setlocal enabledelayedexpansion

REM Checking dependencies

where /Q git.exe || (
    echo Error: "git.exe" was not found
    exit /b 1
)

where /Q curl.exe || (
    echo Error: "curl.exe" was not found
    exit /b 1
)

where /Q cmake.exe || (
    echo Error: "cmake.exe" was not found
    exit /b 1
)

if exist "%ProgramFiles%\7-Zip\7z.exe" (
  set SZIP="%ProgramFiles%\7-Zip\7z.exe"
) else (
  where /q 7za.exe || (
    echo Error: 7-Zip installation or "7za.exe" not found
    exit /b 1
  )
  set SZIP=7za.exe
)

rem Setting up visual studio environment

where /Q cl.exe || (
    set __VSCMD_ARG_NO_LOGO=1
    for /f "tokens=*" %%i in ('"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -requires Microsoft.VisualStudio.Workload.NativeDesktop -property installationPath') do set VS=%%i
    if "!VS!" equ "" (
        echo ERROR: Visual Studio installation not found
        exit /b 1
    )  
    call "!VS!\VC\Auxiliary\Build\vcvarsall.bat" amd64 || exit /b 1
)

rem Downloading source

echo Downloading benchmark
if exist benchmark.src (
  pushd benchmark.src
  git pull --force --no-tags --depth 1 || exit /b 1
  popd
) else (
  git clone --depth 1 --no-tags --single-branch https://github.com/google/benchmark benchmark.src || exit /b 1
)

rem Building

pushd benchmark.src
cmake -E make_directory "build"
cmake -E chdir "build" cmake -A x64 -G "Visual Studio 17 2022" -DBENCHMARK_DOWNLOAD_DEPENDENCIES=on -DCMAKE_BUILD_TYPE=Release -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ../ || exit /b 1
cmake --build "build" --config Release
popd


Rem Packaging release

mkdir benchmark
mkdir benchmark\lib
mkdir benchmark\include

copy /y benchmark.src\.git\refs\heads\main benchmark\commit.txt            1>nul 2>nul

copy /y benchmark.src\build\src\Release\benchmark.lib      benchmark\lib     1>nul 2>nul
copy /y benchmark.src\build\src\Release\benchmark_main.lib benchmark\lib     1>nul 2>nul

xcopy /D /S /I /Q /Y benchmark.src\include                 benchmark\include 1>nul 2>nul

if "%GITHUB_WORKFLOW%" neq "" (
    set /p BENCHMARK_COMMIT=<benchmark\commit.txt

    for /F "skip=1" %%D in ('WMIC OS GET LocalDateTime') do (set LDATE=%%D & goto :dateok)
    :dateok
    set BUILD_DATE=%LDATE:~0,4%-%LDATE:~4,2%-%LDATE:~6,2%

    %SZIP% a -mx=9 benchmark-%BUILD_DATE%.zip benchmark || exit /b 1

    echo Successfully packaged benchmark

    echo ::set-output name=BENCHMARK_COMMIT::%BENCHMARK_COMMIT%
    echo ::set-output name=BUILD_DATE::%BUILD_DATE%

    echo Done
)

exit /b 0